import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../domain/models/conversation_model.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
  });

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final isToday = now.year == local.year && now.month == local.month && now.day == local.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == local.year && yesterday.month == local.month && yesterday.day == local.day;

    if (isToday) {
      return DateFormat('HH:mm').format(local);
    } else if (isYesterday) {
      return LocaleController.instance.value.languageCode == 'id' ? 'Kemarin' : 'Yesterday';
    } else {
      return DateFormat('dd/MM').format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: conversation.unreadCount > 0
            ? (isDark ? AppColors.primary.withValues(alpha: 0.07) : AppColors.primary.withValues(alpha: 0.04))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: conversation.unreadCount > 0
            ? Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: AppColors.primaryGlow,
          highlightColor: (isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated).withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              ModernAvatar(
                name: conversation.title,
                imagePath: conversation.avatarUrl,
                radius: 26,
                isOnline: conversation.isOnline,
                isVerified: conversation.isKeyVerified,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  conversation.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (conversation.isGroup) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.group_rounded,
                                  size: 15,
                                  color: secondaryColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (conversation.isMuted) ...[
                              Icon(
                                Icons.volume_off_rounded,
                                size: 13,
                                color: secondaryColor,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (conversation.isPinned) ...[
                              const Icon(
                                Icons.push_pin_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              _formatTime(conversation.lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                                color: conversation.unreadCount > 0 ? AppColors.primary : secondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (conversation.hasDisappearingMessages) ...[
                          const Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: AppColors.cyan,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: conversation.unreadCount > 0 ? titleColor : secondaryColor,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
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
    ),
  );
}
}
