import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/core.dart';

/// WebRTCCallService — Handles real-time peer-to-peer WebRTC audio/video call
/// with dual signaling (WebSocket + REST API fallback) and resilient media handling.
class WebRTCCallService {
  WebRTCCallService._();
  static final WebRTCCallService instance = WebRTCCallService._();

  // WebSocket for signaling
  WebSocket? _ws;
  bool _wsConnected = false;
  Timer? _wsReconnectTimer;
  Timer? _wsPingTimer;
  String? _currentCallId;
  String? _remoteUserId;
  bool _isInitiator = false;

  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  // ICE Candidate Queue (avoids dropping candidates arriving before remote description)
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _hasRemoteDescription = false;
  final Set<String> _processedSignalKeys = {};

  // Callbacks
  Function(RTCVideoRenderer local, RTCVideoRenderer remote)? onRendererReady;
  Function()? onCallConnected;
  Function()? onCallEnded;
  Function(String errorMsg)? onError;
  Function(Map<String, dynamic> event)? onSignalingEvent;

  bool get isConnected => _wsConnected;
  bool get hasPeerConnection => _peerConnection != null;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  bool get isLocalVideoReady =>
      _localRenderer != null && _localRenderer!.srcObject != null;

  bool get isRemoteVideoReady =>
      _remoteRenderer != null && _remoteRenderer!.srcObject != null;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  static const Map<String, dynamic> _offerConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  // ── WebSocket Connection ──────────────────────────────────────────────────

  Future<void> connectSignaling({
    required String callId,
    required bool isInitiator,
    String? remoteUserId,
  }) async {
    _currentCallId = callId;
    _isInitiator = isInitiator;
    _remoteUserId = remoteUserId;
    await _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    try {
      final token = ApiClient.instance.authToken ?? '';
      if (token.isEmpty) {
        debugPrint('[WebRTC] No auth token, skipping WebSocket signaling');
        return;
      }

      final wsBase = EnvConfig.instance.websocketUrl;
      final wsUrl = '$wsBase/ws/calls?token=${Uri.encodeComponent(token)}';
      debugPrint('[WebRTC] Connecting to signaling: $wsUrl');

      _ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 8));
      _wsConnected = true;
      debugPrint('[WebRTC] Signaling WebSocket connected');

      _ws!.listen(
        _onSignalingMessage,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );

      // Join the call room
      _wsSend({'event': 'join_call', 'data': {'callId': _currentCallId}});

