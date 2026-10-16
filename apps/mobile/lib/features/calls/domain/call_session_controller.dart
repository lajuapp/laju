import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/core.dart';
import '../../conversations/domain/conversation_service.dart';
import '../../conversations/domain/models/conversation_model.dart';
import '../../messaging/domain/models/message_model.dart';
import '../../settings/domain/data_storage_controller.dart';
import '../presentation/screens/active_call_screen.dart';
import '../presentation/screens/active_group_call_screen.dart';
import '../presentation/screens/incoming_call_screen.dart';
import 'webrtc_call_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallStatus {
  idle,
  connecting,
  ringing,
  connected,
  rejected,
  busy,
  ended,
}

class CallSessionController extends ChangeNotifier with WidgetsBindingObserver {
  String? _currentIncomingCallId;

  CallSessionController._() {
    WidgetsBinding.instance.addObserver(this);
    AppNotificationService.instance.isCallActiveChecker = () => _isActive;
    _initChannelHandler();
    _startIncomingCallPoller();
    checkLaunchPayload();
    WebRTCCallService.instance.onRendererReady = (local, remote) {
      notifyListeners();
    };
    WebRTCCallService.instance.onCallEnded = () {
      if (_isActive) {
        endCall();
      }
    };
    ChatWebSocketService.instance.onCallIncoming = (_) {
      checkForIncomingCalls();
    };
  }
  static final CallSessionController instance = CallSessionController._();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // If an incoming call is ringing and user minimizes app, elevate to Android system notification
      if (_lastRingingCallId != null && !_isActive) {
        _systemNotifChannel.invokeMethod('showCallNotification', {
          'callId': _lastRingingCallId,
          'callerName': _lastRingingCallerName ?? 'Panggilan',
          'isVideo': _lastRingingIsVideo,
        }).catchError((_) {});
      }
    } else if (state == AppLifecycleState.resumed) {
      // Returned to foreground: cancel duplicate system notification so user only interacts with in-app banner
      _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    }
  }

  @override
  void notifyListeners() {
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }

  static const MethodChannel _audioChannel = MethodChannel('com.laju/call_audio');
  static const MethodChannel _systemNotifChannel = MethodChannel('com.laju/system_notifications');

  String? _callId;
  String _title = '';
  String? _contactUserId;
  String? _contactPhone;
  String? _avatarUrl;
  String? _groupName;
  bool _isGroup = false;
  bool _isVideo = false;
  bool _isOutgoing = true;
  List<String> _participants = [];
  int _durationSeconds = 0;
  bool _isMuted = false;
  bool _isVideoOn = false;
  bool _isSpeaker = false;
  bool _isMinimized = false;
  bool _isActive = false;
  RTCVideoRenderer? get webRtcLocalRenderer => WebRTCCallService.instance.localRenderer;
  RTCVideoRenderer? get webRtcRemoteRenderer => WebRTCCallService.instance.remoteRenderer;
  bool get isWebRtcRemoteVideoReady => WebRTCCallService.instance.isRemoteVideoReady;
  bool get isWebRtcLocalVideoReady => WebRTCCallService.instance.isLocalVideoReady;
  CallStatus _status = CallStatus.idle;

  Timer? _timer;
  Timer? _incomingCallPoller;
  Timer? _statusPoller;
  String? _declinedCallId;
  String? _lastRingingCallId;
  String? _lastRingingCallerName;
  String? _lastRingingCallerId;
  String? _lastRingingCallerPhone;
  String? _lastRingingCallerAvatar;
  bool _lastRingingIsVideo = false;
  bool _hasLoggedCurrentCall = false;
  final Set<String> _handledCallIds = {};

  // Getters
  String? get callId => _callId;
  String get title => _title;
  String? get contactUserId => _contactUserId;
  String? get contactPhone => _contactPhone;
  String? get avatarUrl => _avatarUrl;
  String? get groupName => _groupName;
  bool get isGroup => _isGroup;
  bool get isVideo => _isVideo;
  bool get isOutgoing => _isOutgoing;
  List<String> get participants => _participants;
  int get durationSeconds => _durationSeconds;
  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isSpeaker => _isSpeaker;
  bool get isMinimized => _isMinimized;
  bool get isActive => _isActive;
  CallStatus get status => _status;
  String? get lastRingingCallId => _lastRingingCallId;

  String get formattedDuration {
    final minutes = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get statusLabel {
    switch (_status) {
      case CallStatus.connecting:
        return 'Menghubungkan...';
      case CallStatus.ringing:
        return 'Berdering...';
      case CallStatus.connected:
        return formattedDuration;
      case CallStatus.rejected:
        return 'Panggilan Ditolak';
      case CallStatus.busy:
        return 'Sedang Sibuk';
      case CallStatus.ended:
        return 'Panggilan Berakhir';
      case CallStatus.idle:
        return '';
    }
  }

  void _startIncomingCallPoller() {
    _incomingCallPoller?.cancel();
    _incomingCallPoller = Timer.periodic(const Duration(seconds: 2), (_) {
      checkForIncomingCalls();
    });
  }

  String? _resolveAvatar(String? userId, String? phone, String contactName) {
    try {
      final convs = ConversationService.instance.conversationsNotifier.value;
      for (final c in convs) {
        if (userId != null && userId.isNotEmpty && c.participantUserId == userId) {
          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) return c.avatarUrl;
        }
        if (phone != null && phone.isNotEmpty && c.participantPhone == phone) {
          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) return c.avatarUrl;
        }
        if (c.title.toLowerCase() == contactName.toLowerCase()) {
          if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) return c.avatarUrl;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> start1on1Call({
    required String contactName,
    required bool isVideo,
    String? calleeUserId,
    String? contactPhone,
    String? avatarUrl,
  }) async {
    _stopCallAudio();
    _playCallTone('stop');
    _timer?.cancel();
    _statusPoller?.cancel();

    // Check & request permissions before proceeding
    var effectiveIsVideo = isVideo;
    final permResult = await CallPermissionService.instance.checkAndRequestPermissions(
      isVideo: isVideo,
      context: AppNavigation.navigatorKey.currentContext,
    );

    if (permResult == CallPermissionResult.denied) {
      _isActive = false;
      _status = CallStatus.idle;
      notifyListeners();
      return;
    }

    if (isVideo && permResult == CallPermissionResult.audioOnlyGranted) {
      effectiveIsVideo = false;
    }

    final resolvedTitle = contactName.trim().isNotEmpty
        ? contactName.trim()
        : (contactPhone?.trim().isNotEmpty == true
            ? contactPhone!.trim()
            : (calleeUserId?.trim().isNotEmpty == true ? calleeUserId!.trim() : 'Panggilan Keluar'));

    _callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _title = resolvedTitle;
    _contactUserId = calleeUserId;
    _contactPhone = contactPhone;
    _avatarUrl = avatarUrl ?? _resolveAvatar(calleeUserId, contactPhone, resolvedTitle);
    _groupName = null;
    _isGroup = false;
    _isVideo = effectiveIsVideo;
    _isOutgoing = true;
    _participants = [resolvedTitle];
    _durationSeconds = 0;
    _hasLoggedCurrentCall = false;
    _isMuted = false;
    _isVideoOn = effectiveIsVideo;
    _isSpeaker = effectiveIsVideo;
    _isMinimized = false;
    _isActive = true;
    _status = CallStatus.connecting;

    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
    AppNotificationService.instance.dismissAll();

    // Immediately initialize WebRTC local preview for caller so they see themselves while ringing
    WebRTCCallService.instance.initializePeerConnection(
      isVideo: effectiveIsVideo,
      isAudio: true,
    ).catchError((e) {
      debugPrint('[CallSessionController] Local preview init error: $e');
    });

    _dispatchCallToBackend(calleeUserId ?? contactPhone ?? contactName, isVideo: effectiveIsVideo);
    notifyListeners();
  }

  Future<void> startGroupCall({
    required String groupName,
    required List<String> initialParticipants,
    required bool isVideo,
    String? conversationId,
  }) async {
    _stopCallAudio();
    _playCallTone('stop');
    _timer?.cancel();
    _statusPoller?.cancel();

    // Check & request permissions before proceeding
    var effectiveIsVideo = isVideo;
    final permResult = await CallPermissionService.instance.checkAndRequestPermissions(
      isVideo: isVideo,
      context: AppNavigation.navigatorKey.currentContext,
    );

    if (permResult == CallPermissionResult.denied) {
      _isActive = false;
      _status = CallStatus.idle;
      notifyListeners();
      return;
    }

    if (isVideo && permResult == CallPermissionResult.audioOnlyGranted) {
      effectiveIsVideo = false;
    }

    _callId = 'group-call-${DateTime.now().millisecondsSinceEpoch}';
    _title = groupName;
    _groupName = groupName;
    _isGroup = true;
    _isVideo = effectiveIsVideo;
    _isOutgoing = true;
    _participants = List.from(initialParticipants);
    _durationSeconds = 0;
    _isMuted = false;
    _isVideoOn = effectiveIsVideo;
    _isSpeaker = true;
    _isMinimized = false;
    _isActive = true;
    _status = CallStatus.connected;

    _startTimer();
    _initCallAudio();

    // Initialize local WebRTC stream and preview for group call
    WebRTCCallService.instance.initializePeerConnection(
      isVideo: effectiveIsVideo,
      isAudio: true,
    ).catchError((e) {
      debugPrint('[CallSessionController] Group call local media init error: $e');
    });

    if (conversationId != null && conversationId.isNotEmpty) {
      _dispatchGroupCallToBackend(conversationId, isVideo: effectiveIsVideo);
    } else {
      // Connect to WebRTC signaling gateway for group call room
      WebRTCCallService.instance.connectSignaling(
        callId: _callId!,
        isInitiator: true,
      );
    }

    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive || _status != CallStatus.connected) {
        timer.cancel();
        return;
      }
      _durationSeconds++;
      notifyListeners();
    });
  }

  void _startCallStatusPoller() {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      final curCallId = _callId;
      if (!_isActive || curCallId == null || curCallId.startsWith('call-') || curCallId.startsWith('group-')) {
        return;
      }

      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.callById(curCallId));
        if (resp.isSuccess && resp.rawJson is Map) {
          final data = resp.rawJson;
          final callState = (data['state'] as String?)?.toUpperCase() ?? '';

          if (callState == 'INITIATED') {
            final participants = data['participants'] as List? ?? [];
            final callee = participants.firstWhere(
              (p) => (p is Map) && p['userId'] != data['initiatorId'],
              orElse: () => null,
            );
            if (callee != null && callee['state'] == 'RINGING') {
              if (_status != CallStatus.ringing) {
                _status = CallStatus.ringing;
                _playCallTone('ringback');
                notifyListeners();
              }
            }
          } else if (callState == 'CONNECTED') {
            if (_status != CallStatus.connected) {
              _status = CallStatus.connected;
              _playCallTone('stop');
              _durationSeconds = 0;
              _startTimer();
              _initCallAudio();
              notifyListeners();

              if (_isOutgoing) {
                WebRTCCallService.instance.ensureOfferCreatedAndSent();
              }
            }

            // Fetch signals to discover remote peer's direct IP & WebRTC signals
            try {
              final sigResp = await ApiClient.instance.get(ApiEndpoints.callSignals(curCallId));
              if (sigResp.isSuccess && sigResp.rawJson is List) {
                for (final item in sigResp.rawJson) {
                  if (item is Map && item['fromUserId'] != ApiClient.instance.userId) {
                    final sig = item['signal'];
                    if (sig is Map) {
                      final type = ((sig['type'] as String?) ?? '').toUpperCase();
                      if (type == 'WEBRTC_OFFER' || type == 'WEBRTC_ANSWER' || type == 'ICE_CANDIDATE') {
                        WebRTCCallService.instance.handleRemoteSignal(Map<String, dynamic>.from(sig));
                      } else if (type == 'AUDIO_P2P') {
                        final peerIp = (sig['ip'] as String?) ?? (item['clientIp'] as String?) ?? '';
                        final peerPort = (sig['port'] as int?) ?? (_isOutgoing ? 50006 : 50005);
                        if (peerIp.isNotEmpty && peerIp != '127.0.0.1' && !peerIp.contains('localhost')) {
                          _audioChannel.invokeMethod('updatePeerAddress', {
                            'ip': peerIp,
                            'port': peerPort,
                          }).catchError((_) {});
                        }
                      }
                    }
                  }
                }
              }
            } catch (_) {}
          } else if (callState == 'REJECTED') {
            if (_status != CallStatus.rejected) {
              _status = CallStatus.rejected;
              _playCallTone('busy');
              notifyListeners();

              // Insert to local database
              _saveCallLog(status: 'rejected');

              Future.delayed(const Duration(milliseconds: 1800), () {
                endCall();
              });
            }
          } else if (callState == 'ENDED') {
            if (_status != CallStatus.ended) {
              final finalDur = _durationSeconds;
              final isOut = _isOutgoing;
              final logStatus = finalDur > 0 ? 'completed' : (isOut ? 'cancelled' : 'missed');

              _playCallTone('stop');
              _status = CallStatus.ended;

              // Insert to local database first so UI gets updated immediately
              await _saveCallLog(status: logStatus, duration: finalDur);

              notifyListeners();

              Future.delayed(const Duration(milliseconds: 1000), () {
                endCall();
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  void _stopCallStatusPoller() {
    _statusPoller?.cancel();
    _statusPoller = null;
  }

  Future<void> _initCallAudio() async {
    try {
      final hasPerm = await _audioChannel.invokeMethod<bool>('hasRecordPermission') ?? false;
      if (!hasPerm) {
        await _audioChannel.invokeMethod('requestRecordPermission');
      }

      // Configure native audio routing to MODE_IN_COMMUNICATION & speaker/earpiece
      final useSpeaker = _isSpeaker || _isVideo;
      await _audioChannel.invokeMethod('setSpeaker', {'speaker': useSpeaker});
      WebRTCCallService.instance.setSpeakerphone(useSpeaker);
    } catch (_) {}
  }

  Future<void> _stopCallAudio() async {
    try {
      await _audioChannel.invokeMethod('stopCallAudio');
      await _audioChannel.invokeMethod('setSpeaker', {'speaker': false});
    } catch (_) {}
  }

  Future<void> _playCallTone(String type) async {
    try {
      await _audioChannel.invokeMethod('playCallTone', {'type': type});
    } catch (_) {}
  }

  void minimize() {
    if (!_isActive) return;
    _isMinimized = true;
    notifyListeners();
  }

  void restore() {
    if (!_isActive) return;
    _isMinimized = false;
    notifyListeners();

    final nav = AppNavigation.navigatorKey.currentState;
    if (nav == null) return;

    if (_isGroup) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ActiveGroupCallScreen(
            groupName: _groupName ?? _title,
            initialParticipants: _participants,
            isVideo: _isVideo,
            returnToCallsScreen: false,
          ),
        ),
      );
    } else {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ActiveCallScreen(
            contactName: _title,
            isVideo: _isVideo,
            calleeUserId: _contactUserId,
            contactPhone: _contactPhone,
            avatarUrl: _avatarUrl,
            returnToCallsScreen: false,
          ),
        ),
      );
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _audioChannel.invokeMethod('setMute', {'muted': _isMuted}).catchError((_) {});
    WebRTCCallService.instance.setMicrophoneMuted(_isMuted);
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOn = !_isVideoOn;
    WebRTCCallService.instance.setCameraEnabled(_isVideoOn);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await WebRTCCallService.instance.switchCamera();
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    _audioChannel.invokeMethod('setSpeaker', {'speaker': _isSpeaker}).catchError((_) {});
    WebRTCCallService.instance.setSpeakerphone(_isSpeaker);
    notifyListeners();
  }

  void endCall() {
    final curCallId = _callId;
    final finalDur = _durationSeconds;
    final finalStatus = _status;
    final isOut = _isOutgoing;

    _timer?.cancel();
    _stopCallStatusPoller();
    _stopCallAudio();
    _playCallTone('stop');

    // Ensure call log is recorded if not logged yet
    if (!_hasLoggedCurrentCall && (_title.isNotEmpty || _contactUserId != null || _contactPhone != null)) {
      String logStatus;
      if (finalStatus == CallStatus.connected || finalDur > 0) {
        logStatus = 'completed';
      } else if (finalStatus == CallStatus.rejected) {
        logStatus = 'rejected';
      } else {
        logStatus = isOut ? 'cancelled' : 'missed';
      }
      _saveCallLog(status: logStatus, duration: finalDur);
    }

    WebRTCCallService.instance.dispose().catchError((_) {});
    _isActive = false;
    _isMinimized = false;
    _status = CallStatus.ended;
    _durationSeconds = 0;
    _callId = null;
    notifyListeners();

    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': false}).catchError((_) {});

    if (curCallId != null) {
      _dispatchEndCallToBackend(curCallId);
    }
  }

  Future<void> _saveCallLog({required String status, int? duration}) async {
    if (_hasLoggedCurrentCall) return;
    _hasLoggedCurrentCall = true;

    final resolvedTitle = _title.trim().isNotEmpty
        ? _title.trim()
        : (_contactPhone?.trim().isNotEmpty == true
            ? _contactPhone!.trim()
            : (_contactUserId?.trim().isNotEmpty == true
                ? _contactUserId!.trim()
                : (_isOutgoing ? 'Panggilan Keluar' : 'Panggilan Masuk')));

    final resolvedAvatar = _avatarUrl ?? _resolveAvatar(_contactUserId, _contactPhone, resolvedTitle);
    final logId = (_callId != null && !_callId!.startsWith('call-') && !_callId!.startsWith('group-'))
        ? _callId!
        : 'call-log-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await LocalDatabase.instance.insertCallLog(
        id: logId,
        contactName: resolvedTitle,
        contactId: _contactUserId,
        contactPhone: _contactPhone,
        avatarUrl: resolvedAvatar,
        isVideo: _isVideo,
        isOutgoing: _isOutgoing,
        status: status,
        durationSeconds: duration ?? _durationSeconds,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      DataStorageController.instance.recordCallStats(
        durationSeconds: duration ?? _durationSeconds,
        isVideo: _isVideo,
      );
    } catch (e) {
      debugPrint('[CallSessionController] insertCallLog error: $e');
    }
    notifyListeners();
  }

  void _dispatchCallToBackend(String callee, {bool isVideo = false}) async {
    try {
      if (ApiClient.instance.authToken != null) {
        final resp = await ApiClient.instance.post(
          ApiEndpoints.calls,
          body: {
            'calleeUserId': callee,
            'isVideo': isVideo,
          },
        );
        if (resp.isSuccess && resp.rawJson is Map && resp.rawJson['id'] != null) {
          _callId = resp.rawJson['id'];
          _handledCallIds.add(_callId!);
          _startCallStatusPoller();
          WebRTCCallService.instance.connectSignaling(
            callId: _callId!,
            isInitiator: true,
            remoteUserId: callee,
          ).catchError((_) {});
        } else if (resp.statusCode == 409 ||
            (resp.rawJson is Map &&
                (resp.rawJson['message']?.toString().contains('panggilan lain') == true ||
                 resp.rawJson['message']?.toString().contains('Sibuk') == true))) {
          _status = CallStatus.busy;
          _playCallTone('busy');
          notifyListeners();
          final ctx = AppNavigation.navigatorKey.currentContext;
          if (ctx != null) {
            LajuToast.info(ctx, 'Kontak sedang berada dalam panggilan lain');
          }
          Future.delayed(const Duration(milliseconds: 2500), () {
            endCall();
          });
        }
      }
    } catch (_) {}
  }

  void _dispatchGroupCallToBackend(String conversationId, {bool isVideo = false}) async {
    try {
      if (ApiClient.instance.authToken != null) {
        final resp = await ApiClient.instance.post(
          ApiEndpoints.callGroup,
          body: {
            'conversationId': conversationId,
            'isVideo': isVideo,
          },
        );
        if (resp.isSuccess && resp.rawJson is Map && resp.rawJson['id'] != null) {
          final realId = resp.rawJson['id'].toString();
          _callId = realId;
          _handledCallIds.add(realId);
          _startCallStatusPoller();
          WebRTCCallService.instance.connectSignaling(
            callId: realId,
            isInitiator: true,
          ).catchError((_) {});
        } else {
          WebRTCCallService.instance.connectSignaling(
            callId: _callId!,
            isInitiator: true,
          ).catchError((_) {});
        }
      }
    } catch (e) {
      debugPrint('[CallSessionController] _dispatchGroupCallToBackend error: $e');
      WebRTCCallService.instance.connectSignaling(
        callId: _callId!,
        isInitiator: true,
      ).catchError((_) {});
    }
  }

  void _dispatchEndCallToBackend(String id) async {
    try {
      if (ApiClient.instance.authToken != null && !id.startsWith('call-') && !id.startsWith('group-')) {
        await ApiClient.instance.post(ApiEndpoints.callEnd(id));
      }
    } catch (_) {}
  }

  /// Checks for any incoming calls targeting this user on the backend
  Future<void> checkForIncomingCalls() async {
    if (ApiClient.instance.authToken == null) return;

    if (_isActive) {
      // User is already busy in an active call!
      // Check if there is an incoming call targeting us, and immediately auto-reject it as BUSY so caller knows
      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.callIncoming);
        if (resp.isSuccess && resp.rawJson is Map) {
          final data = resp.rawJson;
          final incomingCallId = data['callId'] as String?;
          if (incomingCallId != null &&
              incomingCallId.isNotEmpty &&
              incomingCallId != _callId &&
              !_handledCallIds.contains(incomingCallId)) {
            _handledCallIds.add(incomingCallId);
            await ApiClient.instance.post(ApiEndpoints.callReject(incomingCallId));
          }
        }
      } catch (_) {}
      return;
    }

    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.callIncoming);
      // RE-CHECK: user could have answered or started a call while awaiting HTTP
      if (_isActive) return;

      if (resp.isSuccess && resp.rawJson is Map) {
        final data = resp.rawJson;
        final incomingCallId = data['callId'] as String?;
        final callerName = data['initiatorName'] as String? ?? 'Kontak';
        final callerId = data['initiatorId'] as String?;
        final callerPhone = data['initiatorPhone'] as String?;
        final callerAvatar = (data['initiatorAvatar'] as String?) ?? (data['avatarUrl'] as String?);
        final resolvedAvatar = callerAvatar ?? _resolveAvatar(callerId, callerPhone, callerName);
        final isVideo = data['isVideo'] == true;
        final isGroup = data['isGroup'] == true;
        final groupName = data['groupName'] as String?;
        final conversationId = data['conversationId'] as String?;
        final effectiveDisplayName = isGroup && groupName != null && groupName.isNotEmpty
            ? groupName
            : callerName;

        if (incomingCallId != null &&
            incomingCallId != _callId &&
            !_handledCallIds.contains(incomingCallId) &&
            incomingCallId != _lastRingingCallId &&
            incomingCallId != _declinedCallId) {
          _lastRingingCallId = incomingCallId;
          _lastRingingCallerName = effectiveDisplayName;
          _lastRingingCallerId = callerId;
          _lastRingingCallerPhone = callerPhone;
          _lastRingingCallerAvatar = resolvedAvatar;
          _lastRingingIsVideo = isVideo;
          _status = CallStatus.ringing;

          final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

          if (isForeground) {
            // Foreground: ONLY show in-app popup overlay banner. Cancel any system notification.
            _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
            _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
            AppNotificationService.instance.showIncomingCall(
              callerName: isGroup ? '$effectiveDisplayName (Grup)' : effectiveDisplayName,
              isVideo: isVideo,
              avatarUrl: resolvedAvatar,
              onAccept: () {
                if (isGroup) {
                  answerIncomingGroupCall(
                    incomingCallId,
                    groupName: effectiveDisplayName,
                    conversationId: conversationId,
                    isVideo: isVideo,
                    callerName: callerName,
                  );
                } else {
                  answerIncomingCall(
                    incomingCallId,
                    callerName: callerName,
                    isVideo: isVideo,
                    callerId: callerId,
                    callerPhone: callerPhone,
                    avatarUrl: resolvedAvatar,
                  );
                }
              },
              onDecline: () => declineIncomingCall(
                incomingCallId,
                callerName: effectiveDisplayName,
                isVideo: isVideo,
                callerId: callerId,
                callerPhone: callerPhone,
                avatarUrl: resolvedAvatar,
              ),
            );
          } else {
            // Background / Minimized: Trigger native Android system notification
            _systemNotifChannel.invokeMethod('showCallNotification', {
              'callId': incomingCallId,
              'callerName': isGroup ? '$effectiveDisplayName (Grup)' : effectiveDisplayName,
              'isVideo': isVideo,
            }).catchError((_) {});
          }
        }
      } else {
        _declinedCallId = null;
        if (_lastRingingCallId != null && !_isActive) {
          // Caller ended or cancelled before receiver answered -> Log as missed call!
          final missedCallId = _lastRingingCallId;
          final missedName = _lastRingingCallerName ?? 'Panggilan';
          final missedId = _lastRingingCallerId;
          final missedPhone = _lastRingingCallerPhone;
          final missedAvatar = _lastRingingCallerAvatar ?? _resolveAvatar(missedId, missedPhone, missedName);
          final missedIsVideo = _lastRingingIsVideo;
          final logId = (missedCallId != null && missedCallId.isNotEmpty && !missedCallId.startsWith('call-'))
              ? missedCallId
              : 'call-log-${DateTime.now().millisecondsSinceEpoch}';

          LocalDatabase.instance.insertCallLog(
            id: logId,
            contactName: missedName,
            contactId: missedId,
            contactPhone: missedPhone,
            avatarUrl: missedAvatar,
            isVideo: missedIsVideo,
            isOutgoing: false,
            status: 'missed',
            durationSeconds: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

          if (missedCallId != null) {
            _handledCallIds.add(missedCallId);
          }
          _lastRingingCallId = null;
          _lastRingingCallerName = null;
          _lastRingingCallerId = null;
          _lastRingingCallerPhone = null;
          _lastRingingCallerAvatar = null;
          _status = CallStatus.idle;
          AppNotificationService.instance.dismissAll();
          _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
          _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
          _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': false}).catchError((_) {});
          notifyListeners();
        }
      }

    } catch (_) {}
  }

  void showIncomingCallScreen({
    required String callId,
    required String callerName,
    required bool isVideo,
    String? callerId,
    String? callerPhone,
    String? avatarUrl,
    bool isGroup = false,
    String? groupName,
    String? conversationId,
  }) {
    if (_isActive && _status == CallStatus.connected) return;
    if (_currentIncomingCallId == callId) return;
    _currentIncomingCallId = callId;
    _status = CallStatus.ringing;

    _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': true}).catchError((_) {});

    void pushScreen() {
      final nav = AppNavigation.navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: avatarUrl,
              isGroup: isGroup,
              groupName: groupName,
              conversationId: conversationId,
            ),
          ),
        ).then((_) {
          if (_currentIncomingCallId == callId) {
            _currentIncomingCallId = null;
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_currentIncomingCallId == callId) {
            pushScreen();
          }
        });
      }
    }

    pushScreen();
  }

  void _initChannelHandler() {
    _systemNotifChannel.setMethodCallHandler((call) async {
      if (call.method == 'onCallAction') {
        final args = call.arguments as Map?;
        final callId = args?['callId'] as String?;
        final action = args?['action'] as String?;
        final isVideo = args?['isVideo'] == true;
        final callerName = (args?['callerName'] as String?) ?? 'Panggilan';
        final callerId = args?['callerId'] as String?;
        final callerPhone = args?['callerPhone'] as String?;
        final callerAvatar = (args?['avatarUrl'] as String?) ?? _resolveAvatar(callerId, callerPhone, callerName);
        if (callId != null && callId.isNotEmpty) {
          if (action == 'incoming_call') {
            showIncomingCallScreen(
              callId: callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          } else if (action == 'answer') {
            await answerIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          } else if (action == 'decline') {
            await declineIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          }
        }
      } else if (call.method == 'onNewMessage') {
        final args = call.arguments as Map?;
        final convId = args?['conversationId'] as String?;
        ConversationService.instance.fetchConversations().catchError((_) => <ConversationModel>[]);
        if (convId != null && convId.isNotEmpty) {
          ConversationService.instance.fetchMessages(convId).catchError((_) => <MessageModel>[]);
        }
      }
    });
  }

  Future<void> answerIncomingGroupCall(
    String incomingCallId, {
    required String groupName,
    required String? conversationId,
    required bool isVideo,
    String? callerName,
  }) async {
    _isActive = true;
    _handledCallIds.add(incomingCallId);
    _lastRingingCallId = incomingCallId;
    _lastRingingCallerName = null;
    _lastRingingCallerId = null;
    _lastRingingCallerPhone = null;
    _lastRingingCallerAvatar = null;
    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
    _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': true}).catchError((_) {});
    AppNotificationService.instance.dismissAll();

    var effectiveIsVideo = isVideo;
    final permResult = await CallPermissionService.instance.checkAndRequestPermissions(
      isVideo: isVideo,
      context: AppNavigation.navigatorKey.currentContext,
    );

    if (permResult == CallPermissionResult.denied) {
      await declineIncomingCall(
        incomingCallId,
        callerName: groupName,
        isVideo: isVideo,
      );
      return;
    }

    if (isVideo && permResult == CallPermissionResult.audioOnlyGranted) {
      effectiveIsVideo = false;
    }

    _stopCallAudio();
    _callId = incomingCallId;
    _title = groupName;
    _groupName = groupName;
    _isGroup = true;
    _isOutgoing = false;
    _isVideo = effectiveIsVideo;
    _isVideoOn = effectiveIsVideo;
    _isSpeaker = true;
    _durationSeconds = 0;
    _hasLoggedCurrentCall = false;
    _status = CallStatus.connected;
    _startTimer();
    _initCallAudio();
    _startCallStatusPoller();

    WebRTCCallService.instance.initializePeerConnection(
      isVideo: effectiveIsVideo,
      isAudio: true,
    ).catchError((_) {});

    WebRTCCallService.instance.connectSignaling(
      callId: incomingCallId,
      isInitiator: false,
    ).catchError((_) {});

    notifyListeners();

    try {
      await ApiClient.instance.post(ApiEndpoints.callAccept(incomingCallId));
    } catch (_) {}

    AppNavigation.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ActiveGroupCallScreen(
          groupName: groupName,
          initialParticipants: callerName != null ? [callerName] : [],
          isVideo: effectiveIsVideo,
          conversationId: conversationId,
          returnToCallsScreen: false,
        ),
      ),
    );
  }

  Future<void> answerIncomingCall(
    String incomingCallId, {
    required String callerName,
    required bool isVideo,
    String? callerId,
    String? callerPhone,
    String? avatarUrl,
  }) async {
    // Immediately stop ringing, dismiss all banners/notifications, and flag session active
    _isActive = true;
    _handledCallIds.add(incomingCallId);
    _lastRingingCallId = incomingCallId;
    _lastRingingCallerName = null;
    _lastRingingCallerId = null;
    _lastRingingCallerPhone = null;
    _lastRingingCallerAvatar = null;
    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
    _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': true}).catchError((_) {});
    AppNotificationService.instance.dismissAll();

    var effectiveIsVideo = isVideo;
    final permResult = await CallPermissionService.instance.checkAndRequestPermissions(
      isVideo: isVideo,
      context: AppNavigation.navigatorKey.currentContext,
    );

    if (permResult == CallPermissionResult.denied) {
      await declineIncomingCall(
        incomingCallId,
        callerName: callerName,
        isVideo: isVideo,
        callerId: callerId,
        callerPhone: callerPhone,
        avatarUrl: avatarUrl,
      );
      return;
    }

    if (isVideo && permResult == CallPermissionResult.audioOnlyGranted) {
      effectiveIsVideo = false;
    }

    _stopCallAudio();
    _callId = incomingCallId;
    _title = callerName;
    _contactUserId = callerId;
    _contactPhone = callerPhone;
    _avatarUrl = avatarUrl ?? _resolveAvatar(callerId, callerPhone, callerName);
    _isOutgoing = false;
    _isVideo = effectiveIsVideo;
    _isVideoOn = effectiveIsVideo;
    _isSpeaker = effectiveIsVideo;
    _durationSeconds = 0;
    _hasLoggedCurrentCall = false;
    _status = CallStatus.connected;
    _startTimer();
    _initCallAudio();
    _startCallStatusPoller();
    WebRTCCallService.instance.connectSignaling(
      callId: incomingCallId,
      isInitiator: false,
      remoteUserId: callerId,
    ).catchError((_) {});
    WebRTCCallService.instance.initializePeerConnection(
      isVideo: effectiveIsVideo,
      isAudio: true,
    ).catchError((_) {});
    notifyListeners();

    try {
      await ApiClient.instance.post(ApiEndpoints.callAccept(incomingCallId));
    } catch (_) {}

    AppNavigation.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          contactName: callerName,
          isVideo: effectiveIsVideo,
          calleeUserId: callerId,
          contactPhone: callerPhone,
          avatarUrl: _avatarUrl,
          returnToCallsScreen: false,
        ),
      ),
    );
  }

  Future<void> declineIncomingCall(
    String incomingCallId, {
    required String callerName,
    required bool isVideo,
    String? callerId,
    String? callerPhone,
    String? avatarUrl,
  }) async {
    _isActive = false;
    _status = CallStatus.idle;
    _declinedCallId = incomingCallId;
    _handledCallIds.add(incomingCallId);
    _lastRingingCallId = null;
    _lastRingingCallerName = null;
    _lastRingingCallerId = null;
    _lastRingingCallerPhone = null;
    _lastRingingCallerAvatar = null;
    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    _systemNotifChannel.invokeMethod('cancelAll').catchError((_) {});
    _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': false}).catchError((_) {});
    AppNotificationService.instance.dismissAll();

    final resolvedAvatar = avatarUrl ?? _resolveAvatar(callerId, callerPhone, callerName);
    final logId = (incomingCallId.isNotEmpty && !incomingCallId.startsWith('call-'))
        ? incomingCallId
        : 'call-log-${DateTime.now().millisecondsSinceEpoch}';
    LocalDatabase.instance.insertCallLog(
      id: logId,
      contactName: callerName,
      contactId: callerId ?? 'unknown',
      contactPhone: callerPhone,
      avatarUrl: resolvedAvatar,
      isVideo: isVideo,
      isOutgoing: false,
      status: 'rejected',
      durationSeconds: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await ApiClient.instance.post(ApiEndpoints.callReject(incomingCallId));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> checkLaunchPayload() async {
    try {
      final payload = await _systemNotifChannel.invokeMapMethod<String, dynamic>('getLaunchPayload');
      if (payload != null && payload['type'] == 'call') {
        final callId = payload['id'] as String?;
        final isVideo = payload['isVideo'] == true;
        final action = payload['action'] as String?;
        final callerName = (payload['callerName'] as String?) ?? 'Panggilan';
        final callerId = payload['callerId'] as String?;
        final callerPhone = payload['callerPhone'] as String?;
        final callerAvatar = (payload['avatarUrl'] as String?) ?? _resolveAvatar(callerId, callerPhone, callerName);
        if (callId != null && callId.isNotEmpty) {
          if (action == 'incoming_call') {
            showIncomingCallScreen(
              callId: callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          } else if (action == 'answer') {
            await answerIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          } else if (action == 'decline') {
            await declineIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
              avatarUrl: callerAvatar,
            );
          }
        }
      }
    } catch (_) {}
  }
}
