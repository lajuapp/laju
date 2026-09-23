import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/core.dart';
import '../presentation/screens/active_call_screen.dart';
import '../presentation/screens/active_group_call_screen.dart';

enum CallStatus {
  idle,
  connecting,
  ringing,
  connected,
  rejected,
  ended,
}

class CallSessionController extends ChangeNotifier {
  CallSessionController._() {
    _initChannelHandler();
    _startIncomingCallPoller();
    checkLaunchPayload();
  }
  static final CallSessionController instance = CallSessionController._();

  static const MethodChannel _audioChannel = MethodChannel('com.laju/call_audio');
  static const MethodChannel _systemNotifChannel = MethodChannel('com.laju/system_notifications');

  String? _callId;
  String _title = '';
  String? _contactUserId;
  String? _contactPhone;
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
  CallStatus _status = CallStatus.idle;

  Timer? _timer;
  Timer? _incomingCallPoller;
  Timer? _statusPoller;
  String? _declinedCallId;
  String? _lastRingingCallId;

  // Getters
  String? get callId => _callId;
  String get title => _title;
  String? get contactUserId => _contactUserId;
  String? get contactPhone => _contactPhone;
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

  void start1on1Call({
    required String contactName,
    required bool isVideo,
    String? calleeUserId,
    String? contactPhone,
  }) {
    _stopCallAudio();
    _playCallTone('stop');
    _timer?.cancel();
    _statusPoller?.cancel();

    _callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _title = contactName;
    _contactUserId = calleeUserId;
    _contactPhone = contactPhone;
    _groupName = null;
    _isGroup = false;
    _isVideo = isVideo;
    _isOutgoing = true;
    _participants = [contactName];
    _durationSeconds = 0;
    _isMuted = false;
    _isVideoOn = isVideo;
    _isSpeaker = isVideo;
    _isMinimized = false;
    _isActive = true;
    _status = CallStatus.connecting;

    _dispatchCallToBackend(calleeUserId ?? contactPhone ?? contactName, isVideo: isVideo);
    notifyListeners();
  }

  void startGroupCall({
    required String groupName,
    required List<String> initialParticipants,
    required bool isVideo,
  }) {
    _stopCallAudio();
    _playCallTone('stop');
    _timer?.cancel();
    _statusPoller?.cancel();

    _callId = 'group-call-${DateTime.now().millisecondsSinceEpoch}';
    _title = groupName;
    _groupName = groupName;
    _isGroup = true;
    _isVideo = isVideo;
    _isOutgoing = true;
    _participants = List.from(initialParticipants);
    _durationSeconds = 0;
    _isMuted = false;
    _isVideoOn = isVideo;
    _isSpeaker = true;
    _isMinimized = false;
    _isActive = true;
    _status = CallStatus.connected;

    _startTimer();
    _initCallAudio();
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
            }

            // Fetch signals to discover remote peer's direct IP
            try {
              final sigResp = await ApiClient.instance.get(ApiEndpoints.callSignals(curCallId));
              if (sigResp.isSuccess && sigResp.rawJson is List) {
                for (final item in sigResp.rawJson) {
                  if (item is Map && item['fromUserId'] != ApiClient.instance.userId) {
                    final sig = item['signal'];
                    if (sig is Map && sig['type'] == 'AUDIO_P2P') {
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
              _status = CallStatus.ended;
              _playCallTone('stop');
              notifyListeners();

              // Insert to local database
              _saveCallLog(status: _durationSeconds > 0 ? 'completed' : 'cancelled');

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
      final localIp = await _audioChannel.invokeMethod<String>('getLocalIp') ?? '127.0.0.1';

      // Exchange IP with peer over signaling
      if (_callId != null && !_callId!.startsWith('call-') && !_callId!.startsWith('group-')) {
        await ApiClient.instance.post(
          ApiEndpoints.callSignal(_callId!),
          body: {
            'signal': {
              'type': 'AUDIO_P2P',
              'ip': localIp,
              'port': _isOutgoing ? 50005 : 50006,
            }
          },
        );
      }

      // Start native audio engine (default to local subnet broadcast/peer)
      final remotePort = _isOutgoing ? 50006 : 50005;
      final localPort = _isOutgoing ? 50005 : 50006;

      await _audioChannel.invokeMethod('startCallAudio', {
        'remoteIp': '255.255.255.255', // Subnet broadcast allows instant P2P audio connection on LAN
        'remotePort': remotePort,
        'localPort': localPort,
        'isSpeaker': _isSpeaker || _isVideo,
        'isVideo': _isVideo,
        'baseUrl': EnvConfig.instance.apiBaseUrl,
        'callId': _callId ?? '',
        'token': ApiClient.instance.authToken ?? '',
      });
    } catch (_) {}
  }

  Future<void> _stopCallAudio() async {
    try {
      await _audioChannel.invokeMethod('stopCallAudio');
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
            returnToCallsScreen: false,
          ),
        ),
      );
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _audioChannel.invokeMethod('setMute', {'muted': _isMuted}).catchError((_) {});
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOn = !_isVideoOn;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    _audioChannel.invokeMethod('setSpeaker', {'speaker': _isSpeaker}).catchError((_) {});
    notifyListeners();
  }

  void endCall() {
    final curCallId = _callId;
    final finalDur = _durationSeconds;
    final finalStatus = _status;

    _timer?.cancel();
    _stopCallStatusPoller();
    _stopCallAudio();
    _playCallTone('stop');

    if (finalStatus == CallStatus.connected) {
      _saveCallLog(status: 'completed', duration: finalDur);
    } else if (finalStatus == CallStatus.ringing || finalStatus == CallStatus.connecting) {
      _saveCallLog(status: _isOutgoing ? 'cancelled' : 'missed', duration: 0);
    }

    _isActive = false;
    _isMinimized = false;
    _status = CallStatus.ended;
    _durationSeconds = 0;
    _callId = null;
    notifyListeners();

    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});

