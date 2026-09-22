import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/call_session_controller.dart';

class FloatingCallOverlay extends StatefulWidget {
  final Widget child;

  const FloatingCallOverlay({super.key, required this.child});

  @override
  State<FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<FloatingCallOverlay> with SingleTickerProviderStateMixin {
  Offset _position = const Offset(16, 90);
  bool _isDragging = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _snapToEdge(Size screenSize) {
    final x = _position.dx < (screenSize.width / 2) ? 12.0 : screenSize.width - 232.0;
    final y = _position.dy.clamp(60.0, screenSize.height - 140.0);

    setState(() {
      _position = Offset(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        CallSessionController.instance,
        AppNotificationService.instance,
      ]),
      builder: (context, _) {
        final call = CallSessionController.instance;
        final notification = AppNotificationService.instance.currentNotification;
        final popupNotification = AppNotificationService.instance.currentPopupNotification;
        final showCallOverlay = call.isActive && call.isMinimized;

        return Stack(
          children: [
            // App Main Content
            widget.child,

            // Global In-App Notification Banner
            if (notification != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: Material(
                  color: Colors.transparent,
                  child: _buildNotificationBanner(context, notification, isDark),
                ),
              ),

            // Global In-App Popup Notification Dialog
            if (popupNotification != null)
              Positioned.fill(
                child: _buildPopupNotificationOverlay(context, popupNotification, isDark),
              ),

            // Draggable Floating Call Overlay (Picture-in-Picture)
            if (showCallOverlay)
              Positioned(
                left: _position.dx.clamp(8.0, screenSize.width - 236.0),
                top: _position.dy.clamp(50.0, screenSize.height - 120.0),
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _isDragging = false);
                    _snapToEdge(screenSize);
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: _buildFloatingCallWidget(context, call, isDark),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingCallWidget(BuildContext context, CallSessionController call, bool isDark) {
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return AnimatedScale(
      scale: _isDragging ? 1.04 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: 228,
        child: LajuGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          borderRadius: 20,
          blurSigma: 18,
          tintColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderColor: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceBorder,
          customShadow: [
            BoxShadow(
              color: (call.isMuted ? Colors.black : AppColors.primary).withValues(alpha: isDark ? 0.4 : 0.22),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
          child: Row(
          children: [
            // Tap area to restore call
            Expanded(
              child: InkWell(
                onTap: () => call.restore(),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    // Avatar with pulsing green ring if unmuted
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!call.isMuted)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Container(
                                width: 38 + (_pulseController.value * 4),
                                height: 38 + (_pulseController.value * 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.6 - (_pulseController.value * 0.3)),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        ModernAvatar(
                          name: call.title,
                          radius: 17,
                          isVerified: true,
                        ),
                      ],
                    ),

                    const SizedBox(width: 8),

                    // Info: Title & Timer
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  call.title,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                call.formattedDuration,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                call.isGroup ? 'Grup' : 'P2P',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Quick Mute Button
            GestureDetector(
              onTap: () => call.toggleMute(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: call.isMuted
                      ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08))
                      : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  size: 15,
                  color: call.isMuted ? textSecondary : AppColors.primary,
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Quick End Call Button
            GestureDetector(
              onTap: () => call.endCall(),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildNotificationBanner(BuildContext context, InAppNotificationItem item, bool isDark) {
    if (item.isCall) {
      return _buildIncomingCallBanner(context, item, isDark);
    }

    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.up,
      onDismissed: (_) => AppNotificationService.instance.dismiss(),
      child: LajuGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        borderRadius: 18,
        blurSigma: 20,
        tintColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderColor: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceBorder,
        customShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: item.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: textSecondary, size: 18),
              onPressed: () => AppNotificationService.instance.dismiss(),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallBanner(BuildContext context, InAppNotificationItem item, bool isDark) {
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;

    return LajuGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderRadius: 24,
      blurSigma: 24,
      tintColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      borderWidth: 1.5,
      customShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 28,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      item.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Berdering...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Caller info row
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Container(
                        width: 50 + (_pulseController.value * 8),
                        height: 50 + (_pulseController.value * 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5 - (_pulseController.value * 0.3)),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  ModernAvatar(
                    name: item.senderName ?? item.message.split(' • ').first,
                    radius: 23,
                    isVerified: true,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.senderName ?? item.message.split(' • ').first,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message.contains(' • ') ? item.message.split(' • ').last : item.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Action Buttons: Tolak (Red) & Terima (Green)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decline Button
              GestureDetector(
                onTap: item.onDecline,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tolak',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Accept Button
              GestureDetector(
                onTap: item.onAccept,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Terima',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopupNotificationOverlay(BuildContext context, InAppNotificationItem item, bool isDark) {
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final replyController = TextEditingController();

    return Container(
      color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: LajuGlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          tintColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderColor: isDark ? Colors.white.withValues(alpha: 0.18) : AppColors.primary.withValues(alpha: 0.25),
          customShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Avatar, Name, and Close
              Row(
                children: [
                  ModernAvatar(
                    name: item.senderName ?? item.title,
                    radius: 20,
                    imagePath: item.avatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.senderName ?? item.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Notifikasi Popup',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                    onPressed: () => AppNotificationService.instance.dismissPopup(),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Message Body Bubble
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  item.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Reply Input
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: replyController,
                        style: TextStyle(fontSize: 13.5, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Ketik balasan cepat...',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: () {
                        final text = replyController.text.trim();
                        if (text.isNotEmpty) {
                          HapticFeedback.selectionClick();
                          item.onQuickReply?.call(text);
                          AppNotificationService.instance.dismissPopup();
                          LajuToast.success(context, 'Balasan terkirim: "$text"');
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Bottom Actions: Buka Chat / Tutup
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => AppNotificationService.instance.dismissPopup(),
                    child: Text(
                      'Tutup',
                      style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('Buka Obrolan', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      AppNotificationService.instance.dismissPopup();
                      item.onTap?.call();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
