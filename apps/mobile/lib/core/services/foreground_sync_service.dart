import 'dart:async';
import 'package:flutter/widgets.dart';
import '../network/api_client.dart';
import '../../features/calls/domain/call_session_controller.dart';
import '../../features/conversations/domain/conversation_service.dart';

/// Global background/foreground synchronization service that monitors
/// incoming messages and incoming calls every 1.5 seconds.
class ForegroundSyncService with WidgetsBindingObserver {
  ForegroundSyncService._();
  static final ForegroundSyncService instance = ForegroundSyncService._();

  Timer? _poller;
  bool _isPolling = false;
  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  void start() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      tick();
    });
    // Fire an immediate tick
    tick();
  }

  void stop() {
    _poller?.cancel();
    _poller = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Keep slow-polling in background (every 8 seconds)
      _poller?.cancel();
      _poller = Timer.periodic(const Duration(seconds: 8), (_) {
        tick();
      });
    }
  }

  Future<void> tick() async {
    if (_isPolling || ApiClient.instance.authToken == null) return;
    _isPolling = true;
    try {
      await Future.wait([
        CallSessionController.instance.checkForIncomingCalls(),
        ConversationService.instance.syncForegroundMessages(),
      ]);
    } catch (_) {
    } finally {
      _isPolling = false;
    }
  }
}