      // Start ping to keep connection alive
      _startWsPing();
    } catch (e) {
      debugPrint('[WebRTC] WS connect error (will use REST fallback): $e');
      _wsConnected = false;
      _scheduleReconnect();
    }
  }

  void _onSignalingMessage(dynamic raw) {
    try {
      final data = json.decode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? data['event'] as String? ?? '';
      debugPrint('[WebRTC] Signaling received via WS: $type');

      onSignalingEvent?.call(data);

      switch (type) {
        case 'CONNECTED':
          if (_isInitiator && _peerConnection != null) {
            _createAndSendOffer();
          }
          break;

        case 'PEER_JOINED':
          if (_isInitiator && _peerConnection != null) {
            _createAndSendOffer();
          }
          break;

        case 'CALL_ENDED':
        case 'CALL_REJECTED':
          onCallEnded?.call();
          break;

        case 'CALL_ACCEPTED':
          if (_isInitiator && _peerConnection != null) {
            _createAndSendOffer();
          }
          break;

        default:
          handleRemoteSignal(data);
          break;
      }
    } catch (e) {
      debugPrint('[WebRTC] Signaling parse error: $e');
    }
  }

  void _onWsDone() {
    debugPrint('[WebRTC] WS closed');
    _wsConnected = false;
    _scheduleReconnect();
  }

  void _onWsError(dynamic error) {
    debugPrint('[WebRTC] WS error: $error');
    _wsConnected = false;
  }

  void _scheduleReconnect() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_wsConnected && _currentCallId != null) {
        _connectWebSocket();
      }
    });
  }

  void _startWsPing() {
    _wsPingTimer?.cancel();
    _wsPingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_wsConnected && _ws != null) {
        _wsSend({'event': 'ping'});
      }
    });
  }

  void _wsSend(Map<String, dynamic> data) {
    if (_ws != null && _wsConnected) {
      try {
        _ws!.add(json.encode(data));
      } catch (e) {
        debugPrint('[WebRTC] WS send error: $e');
      }
    }
  }

  // ── Dual Signaling Dispatcher ─────────────────────────────────────────────

  void _sendSignal(String event, Map<String, dynamic> data) {
    // 1. Send via WebSocket if connected
    _wsSend({'event': event, 'data': data});

    // 2. Also send via REST API fallback for guaranteed delivery
    final cid = _currentCallId;
    if (cid != null && !cid.startsWith('call-') && !cid.startsWith('group-')) {
      unawaited(() async {
        try {
          await ApiClient.instance.post(
            ApiEndpoints.callSignal(cid),
            body: {
              'signal': {
                'type': event.toUpperCase(),
                'event': event,
                ...data,
              }
            },
          );
        } catch (_) {}
      }());
    }
  }

  /// Process incoming signal from either WebSocket or REST polling
  void handleRemoteSignal(Map<String, dynamic> data) {
    final type = ((data['type'] as String?) ?? (data['event'] as String?) ?? '').toUpperCase();
    if (type.isEmpty) return;

    // Deduplicate identical signals
    final sigKey = '$type-${json.encode(data['sdp'] ?? data['candidate'] ?? '')}';
    if (_processedSignalKeys.contains(sigKey)) return;
    _processedSignalKeys.add(sigKey);

    debugPrint('[WebRTC] handleRemoteSignal: $type');

    switch (type) {
      case 'WEBRTC_OFFER':
        final sdp = data['sdp'];
        if (sdp != null && !_isInitiator) {
          final sdpMap = sdp is Map ? sdp : json.decode(sdp.toString());
          _handleRemoteOffer(RTCSessionDescription(sdpMap['sdp'], sdpMap['type']));
        }
        break;

      case 'WEBRTC_ANSWER':
        final sdp = data['sdp'];
        if (sdp != null && _isInitiator) {
          final sdpMap = sdp is Map ? sdp : json.decode(sdp.toString());
          _handleRemoteAnswer(RTCSessionDescription(sdpMap['sdp'], sdpMap['type']));
        }
        break;

      case 'ICE_CANDIDATE':
        final candidate = data['candidate'];
        if (candidate != null) {
          final cMap = candidate is Map ? candidate : json.decode(candidate.toString());
          _handleRemoteIceCandidate(RTCIceCandidate(
            cMap['candidate'],
            cMap['sdpMid'],
            cMap['sdpMLineIndex'],
          ));
        }
        break;
    }
  }

  // ── WebRTC Peer Connection ────────────────────────────────────────────────

  Future<void> initializePeerConnection({
    required bool isVideo,
    required bool isAudio,
  }) async {
    _hasRemoteDescription = false;
    _pendingIceCandidates.clear();
    _processedSignalKeys.clear();

    // Initialize renderers
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    // Get local media stream with flexible constraints & automatic fallback
    if (isVideo || isAudio) {
      try {
        final Map<String, dynamic> mediaConstraints = {
          'audio': isAudio ? {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          } : false,
          'video': isVideo ? {
            'facingMode': 'user',
            'mandatory': {
              'minWidth': '640',
              'minHeight': '480',
              'minFrameRate': '24',
            },
            'optional': [],
          } : false,
        };

        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (e) {
        debugPrint('[WebRTC] High-res getUserMedia failed: $e, trying simple constraints...');
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': isAudio,
            'video': isVideo ? {'facingMode': 'user'} : false,
          });
        } catch (e2) {
          debugPrint('[WebRTC] Basic getUserMedia also failed: $e2');
          _localStream = null;
        }
      }

      if (_localStream != null) {
        _localRenderer!.srcObject = _localStream;
        debugPrint('[WebRTC] Local stream acquired: ${_localStream!.id}');
      }
    }

    // Create RTCPeerConnection
    _peerConnection = await createPeerConnection(_iceServers);

    // Add local stream tracks to peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Handle remote track (supports both stream-based and track-based modes)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteRenderer!.srcObject = _remoteStream;
      }
      onCallConnected?.call();
      onRendererReady?.call(_localRenderer!, _remoteRenderer!);
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      debugPrint('[WebRTC] Remote stream added: ${stream.id}');
      _remoteStream = stream;
      _remoteRenderer!.srcObject = _remoteStream;
      onCallConnected?.call();
      onRendererReady?.call(_localRenderer!, _remoteRenderer!);
    };

    // ICE candidate handling
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        debugPrint('[WebRTC] Local ICE candidate generated');
        _sendSignal('ice_candidate', {
          'callId': _currentCallId,
          'targetUserId': _remoteUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    // Connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _restartIce();
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state: $state');
    };

    // Notify initial renderer readiness
    onRendererReady?.call(_localRenderer!, _remoteRenderer!);

    // If initiator, send offer immediately
    if (_isInitiator) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _createAndSendOffer();
      });
    }

    debugPrint('[WebRTC] PeerConnection initialized');
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;
    try {
      final offer = await _peerConnection!.createOffer(_offerConstraints);
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('[WebRTC] Sending SDP offer');
      _sendSignal('webrtc_offer', {
        'callId': _currentCallId,
        'targetUserId': _remoteUserId,
        'sdp': {'type': offer.type, 'sdp': offer.sdp},
      });
    } catch (e) {
      debugPrint('[WebRTC] createOffer error: $e');
    }
  }

  Future<void> _handleRemoteOffer(RTCSessionDescription offer) async {
    if (_peerConnection == null) return;
    try {
      await _peerConnection!.setRemoteDescription(offer);
      _hasRemoteDescription = true;
      await _drainPendingCandidates();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTC] Sending SDP answer');
      _sendSignal('webrtc_answer', {
        'callId': _currentCallId,
        'targetUserId': _remoteUserId,
        'sdp': {'type': answer.type, 'sdp': answer.sdp},
      });
    } catch (e) {
      debugPrint('[WebRTC] handleOffer error: $e');
    }
  }

  Future<void> _handleRemoteAnswer(RTCSessionDescription answer) async {
    if (_peerConnection == null) return;
    try {
      await _peerConnection!.setRemoteDescription(answer);
      _hasRemoteDescription = true;
      await _drainPendingCandidates();
      debugPrint('[WebRTC] Remote answer set successfully');
    } catch (e) {
      debugPrint('[WebRTC] setRemoteDescription error: $e');
    }
  }

  Future<void> _handleRemoteIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) return;
    if (!_hasRemoteDescription) {
      debugPrint('[WebRTC] Queuing ICE candidate until remote description is set');
      _pendingIceCandidates.add(candidate);
      return;
    }
    try {
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[WebRTC] Added remote ICE candidate');
    } catch (e) {
      debugPrint('[WebRTC] addCandidate error: $e');
    }
  }

  Future<void> _drainPendingCandidates() async {
    if (_peerConnection == null) return;
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
        debugPrint('[WebRTC] Added queued ICE candidate');
      } catch (e) {
        debugPrint('[WebRTC] add queued Candidate error: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  Future<void> _restartIce() async {
    debugPrint('[WebRTC] Restarting ICE...');
    if (_peerConnection == null || !_isInitiator) return;
    try {
      final offer = await _peerConnection!.createOffer({
        'iceRestart': true,
        'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      });
      await _peerConnection!.setLocalDescription(offer);
      _sendSignal('webrtc_offer', {
        'callId': _currentCallId,
        'targetUserId': _remoteUserId,
        'sdp': {'type': offer.type, 'sdp': offer.sdp},
      });
    } catch (e) {
      debugPrint('[WebRTC] ICE restart error: $e');
    }
  }

  // ── Media Controls ────────────────────────────────────────────────────────

  void setMicrophoneMuted(bool muted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  void setCameraEnabled(bool enabled) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks.first);
    }
  }

  void setSpeakerphone(bool speaker) {
    Helper.setSpeakerphoneOn(speaker);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    debugPrint('[WebRTC] Disposing WebRTC...');
    _wsReconnectTimer?.cancel();
    _wsPingTimer?.cancel();
    _wsConnected = false;
    _currentCallId = null;
    _remoteUserId = null;
    _hasRemoteDescription = false;
    _pendingIceCandidates.clear();
    _processedSignalKeys.clear();

    try {
      await _ws?.close();
      _ws = null;
    } catch (_) {}

    try {
      _localStream?.getTracks().forEach((t) => t.stop());
      await _localStream?.dispose();
      _localStream = null;
    } catch (_) {}

    try {
      _remoteStream?.getTracks().forEach((t) => t.stop());
      await _remoteStream?.dispose();
      _remoteStream = null;
    } catch (_) {}

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
    } catch (_) {}

    try {
      await _localRenderer?.dispose();
      await _remoteRenderer?.dispose();
      _localRenderer = null;
      _remoteRenderer = null;
    } catch (_) {}

    debugPrint('[WebRTC] Disposed completely');
  }

  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
}
