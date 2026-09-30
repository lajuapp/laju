import 'dart:async';
import 'package:flutter/widgets.dart';
import '../network/api_client.dart';
import '../widgets/app_notification_service.dart';
import '../../features/auth/domain/auth_controller.dart';
import '../../features/auth/presentation/widgets/transfer_approval_bottom_sheet.dart';
import '../../features/calls/domain/call_session_controller.dart';
import '../../features/conversations/domain/conversation_service.dart';

/// Global background/foreground synchronization service that monitors
/// incoming messages, incoming calls, and device transfer authorizations.
class ForegroundSyncService with WidgetsBindingObserver {
  ForegroundSyncService._();
  static final ForegroundSyncService instance = ForegroundSyncService._();

  Timer? _poller;
  bool _isPolling = false;
  bool _isInitialized = false;
  int _transferCheckTickCount = 0;

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
      CallSessionController.instance.checkLaunchPayload();
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
      final futures = <Future<dynamic>>[
        CallSessionController.instance.checkForIncomingCalls(),
        ConversationService.instance.syncForegroundMessages(),
      ];
      _transferCheckTickCount++;
      if (_transferCheckTickCount % 2 == 0) {
        futures.add(_checkDeviceTransferStatus());
      }
      await Future.wait(futures);
    } catch (_) {
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _checkDeviceTransferStatus() async {
    try {
      final res = await AuthController.instance.checkPendingTransferAsync();
      if (res == null) return;

      final isRevoked = res['isRevoked'] == true;
      if (isRevoked) {
        AuthController.instance.handleDeviceReplaced();
        return;
      }

      final pending = res['pendingTransfer'];
      if (pending is Map<String, dynamic>) {
        final reqId = pending['id']?.toString();
        final targetDeviceName =
            pending['targetDeviceName']?.toString() ?? 'Perangkat Baru';
        final targetPlatform =
            pending['targetPlatform']?.toString() ?? 'unknown';
        final expiresAtStr = pending['expiresAt']?.toString();
        final expiresAt =
            expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

        final ctx = AppNavigation.currentContext;
        if (ctx != null && ctx.mounted && reqId != null && !TransferApprovalBottomSheet.isOpen) {
          TransferApprovalBottomSheet.show(
            ctx,
            requestId: reqId,
            targetDeviceName: targetDeviceName,
            targetPlatform: targetPlatform,
            expiresAt: expiresAt,
          );
        }
      }
    } catch (_) {}
  }
}
