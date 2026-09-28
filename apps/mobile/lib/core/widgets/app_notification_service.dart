import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/core.dart';

class AppNavigation {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static BuildContext? get currentContext => navigatorKey.currentContext;
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool isCall;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isPopup;
  final String? senderName;
  final String? conversationId;
  final String? avatarUrl;
  final void Function(String replyText)? onQuickReply;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.icon = Icons.notifications_rounded,
    this.iconColor = AppColors.primary,
    this.onTap,
    this.isCall = false,
    this.onAccept,
    this.onDecline,
    this.isPopup = false,
    this.senderName,
    this.conversationId,
    this.avatarUrl,
    this.onQuickReply,
  });
}

class AppNotificationService extends ChangeNotifier {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  InAppNotificationItem? _currentNotification;
  InAppNotificationItem? _currentPopupNotification;
  Timer? _dismissTimer;
  bool Function()? isCallActiveChecker;

  InAppNotificationItem? get currentNotification => _currentNotification;
  InAppNotificationItem? get currentPopupNotification => _currentPopupNotification;

  void showNotification({
    required String title,
    required String message,
    IconData icon = Icons.notifications_rounded,
    Color iconColor = AppColors.primary,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
    String? senderName,
    String? avatarUrl,
    String? conversationId,
  }) {
    _dismissTimer?.cancel();
    _currentNotification = InAppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
      senderName: senderName,
      avatarUrl: avatarUrl,
      conversationId: conversationId,
    );
    notifyListeners();

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// Dispatches an incoming message notification, respecting user's sound, vibrate, high priority, and popup settings!
  Future<void> showIncomingMessage({
    required String conversationId,
    required String senderName,
    required String message,
    bool isGroup = false,
    String? avatarUrl,
    VoidCallback? onOpenChat,
    void Function(String replyText)? onQuickReply,
  }) async {
    // 1. Play real ringtone and vibrate according to saved preferences
    await LajuSoundService.playIncomingNotification(isGroup: isGroup);

    final prefs = await SharedPreferences.getInstance();
    final popupSetting = prefs.getString('notif_msg_popup') ?? 'Tanpa popup';
    final highPriority = prefs.getBool(isGroup ? 'notif_group_high_priority' : 'notif_msg_high_priority') ?? true;

    final shouldShowPopup = popupSetting == 'Selalu tampilkan popup' || popupSetting == 'Hanya saat layar aktif';

    if (shouldShowPopup) {
      _currentPopupNotification = InAppNotificationItem(
        id: 'msg-popup-${DateTime.now().millisecondsSinceEpoch}',
        title: senderName,
        message: message,
        senderName: senderName,
        conversationId: conversationId,
        avatarUrl: avatarUrl,
        isPopup: true,
        onTap: onOpenChat,
        onQuickReply: onQuickReply,
      );
      notifyListeners();
    } else if (highPriority) {
      showNotification(
        title: senderName,
        message: message,
        senderName: senderName,
        avatarUrl: avatarUrl,
        conversationId: conversationId,
        icon: isGroup ? Icons.group_rounded : Icons.chat_bubble_outline_rounded,
        iconColor: AppColors.primary,
        onTap: onOpenChat,
      );
    }
  }

  void showIncomingCall({
    required String callerName,
    required bool isVideo,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    String? avatarUrl,
  }) {
    if (isCallActiveChecker?.call() == true) {
      return;
    }
    _dismissTimer?.cancel();
    _currentNotification = InAppNotificationItem(
      id: 'incoming-call-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Panggilan Masuk',
      message: '$callerName • ${isVideo ? "Panggilan Video" : "Panggilan Suara"}',
      icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
      iconColor: AppColors.primary,
      isCall: true,
      senderName: callerName,
      avatarUrl: avatarUrl,
      onAccept: () {
        dismiss();
        onAccept();
      },
      onDecline: () {
        dismiss();
        onDecline();
      },
    );
    notifyListeners();

    try {
      LajuSoundService.playRingtone('Panggilan Masuk');
      LajuSoundService.triggerVibrate('Panjang');
    } catch (_) {
      try {
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }


  void dismissAll() {
    _dismissTimer?.cancel();
    try {
      LajuSoundService.stopRingtone();
    } catch (_) {}
    var changed = false;
    if (_currentNotification != null) {
      _currentNotification = null;
      changed = true;
    }
    if (_currentPopupNotification != null) {
      _currentPopupNotification = null;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void dismiss() {
    dismissAll();
  }

  void dismissPopup() {
    if (_currentPopupNotification != null) {
      _currentPopupNotification = null;
      notifyListeners();
    }
  }
}
