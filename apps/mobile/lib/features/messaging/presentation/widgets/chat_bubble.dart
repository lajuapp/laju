import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../domain/models/message_model.dart';
import '../../domain/services/sticker_service.dart';
import '../../../settings/domain/privacy_controller.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../conversations/presentation/screens/user_profile_screen.dart';
import '../screens/chat_screen.dart';
import 'voice_note_player.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final ValueChanged<String>? onReactionSelected;
  final ValueChanged<MessageModel>? onReply;
  final ValueChanged<MessageModel>? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRecall;
  final bool isGroup;
  final double topMargin;
  final double bottomMargin;

  const ChatBubble({
    super.key,
    required this.message,
    this.onReactionSelected,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onRecall,
    this.isGroup = false,
    this.topMargin = 1.0,
    this.bottomMargin = 1.0,
  });

  static const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _confirmRecallMessage(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Text(
              'Tarik Pesan?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          'Pesan ini akan ditarik dan dihapus untuk semua orang di dalam percakapan. Aksi ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              onRecall?.call();
            },
            child: const Text('Tarik untuk Semua Orang'),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final messageAge = DateTime.now().difference(message.timestamp);
    final canRecall = message.isOutgoing && messageAge.inMinutes <= 30 && !message.isRecalled;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isRecalled) ...[
                  // Quick Emoji Reaction Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: kQuickReactions.map((emoji) {
                        final isSelected = message.reactions.contains(emoji);
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onReactionSelected?.call(emoji);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              emoji,
                              style: TextStyle(
                                fontSize: isSelected ? 30 : 26,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Context Action Menu Card
                Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!message.isRecalled) ...[
                        ListTile(
                          leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
                          title: Text(
                            'Balas',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onReply?.call(message);
                          },
                        ),
                        if (message.content.isNotEmpty && !message.content.startsWith('{')) ...[
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                          ListTile(
                            leading: const Icon(Icons.copy_rounded, color: AppColors.cyan),
                            title: Text(
                              'Salin Teks',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF111827),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Clipboard.setData(ClipboardData(text: message.content));
                              LajuToast.info(context, 'Teks pesan disalin ke clipboard');
                            },
                          ),
                        ],
                        if (message.isOutgoing) ...[
                          if (message.contentType == MessageContentType.text) ...[
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            ListTile(
                              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
                              title: Text(
                                'Edit Pesan',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onEdit?.call(message);
                              },
                            ),
                          ],
                          if (canRecall) ...[
                            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                            ListTile(
                              leading: const Icon(Icons.undo_rounded, color: Color(0xFFF59E0B)),
                              title: const Text(
                                'Tarik Pesan',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Tarik untuk semua orang (sisa ${30 - messageAge.inMinutes} mnt)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _confirmRecallMessage(context);
                              },
                            ),
                          ],
                        ],
                      ],
                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        title: Text(
                          message.isOutgoing ? 'Hapus untuk Saya' : 'Hapus Pesan',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: (message.isOutgoing && !canRecall && !message.isRecalled)
                            ? Text(
                                'Tidak dapat ditarik (> 30 menit)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onDelete?.call();
                          LajuToast.info(context, 'Pesan dihapus untuk Anda');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(MessageDeliveryStatus status, {bool isOut = false, bool forcedWhite = false, bool isDark = true}) {
    final defaultColor = forcedWhite
        ? Colors.white
        : (isOut ? (isDark ? Colors.white70 : const Color(0xFF667781)) : AppColors.textSecondary);
    switch (status) {
      case MessageDeliveryStatus.sending:
        return Icon(Icons.access_time_rounded, size: 12, color: forcedWhite ? Colors.white70 : (isOut ? (isDark ? Colors.white60 : const Color(0xFF8696A0)) : AppColors.textTertiary));
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check_rounded, size: 13, color: defaultColor);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 13, color: defaultColor);
      case MessageDeliveryStatus.read:
        if (!PrivacyController.instance.readReceipts) {
          return Icon(Icons.done_all_rounded, size: 13, color: defaultColor);
        }
        return const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF53BDEB));
      case MessageDeliveryStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.contentType == MessageContentType.systemNotice) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              message.content.toLowerCase().contains('wallpaper')
                  ? Icons.wallpaper_rounded
                  : Icons.lock_rounded,
              size: 12,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message.content,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final isOut = message.isOutgoing;
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final timeStr = DateFormat('HH:mm').format(message.timestamp.toLocal());

    if (message.isRecalled) {
      return _buildRecalledBubble(context, isDark, isOut, timeStr);
    }

    if (_isStickerMessage()) {
      return _buildStickerBubble(context, isDark, isOut, timeStr);
    }

    final isImage = _isImageMessage();

    final bubbleWidget = Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            bottom: bottomMargin,
          ),
          padding: EdgeInsets.only(
            left: isOut ? 48 : 6,
            right: isOut ? 6 : 48,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: isImage
                    ? (_hasImageCaption()
                        ? const EdgeInsets.fromLTRB(4, 4, 4, 5)
                        : const EdgeInsets.all(3))
                    : (message.contentType == MessageContentType.location ||
                            message.contentType == MessageContentType.contact
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.fromLTRB(8, 4, 8, 4)),
                decoration: BoxDecoration(
                  color: isOut
                      ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
                      : (isDark ? const Color(0xFF202C33) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(10),
                    topRight: const Radius.circular(10),
                    bottomLeft: Radius.circular(isOut ? 10 : 2),
                    bottomRight: Radius.circular(isOut ? 2 : 10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                      blurRadius: 1.5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender Name (Only shown in group chats for incoming messages)
                    if (isGroup && !isOut && message.senderName.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.only(
                          left: isImage ? 8 : 0,
                          top: isImage ? 4 : 0,
                          bottom: 2,
                        ),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],

                    // Quoted Message Box (Reply)
                    if (message.replyTo != null) ...[
                      _buildQuotedReplyBox(context, isDark, isOut, isImage),
                    ],

                    // Image Message Content
                    if (isImage)
                      _buildImageContent(context, isDark, isOut, timeStr),

                    // Location Message Content (OpenStreetMap card)
                    if (message.contentType == MessageContentType.location)
                      _buildLocationContent(context, isDark, isOut, timeStr),

                    // Contact Card Message Content (LAJU contact card)
                    if (message.contentType == MessageContentType.contact)
                      _buildContactCardContent(context, isDark, isOut, timeStr),

                    if (!isImage &&
                        message.contentType != MessageContentType.location &&
                        message.contentType != MessageContentType.contact) ...[
                      // Attachment Preview
                      if (message.contentType == MessageContentType.attachment)
                        _buildAttachmentPreview(context, isDark, isOut),

                      // Voice Note Player
                      if (message.contentType == MessageContentType.voiceNote && message.attachmentPath != null)
                        VoiceNotePlayer(
                          filePath: message.attachmentPath!,
                          durationLabel: message.attachmentSize ?? '0:00',
                          isOutgoing: isOut,
                          isDark: isDark,
                        ),

                      // Text message with inline timestamp (WhatsApp style)
                      if (message.contentType == MessageContentType.text)
                        _buildTextMessageContent(context, isDark, isOut, timeStr)
                      else ...[
                        // Non-text attachment / voice note content & timestamp below
                        if (_shouldShowMessageContent()) ...[
                          const SizedBox(height: 3),
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 14 * ChatAppearanceController.instance.fontScale,
                              color: isOut
                                  ? (isDark ? Colors.white : const Color(0xFF111827))
                                  : (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111827)),
                              height: 1.32,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isDisappearing) ...[
                                Icon(Icons.timer_outlined, size: 10.5, color: isOut ? Colors.white70 : AppColors.cyan),
                                const SizedBox(width: 2.5),
                              ],
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isOut
                                      ? (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF667781))
                                      : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (isOut) ...[
                                const SizedBox(width: 3.5),
                                _buildStatusIcon(message.status, isOut: true, isDark: isDark),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Reaction Badge Pill Overlay
              if (message.reactions.isNotEmpty)
                Positioned(
                  bottom: -11,
                  right: isOut ? 8 : null,
                  left: isOut ? null : 8,
                  child: GestureDetector(
                    onTap: () => _showMessageOptions(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.reactions.join(' '),
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (message.reactions.length > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${message.reactions.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return _SwipeToReplyWrapper(
      isDark: isDark,
      onReply: onReply != null ? () => onReply!(message) : null,
      child: bubbleWidget,
    );
  }

  Widget _buildRecalledBubble(BuildContext context, bool isDark, bool isOut, String timeStr) {
    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            bottom: bottomMargin,
          ),
          padding: EdgeInsets.only(
            left: isOut ? 48 : 6,
            right: isOut ? 6 : 48,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? (isOut ? const Color(0xFF1B2B28) : const Color(0xFF1E293B))
                  : (isOut ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(10),
                topRight: const Radius.circular(10),
                bottomLeft: Radius.circular(isOut ? 10 : 2),
                bottomRight: Radius.circular(isOut ? 2 : 10),
              ),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  isOut ? 'Anda menarik pesan ini' : 'Pesan ini telah ditarik',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isStickerMessage() {
    if (message.contentType == MessageContentType.sticker) return true;
    final path = message.attachmentPath ?? '';
    final name = message.attachmentName ?? '';
    final content = message.content;
    return path.contains('stickers/') ||
        name.startsWith('cat_') ||
        name.contains('sticker') ||
        content.startsWith('sticker:');
  }

  Widget _buildStickerBubble(BuildContext context, bool isDark, bool isOut, String timeStr) {
    final stickerGraphic = _buildStickerGraphic(context, isDark);

    final bubbleWidget = Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            bottom: bottomMargin,
          ),
          padding: EdgeInsets.only(
            left: isOut ? 48 : 12,
            right: isOut ? 12 : 48,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quoted Reply Box if replying
                  if (message.replyTo != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: _buildQuotedReplyBox(context, isDark, isOut, false),
                    ),
                  ],

                  // Sticker Graphic + Floating Timestamp Pill
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: stickerGraphic,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isOut) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(message.status, isOut: true, forcedWhite: true),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Reaction Badge Pill Overlay
              if (message.reactions.isNotEmpty)
                Positioned(
                  bottom: -10,
                  right: isOut ? 8 : null,
                  left: isOut ? null : 8,
                  child: GestureDetector(
                    onTap: () => _showMessageOptions(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.reactions.join(' '),
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (message.reactions.length > 1) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${message.reactions.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return _SwipeToReplyWrapper(
      isDark: isDark,
      onReply: onReply != null ? () => onReply!(message) : null,
      child: bubbleWidget,
    );
  }

  Widget _buildStickerGraphic(BuildContext context, bool isDark) {
    String? pathOrUrl;
    final path = message.attachmentPath ?? '';
    final name = message.attachmentName ?? '';
    final content = message.content;

    if (path.isNotEmpty) {
      pathOrUrl = path;
    } else {
      // Try finding in StickerService (remote or local)
      final foundSticker = StickerService.instance.findSticker(name);
      if (foundSticker != null) {
        pathOrUrl = foundSticker.isRemote ? foundSticker.effectivePathOrUrl : foundSticker.assetPath;
      }
    }

    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      if (name == 'cat_cool' || content.contains('cat_cool') || content.toLowerCase() == 'keren') {
        pathOrUrl = 'assets/images/stickers/cat_cool.png';
      } else if (name == 'cat_cheer' || content.contains('cat_cheer') || content.toLowerCase() == 'semangat') {
        pathOrUrl = 'assets/images/stickers/cat_cheer.png';
      } else {
        pathOrUrl = 'assets/images/stickers/cat_thumbs_up.png';
      }
    }

    return LajuAnimatedSticker(
      pathOrUrl: pathOrUrl,
      width: 145,
      height: 145,
      fit: BoxFit.contain,
      fallback: _buildFallbackStickerIcon(isDark),
    );
  }


  Widget _buildFallbackStickerIcon(bool isDark) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Icon(
          Icons.sticky_note_2_outlined,
          size: 40,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }

  bool _isImageMessage() {
    if (message.contentType != MessageContentType.attachment) return false;
    final path = message.attachmentPath ?? '';
    final name = (message.attachmentName ?? '').toUpperCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    final isImgExt = ext == 'JPG' ||
        ext == 'JPEG' ||
        ext == 'PNG' ||
        ext == 'WEBP' ||
        ext == 'GIF' ||
        ext == 'HEIC' ||
        ext == 'BMP';
    if (isImgExt) return true;
    if (path.startsWith('data:image')) return true;
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp')) return true;
    if (path.startsWith('data:')) {
      final b64 = path.contains(',') ? path.split(',').last : path;
      if (b64.startsWith('/9j/') ||
          b64.startsWith('iVBORw0KGgo') ||
          b64.startsWith('R0lGOD') ||
          b64.startsWith('UklGR')) {
        return true;
      }
    }
    return false;
  }

  bool _hasImageCaption() {
    if (!_isImageMessage()) return false;
    final clean = message.content.trim();
    if (clean.isEmpty ||
        clean == 'Foto' ||
        clean == 'Foto.jpg' ||
        clean == (message.attachmentName ?? '').trim()) {
      return false;
    }
    return true;
  }

  Widget _buildImageContent(BuildContext context, bool isDark, bool isOut, String timeStr) {
    Widget imageWidget;
    final path = message.attachmentPath ?? '';

    if (path.startsWith('data:')) {
      try {
        final b64 = path.contains(',') ? path.split(',').last : path;
        final bytes = base64Decode(b64);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, stackTrace) => _buildImagePlaceholder(isDark),
        );
      } catch (_) {
        imageWidget = _buildImagePlaceholder(isDark);
      }
    } else if (File(path).existsSync()) {
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, stackTrace) => _buildImagePlaceholder(isDark),
      );
    } else {
      imageWidget = _buildImagePlaceholder(isDark);
    }

    final hasCaption = _hasImageCaption();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Canvas
        GestureDetector(
          onTap: () {
            if (path.isNotEmpty) {
              LajuImageViewer.show(
                context,
                imagePath: path,
                title: isOut
                    ? 'Anda'
                    : (message.senderName.isNotEmpty ? message.senderName : 'Foto'),
                subtitle: DateFormat('dd MMMM yyyy, HH:mm').format(message.timestamp.toLocal()),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 280,
                maxWidth: 280,
                minWidth: 200,
                minHeight: 140,
              ),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  imageWidget,

                  // Subtle gradient shadow at bottom for timestamp readability if no caption
                  if (!hasCaption)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.60),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Floating Timestamp Pill Overlay (if no caption)
                  if (!hasCaption)
                    Positioned(
                      bottom: 6,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.isDisappearing) ...[
                              const Icon(Icons.timer_outlined, size: 11, color: Colors.white70),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isOut) ...[
                              const SizedBox(width: 4),
                              _buildStatusIcon(message.status, isOut: true, forcedWhite: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Caption & Timestamp (if caption exists)
        if (hasCaption) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 14.5 * ChatAppearanceController.instance.fontScale,
                color: isOut ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isDisappearing) ...[
                    Icon(Icons.timer_outlined, size: 11, color: isOut ? Colors.white70 : AppColors.cyan),
                    const SizedBox(width: 3),
                  ],
                  if (message.isEdited) ...[
                    Text(
                      'diedit ',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isOut
                            ? Colors.white.withValues(alpha: 0.75)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isOut
                          ? Colors.white.withValues(alpha: 0.8)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (isOut) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(message.status, isOut: true),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      height: 180,
      width: 240,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildQuotedReplyBox(BuildContext context, bool isDark, bool isOut, bool isImage) {
    final reply = message.replyTo!;
    final accentColor = isOut
        ? (isDark ? const Color(0xFF00A884) : const Color(0xFF008069))
        : (isDark ? const Color(0xFF53BDEB) : const Color(0xFF027EB5));

    final replyBg = isDark
        ? (isOut ? Colors.black.withValues(alpha: 0.32) : Colors.black.withValues(alpha: 0.22))
        : (isOut ? const Color(0xFFE4F8DD) : const Color(0xFFF0F2F5));

    final senderNameColor = isOut
        ? (isDark ? const Color(0xFF25D366) : const Color(0xFF008069))
        : (isDark ? const Color(0xFF53BDEB) : const Color(0xFF027EB5));

    final snippetColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF111B21).withValues(alpha: 0.78);

    final snippetText = reply.displaySnippet;

    IconData? snippetIcon;
    if (reply.contentType == MessageContentType.sticker) {
      snippetIcon = Icons.emoji_emotions_rounded;
    } else if (reply.contentType == MessageContentType.voiceNote) {
      snippetIcon = Icons.mic_rounded;
    } else if (reply.contentType == MessageContentType.location) {
      snippetIcon = Icons.location_on_rounded;
    } else if (reply.contentType == MessageContentType.contact) {
      snippetIcon = Icons.person_rounded;
    } else if (reply.contentType == MessageContentType.attachment) {
      final name = (reply.attachmentName ?? '').toLowerCase();
      snippetIcon = (name.endsWith('.pdf') ||
              name.endsWith('.doc') ||
              name.endsWith('.docx') ||
              name.endsWith('.xls') ||
              name.endsWith('.xlsx') ||
              name.endsWith('.csv') ||
              name.endsWith('.ppt') ||
              name.endsWith('.pptx') ||
              name.endsWith('.zip') ||
              name.endsWith('.rar') ||
              name.endsWith('.txt'))
          ? Icons.insert_drive_file_rounded
          : Icons.photo_camera_rounded;
    }

    final isReplySticker = reply.contentType == MessageContentType.sticker ||
        reply.content.startsWith('sticker:') ||
        (reply.attachmentName != null &&
            (reply.attachmentName!.startsWith('cat_') ||
                reply.attachmentName!.contains('sticker')));

    String? quotedThumbPath = reply.attachmentPath;
    if ((quotedThumbPath == null || quotedThumbPath.isEmpty) && isReplySticker) {
      quotedThumbPath = reply.attachmentName ?? reply.content;
      if (quotedThumbPath != null && quotedThumbPath.startsWith('sticker:')) {
        quotedThumbPath = quotedThumbPath.substring(8);
      }
    }

    return Container(
      margin: EdgeInsets.only(
        left: isImage ? 4 : 0,
        right: isImage ? 4 : 0,
        top: isImage ? 4 : 0,
        bottom: 3,
      ),
      decoration: BoxDecoration(
        color: replyBg,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vertical WhatsApp Accent Bar
            Container(
              width: 3.5,
              color: accentColor,
            ),
            // Text content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply_rounded, size: 11, color: senderNameColor),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            reply.senderName.isNotEmpty ? reply.senderName : 'Pesan',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: senderNameColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (snippetIcon != null) ...[
                          Icon(snippetIcon, size: 12, color: snippetColor),
                          const SizedBox(width: 3),
                        ],
                        Flexible(
                          child: Text(
                            snippetText.isNotEmpty ? snippetText : '...',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: snippetColor,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (quotedThumbPath != null && quotedThumbPath.isNotEmpty) ...[
              const SizedBox(width: 4),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: _buildQuotedMediaThumbnail(
                    quotedThumbPath,
                    isSticker: isReplySticker,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuotedMediaThumbnail(String path, {bool isSticker = false}) {
    final fit = isSticker ? BoxFit.contain : BoxFit.cover;
    final fallbackIcon = isSticker
        ? const Icon(Icons.emoji_emotions_rounded, size: 20, color: Colors.white54)
        : const Icon(Icons.image, size: 20, color: Colors.white54);

    if (path.startsWith('data:image')) {
      try {
        final b64 = path.contains(',') ? path.split(',').last : path;
        return Image.memory(
          base64Decode(b64),
          fit: fit,
          errorBuilder: (_, __, ___) => fallbackIcon,
        );
      } catch (_) {}
    }
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('/') ||
        path.startsWith('admin/media')) {
      return LajuCachedImage(
        imageUrlOrPath: path,
        fit: fit,
        cacheWidth: 512,
        cacheHeight: 512,
        errorWidget: fallbackIcon,
      );
    }
    if (File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackIcon,
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackIcon,
      );
    }

    if (isSticker) {
      final found = StickerService.instance.findSticker(path);
      if (found != null) {
        if (found.isRemote) {
          return LajuAnimatedSticker(
            pathOrUrl: found.effectivePathOrUrl,
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            fallback: fallbackIcon,
          );
        } else {
          return Image.asset(
            found.effectivePathOrUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallbackIcon,
          );
        }
      }
    }

    return Container(
      color: Colors.black26,
      child: fallbackIcon,
    );
  }

  Widget _buildTextMessageContent(BuildContext context, bool isDark, bool isOut, String timeStr) {
    final textColor = isOut
        ? (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21))
        : (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21));

    final timeColor = isOut
        ? (isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF667781))
        : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781));

    final fontScale = ChatAppearanceController.instance.fontScale;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: message.content,
            style: TextStyle(
              fontSize: 14.5 * fontScale,
              color: textColor,
              height: 1.32,
            ),
          ),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: 8),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (message.isDisappearing) ...[
                    Icon(Icons.timer_outlined, size: 10.5, color: timeColor),
                    const SizedBox(width: 2.5),
                  ],
                  if (message.isEdited) ...[
                    Text(
                      'diedit ',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontStyle: FontStyle.italic,
                        color: timeColor,
                      ),
                    ),
                  ],
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: timeColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (isOut) ...[
                    const SizedBox(width: 3.5),
                    _buildStatusIcon(message.status, isOut: true, isDark: isDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationContent(BuildContext context, bool isDark, bool isOut, String timeStr) {
    LocationData loc;
    try {
      loc = LocationData.fromJson(message.content);
    } catch (_) {
      loc = LocationData(
        latitude: -6.2088,
        longitude: 106.8456,
        name: message.attachmentName ?? 'Lokasi Terkini',
        address: message.attachmentSize ?? '',
      );
    }

    final tileUrl = loc.getOsmTileUrl(zoom: 16);
    final isLive = loc.isLive;
    final timeColor = isOut
        ? (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF667781))
        : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => LocationService.instance.openMap(loc.latitude, loc.longitude, label: loc.name),
        child: SizedBox(
          width: 245,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // OpenStreetMap Mini Map Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LajuCachedImage(
                        imageUrlOrPath: tileUrl,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'User-Agent': 'LajuMobileApp/1.0 (Privacy-First Secure Messenger)',
                        },
                        errorWidget: Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          child: const Center(
                            child: Icon(Icons.map_rounded, color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                      // Center Pin
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isLive ? const Color(0xFF10B981) : AppColors.danger,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          child: Icon(
                            isLive ? Icons.share_location_rounded : Icons.location_on_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      // Attribution tag
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isLive ? const Color(0xFF10B981) : Colors.black87).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLive ? 'LIVE' : '© OpenStreetMap',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // Location Info & Timestamp
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.name.isNotEmpty ? loc.name : 'Lokasi Terkini',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isOut
                            ? (isDark ? Colors.white : const Color(0xFF111827))
                            : (isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (loc.address.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        loc.address,
                        style: TextStyle(
                          fontSize: 11,
                          color: isOut
                              ? (isDark ? Colors.white70 : const Color(0xFF475569))
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: timeColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (isOut) ...[
                            const SizedBox(width: 3.5),
                            _buildStatusIcon(message.status, isOut: true, isDark: isDark),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCardContent(BuildContext context, bool isDark, bool isOut, String timeStr) {
    LajuContactData contact;
    try {
      final parsed = jsonDecode(message.content);
      if (parsed is Map<String, dynamic>) {
        contact = LajuContactData.fromJson(parsed);
      } else if (parsed is Map) {
        contact = LajuContactData.fromJson(Map<String, dynamic>.from(parsed));
      } else {
        throw Exception();
      }
    } catch (_) {
      contact = LajuContactData(
        userId: '',
        name: message.attachmentName ?? 'Kontak LAJU',
        username: message.attachmentSize ?? '',
        status: 'Pengguna Terverifikasi LAJU',
      );
    }

    final timeColor = isOut
        ? (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF667781))
        : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781));

    return SizedBox(
      width: 245,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Contact Info Card Header
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openContactProfile(context, contact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  ModernAvatar(
                    name: contact.name,
                    imagePath: contact.avatarUrl,
                    radius: 22,
                    isOnline: true,
                    isVerified: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isOut
                                ? (isDark ? Colors.white : const Color(0xFF111827))
                                : (isDark ? Colors.white : const Color(0xFF111827)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${contact.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOut
                                ? (isDark ? Colors.white70 : const Color(0xFF4B5563))
                                : (isDark ? Colors.white60 : const Color(0xFF6B7280)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),

          // Action Buttons: Kirim Pesan & Lihat Profil
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                  onTap: () => _openContactChat(context, contact),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Kirim Pesan',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                tooltip: 'Lihat Profil',
                color: isOut
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : (isDark ? Colors.white70 : Colors.black54),
                onPressed: () => _openContactProfile(context, contact),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Timestamp & Status (Bottom right)
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 4, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: timeColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (isOut) ...[
                    const SizedBox(width: 3.5),
                    _buildStatusIcon(message.status, isOut: true, isDark: isDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openContactChat(BuildContext context, LajuContactData contact) async {
    if (contact.userId.isEmpty) return;
    String convId = 'conv-${contact.userId}';
    try {
      final backendId = await ConversationService.instance.createPersonalConversation(contact.userId);
      if (backendId != null && backendId.isNotEmpty) {
        convId = backendId;
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            title: contact.name,
            avatarUrl: contact.avatarUrl,
            contactUserId: contact.userId,
            contactPhone: contact.phoneNumber ?? '@${contact.username}',
            contactAbout: contact.status,
          ),
        ),
      );
    }
  }

  void _openContactProfile(BuildContext context, LajuContactData contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          contactName: contact.name,
          userId: contact.userId.isNotEmpty ? contact.userId : null,
          phone: contact.phoneNumber ?? '@${contact.username}',
          status: contact.status,
          avatarUrl: contact.avatarUrl,
        ),
      ),
    );
  }

  bool _shouldShowMessageContent() {
    if (message.contentType == MessageContentType.location ||
        message.contentType == MessageContentType.contact) {
      return false;
    }
    if (message.contentType == MessageContentType.voiceNote && message.attachmentPath != null) {
      return false;
    }
    if (_isImageMessage()) {
      return _hasImageCaption();
    }
    if (message.contentType != MessageContentType.attachment) {
      return message.content.isNotEmpty;
    }

    final cleanContent = message.content.trim();
    final attName = (message.attachmentName ?? '').trim();

    if (cleanContent.isEmpty ||
        cleanContent == attName ||
        cleanContent == 'Dokumen' ||
        cleanContent == '$attName\nDokumen' ||
        cleanContent == 'Voice Message' ||
        cleanContent.startsWith('Berkas Dokumen Asli') ||
        cleanContent == 'Berkas Dokumen' ||
        cleanContent.startsWith('data:') ||
        (cleanContent.startsWith('{') && cleanContent.contains('"media"')) ||
        (cleanContent.startsWith('{') && cleanContent.contains('"type"')) ||
        cleanContent == '$attName (${message.attachmentSize})' ||
        cleanContent == '${message.attachmentName} (${message.attachmentSize})') {
      return false;
    }

    return true;
  }

  Widget _buildAttachmentPreview(BuildContext context, bool isDark, bool isOut) {
    final fileName = message.attachmentName ?? 'Document.pdf';
    final parts = fileName.split('.');
    final ext = parts.length > 1 ? parts.last.toUpperCase() : 'FILE';

    Color iconBgColor;
    Color iconColor;
    IconData fileIcon;

    switch (ext) {
      case 'PDF':
        iconBgColor = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFEF4444);
        fileIcon = Icons.picture_as_pdf_rounded;
        break;
      case 'DOC':
      case 'DOCX':
        iconBgColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE);
        iconColor = const Color(0xFF3B82F6);
        fileIcon = Icons.description_rounded;
        break;
      case 'XLS':
      case 'XLSX':
      case 'CSV':
        iconBgColor = isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
        iconColor = const Color(0xFF16A34A);
        fileIcon = Icons.table_chart_rounded;
        break;
      case 'ZIP':
      case 'RAR':
      case '7Z':
        iconBgColor = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFF59E0B);
        fileIcon = Icons.folder_zip_rounded;
        break;
      case 'MP3':
      case 'WAV':
      case 'M4A':
        iconBgColor = isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF);
        iconColor = const Color(0xFFA855F7);
        fileIcon = Icons.audiotrack_rounded;
        break;
      default:
        iconBgColor = isDark ? const Color(0xFF134E4A).withValues(alpha: 0.4) : AppColors.primaryLight;
        iconColor = AppColors.primaryDark;
        fileIcon = Icons.insert_drive_file_rounded;
        break;
    }

    final cardBg = isDark
        ? (isOut ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFF0F172A).withValues(alpha: 0.6))
        : (isOut ? Colors.white.withValues(alpha: 0.8) : const Color(0xFFF8FAFC));

    final cardBorder = isDark
        ? (isOut ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1))
        : (isOut ? AppColors.primary.withValues(alpha: 0.35) : const Color(0xFFE2E8F0));

    final isImage = ext == 'JPG' ||
        ext == 'JPEG' ||
        ext == 'PNG' ||
        ext == 'WEBP' ||
        ext == 'GIF' ||
        ext == 'HEIC' ||
        ext == 'BMP' ||
        (message.attachmentPath != null &&
            (message.attachmentPath!.startsWith('data:image') ||
             message.attachmentPath!.startsWith('data:')));

    if (isImage && message.attachmentPath != null) {
      Widget? imageWidget;
      if (message.attachmentPath!.startsWith('data:')) {
        try {
          final b64 = message.attachmentPath!.contains(',')
              ? message.attachmentPath!.split(',').last
              : message.attachmentPath!;
          final bytes = base64Decode(b64);
          imageWidget = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Center(child: Icon(Icons.broken_image_rounded, color: iconColor, size: 36)),
          );
        } catch (_) {}
      } else if (File(message.attachmentPath!).existsSync()) {
        imageWidget = Image.file(
          File(message.attachmentPath!),
          fit: BoxFit.cover,
        );
      }

      if (imageWidget != null) {
        return GestureDetector(
          onTap: () {
            LajuImageViewer.show(
              context,
              imagePath: message.attachmentPath!,
              title: message.isOutgoing
                  ? 'Anda'
                  : (message.senderName.isNotEmpty ? message.senderName : 'Foto'),
              subtitle: DateFormat('dd MMMM yyyy, HH:mm').format(message.timestamp.toLocal()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageWidget,
          ),
        );
      }
    }

    return InkWell(
      onTap: () {
        if (isImage && message.attachmentPath != null) {
          LajuImageViewer.show(
            context,
            imagePath: message.attachmentPath!,
            title: message.isOutgoing
                ? 'Anda'
                : (message.senderName.isNotEmpty ? message.senderName : 'Foto'),
            subtitle: DateFormat('dd MMMM yyyy, HH:mm').format(message.timestamp.toLocal()),
          );
        } else {
          LajuToast.info(context, 'Membuka $fileName');
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Styled file icon badge (or image thumbnail if photo)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: isImage && message.attachmentPath != null && message.attachmentPath!.startsWith('data:')
                  ? Image.memory(
                      base64Decode(message.attachmentPath!.contains(',')
                          ? message.attachmentPath!.split(',').last
                          : message.attachmentPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(fileIcon, color: iconColor, size: 24),
                      ),
                    )
                  : (isImage && message.attachmentPath != null && File(message.attachmentPath!).existsSync()
                      ? Image.file(
                          File(message.attachmentPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(fileIcon, color: iconColor, size: 24),
                          ),
                        )
                      : Center(
                          child: Icon(fileIcon, color: iconColor, size: 24),
                        )),
            ),
            const SizedBox(width: 11),

            // File title and metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        (message.attachmentSize != null && message.attachmentSize!.isNotEmpty)
                            ? '${message.attachmentSize} • $ext'
                            : ext,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action button (Download / Open circular badge)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : (isOut ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: isDark ? AppColors.cyan : (isOut ? AppColors.primaryDark : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  final bool isDark;

  const _SwipeToReplyWrapper({
    required this.child,
    this.onReply,
    required this.isDark,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  static const double _triggerThreshold = 55.0;
  static const double _maxDragOffset = 75.0;
  bool _hasHapticTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;
    final delta = details.primaryDelta ?? 0.0;
    // Allow dragging towards right to trigger reply
    final newOffset = (_dragOffset + delta).clamp(0.0, _maxDragOffset);
    if (newOffset != _dragOffset) {
      if (newOffset >= _triggerThreshold && !_hasHapticTriggered) {
        HapticFeedback.lightImpact();
        _hasHapticTriggered = true;
      } else if (newOffset < _triggerThreshold) {
        _hasHapticTriggered = false;
      }
      setState(() {
        _dragOffset = newOffset;
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.onReply == null) return;
    if (_dragOffset >= _triggerThreshold) {
      widget.onReply?.call();
    }
    _hasHapticTriggered = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) {
      return widget.child;
    }

    final progress = (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dragOffset > 0)
            Positioned(
              left: 12 + (_dragOffset * 0.15),
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + (0.4 * progress),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: progress >= 1.0
                          ? AppColors.primary
                          : (widget.isDark ? Colors.white70 : const Color(0xFF64748B)),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