    if (curCallId != null) {
      _dispatchEndCallToBackend(curCallId);
    }

    // Auto-pop active call screen if visible
    final nav = AppNavigation.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.maybePop();
    }
  }

  void _saveCallLog({required String status, int? duration}) {
    if (_title.isEmpty) return;
    LocalDatabase.instance.insertCallLog(
      id: 'call-log-${DateTime.now().millisecondsSinceEpoch}',
      contactName: _title,
      contactId: _contactUserId,
      contactPhone: _contactPhone,
      isVideo: _isVideo,
      isOutgoing: _isOutgoing,
      status: status,
      durationSeconds: duration ?? _durationSeconds,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
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
          _startCallStatusPoller();
        }
      }
    } catch (_) {}
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
    if (_isActive || ApiClient.instance.authToken == null) return;
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.callIncoming);
      if (resp.isSuccess && resp.rawJson is Map) {
        final data = resp.rawJson;
        final incomingCallId = data['callId'] as String?;
        final callerName = data['initiatorName'] as String? ?? 'Kontak';
        final callerId = data['initiatorId'] as String?;
        final callerPhone = data['initiatorPhone'] as String?;
        final isVideo = data['isVideo'] == true;

        if (incomingCallId != null &&
            incomingCallId != _lastRingingCallId &&
            incomingCallId != _declinedCallId) {
          _lastRingingCallId = incomingCallId;

          // Trigger native Android system notification with ringing tone and full-screen heads-up
          _systemNotifChannel.invokeMethod('showCallNotification', {
            'callId': incomingCallId,
            'callerName': callerName,
            'isVideo': isVideo,
          }).catchError((_) {});

          AppNotificationService.instance.showIncomingCall(
            callerName: callerName,
            isVideo: isVideo,
            onAccept: () => answerIncomingCall(
              incomingCallId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
              callerPhone: callerPhone,
            ),
            onDecline: () => declineIncomingCall(
              incomingCallId,
              callerName: callerName,
              isVideo: isVideo,
              callerId: callerId,
            ),
          );
        }
      } else {
        _declinedCallId = null;
        if (_lastRingingCallId != null) {
          _lastRingingCallId = null;
          AppNotificationService.instance.dismiss();
          _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
        }
      }
    } catch (_) {}
  }

  void _initChannelHandler() {
    _systemNotifChannel.setMethodCallHandler((call) async {
      if (call.method == 'onCallAction') {
        final args = call.arguments as Map?;
        final callId = args?['callId'] as String?;
        final action = args?['action'] as String?;
        final isVideo = args?['isVideo'] == true;
        final callerName = (args?['callerName'] as String?) ?? 'Panggilan';
        if (callId != null && callId.isNotEmpty) {
          if (action == 'answer') {
            await answerIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
            );
          } else if (action == 'decline') {
            await declineIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
            );
          }
        }
      }
    });
  }

  Future<void> answerIncomingCall(
    String incomingCallId, {
    required String callerName,
    required bool isVideo,
    String? callerId,
    String? callerPhone,
  }) async {
    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    AppNotificationService.instance.dismiss();

    _stopCallAudio();
    _callId = incomingCallId;
    _title = callerName;
    _contactUserId = callerId;
    _contactPhone = callerPhone;
    _isActive = true;
    _isOutgoing = false;
    _isVideo = isVideo;
    _isVideoOn = isVideo;
    _isSpeaker = isVideo;
    _durationSeconds = 0;
    _status = CallStatus.connected;
    _startTimer();
    _initCallAudio();
    _startCallStatusPoller();
    notifyListeners();

    try {
      await ApiClient.instance.post(ApiEndpoints.callAccept(incomingCallId));
    } catch (_) {}

    AppNavigation.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          contactName: callerName,
          isVideo: isVideo,
          calleeUserId: callerId,
          contactPhone: callerPhone,
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
  }) async {
    _systemNotifChannel.invokeMethod('cancelNotification', {'id': 9999}).catchError((_) {});
    AppNotificationService.instance.dismiss();

    _declinedCallId = incomingCallId;
    _lastRingingCallId = null;
    LocalDatabase.instance.insertCallLog(
      id: 'call-log-${DateTime.now().millisecondsSinceEpoch}',
      contactName: callerName,
      contactId: callerId ?? 'unknown',
      isVideo: isVideo,
      isOutgoing: false,
      status: 'rejected',
      durationSeconds: 0,
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
        if (callId != null && callId.isNotEmpty) {
          if (action == 'answer') {
            await answerIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
            );
          } else if (action == 'decline') {
            await declineIncomingCall(
              callId,
              callerName: callerName,
              isVideo: isVideo,
            );
          }
        }
      }
    } catch (_) {}
  }
}
