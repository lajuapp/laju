import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../presentation/screens/active_call_screen.dart';
import '../presentation/screens/active_group_call_screen.dart';

class CallSessionController extends ChangeNotifier {
  CallSessionController._();
  static final CallSessionController instance = CallSessionController._();

  String? _callId;
  String _title = '';
  String? _groupName;
  bool _isGroup = false;
  bool _isVideo = false;
  List<String> _participants = [];
  int _durationSeconds = 0;
  bool _isMuted = false;
  bool _isVideoOn = false;
  bool _isSpeaker = false;
  bool _isMinimized = false;
  bool _isActive = false;

  Timer? _timer;

  // Getters
  String? get callId => _callId;
  String get title => _title;
  String? get groupName => _groupName;
  bool get isGroup => _isGroup;
  bool get isVideo => _isVideo;
  List<String> get participants => _participants;
  int get durationSeconds => _durationSeconds;
  bool get isMuted => _isMuted;
  bool get isVideoOn => _isVideoOn;
  bool get isSpeaker => _isSpeaker;
  bool get isMinimized => _isMinimized;
  bool get isActive => _isActive;

  String get formattedDuration {
    final minutes = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void start1on1Call({
    required String contactName,
    required bool isVideo,
  }) {
    _timer?.cancel();
    _callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _title = contactName;
    _groupName = null;
    _isGroup = false;
    _isVideo = isVideo;
    _participants = [contactName];
    _durationSeconds = 0;
    _isMuted = false;
    _isVideoOn = isVideo;
    _isSpeaker = false;
    _isMinimized = false;
    _isActive = true;

    _startTimer();
    _dispatchCallToBackend(contactName);
    notifyListeners();
  }

  void startGroupCall({
    required String groupName,
    required List<String> initialParticipants,
    required bool isVideo,
  }) {
    _timer?.cancel();
    _callId = 'group-call-${DateTime.now().millisecondsSinceEpoch}';
    _title = groupName;
    _groupName = groupName;
    _isGroup = true;
    _isVideo = isVideo;
    _participants = List.from(initialParticipants);
    _durationSeconds = 0;
    _isMuted = false;
    _isVideoOn = isVideo;
    _isSpeaker = true;
    _isMinimized = false;
    _isActive = true;

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive) {
        timer.cancel();
        return;
      }
      _durationSeconds++;
      notifyListeners();
    });
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
            returnToCallsScreen: false,
          ),
        ),
      );
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOn = !_isVideoOn;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    notifyListeners();
  }

  void endCall() {
    final curCallId = _callId;
    _timer?.cancel();
    _isActive = false;
    _isMinimized = false;
    _durationSeconds = 0;
    _callId = null;
    notifyListeners();

    if (curCallId != null) {
      _dispatchEndCallToBackend(curCallId);
    }
  }

  void _dispatchCallToBackend(String callee) async {
    try {
      if (ApiClient.instance.authToken != null) {
        final resp = await ApiClient.instance.post(
          ApiEndpoints.calls,
          body: {'calleeUserId': callee},
        );
        if (resp.isSuccess && resp.rawJson is Map && resp.rawJson['id'] != null) {
          _callId = resp.rawJson['id'];
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

  String? _lastRingingCallId;

  /// Checks for any incoming calls targeting this user on the backend
  Future<void> checkForIncomingCalls() async {
    if (_isActive || ApiClient.instance.authToken == null) return;
    try {
      final resp = await ApiClient.instance.get(ApiEndpoints.callIncoming);
      if (resp.isSuccess && resp.rawJson is Map) {
        final data = resp.rawJson;
        final incomingCallId = data['callId'] as String?;
        final callerName = data['initiatorName'] as String? ?? 'Kontak';
        if (incomingCallId != null && incomingCallId != _lastRingingCallId) {
          _lastRingingCallId = incomingCallId;
          AppNotificationService.instance.showIncomingCall(
            callerName: callerName,
            isVideo: false,
            onAccept: () async {
              _callId = incomingCallId;
              _title = callerName;
              _isActive = true;
              _durationSeconds = 0;
              _startTimer();
              notifyListeners();

              try {
                await ApiClient.instance.post(ApiEndpoints.callAccept(incomingCallId));
              } catch (_) {}

              AppNavigation.navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => ActiveCallScreen(
                    contactName: callerName,
                    isVideo: false,
                    returnToCallsScreen: false,
                  ),
                ),
              );
            },
            onDecline: () async {
              try {
                await ApiClient.instance.post(ApiEndpoints.callReject(incomingCallId));
              } catch (_) {}
            },
          );
        }
      } else {
        if (_lastRingingCallId != null) {
          _lastRingingCallId = null;
          AppNotificationService.instance.dismiss();
        }
      }
    } catch (_) {}
  }
}
