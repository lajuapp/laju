import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../domain/models/message_model.dart';
import 'voice_note_player.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final ValueChanged<String>? onReactionSelected;
  final ValueChanged<MessageModel>? onReply;
  final ValueChanged<MessageModel>? onEdit;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    this.onReactionSelected,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  static const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _showMessageOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isDark = ThemeModeController.instance.isDarkMode(context);

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
                        Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                        ListTile(
                          leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          title: const Text(
                            'Hapus Pesan',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onDelete?.call();
                            LajuToast.info(context, 'Pesan dihapus');
                          },
                        ),
                      ],
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

  Widget _buildStatusIcon(MessageDeliveryStatus status, {bool isOut = false}) {
    final defaultColor = isOut ? Colors.white70 : AppColors.textSecondary;
    switch (status) {
      case MessageDeliveryStatus.sending:
        return Icon(Icons.access_time_rounded, size: 12, color: isOut ? Colors.white60 : AppColors.textTertiary);
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check_rounded, size: 13, color: defaultColor);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 13, color: defaultColor);
      case MessageDeliveryStatus.read:
        return const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF67E8F9));
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
            const Icon(Icons.lock_rounded, size: 12, color: AppColors.primary),
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

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(
            top: 6,
            bottom: message.reactions.isNotEmpty ? 18 : 6,
            left: isOut ? 48 : 12,
            right: isOut ? 12 : 48,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                decoration: BoxDecoration(
                  gradient: isOut
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF065F46).withValues(alpha: 0.85),
                                  const Color(0xFF047857).withValues(alpha: 0.75),
                                ]
                              : [
                                  const Color(0xFF059669).withValues(alpha: 0.88),
                                  const Color(0xFF10B981).withValues(alpha: 0.78),
                                ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B).withValues(alpha: 0.82),
                                  const Color(0xFF0F172A).withValues(alpha: 0.72),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.92),
                                  Colors.white.withValues(alpha: 0.78),
                                ],
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isOut ? 18 : 4),
                    bottomRight: Radius.circular(isOut ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isOut
                        ? (isDark ? const Color(0xFF34D399).withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.45))
                        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.65)),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isOut
                          ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                          : Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender Name (Incoming in group or user chat)
                    if (!isOut && message.senderName.isNotEmpty) ...[
                      Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Quoted Message Box (Reply)
                    if (message.replyTo != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : (isOut ? Colors.black.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(color: AppColors.primary, width: 3.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.replyTo!.senderName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.replyTo!.content,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Attachment Preview (Refined Card)
                    if (message.contentType == MessageContentType.attachment)
                      _buildAttachmentPreview(context, isDark, isOut),

                    // Voice Note Player
                    if (message.contentType == MessageContentType.voiceNote && message.attachmentPath != null)
                      VoiceNotePlayer(
                        filePath: message.attachmentPath!,
                        durationLabel: message.attachmentSize ?? '0:15',
                        isOutgoing: isOut,
                        isDark: isDark,
                      ),

                    // Message Content (Deduplicated so attachment title is not repeated)
                    if (_shouldShowMessageContent()) ...[
                      if (message.contentType == MessageContentType.attachment)
                        const SizedBox(height: 4),
                      Text(
                        message.content,
                        style: TextStyle(
                          fontSize: 14.5 * ChatAppearanceController.instance.fontScale,
                          color: isOut ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),

                    // Timestamp & Status Icon (Right-aligned WhatsApp style)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
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
  }

  bool _shouldShowMessageContent() {
    if (message.contentType == MessageContentType.voiceNote && message.attachmentPath != null) {
      return false;
    }
    if (message.contentType != MessageContentType.attachment) {
      return message.content.isNotEmpty;
    }

    final cleanContent = message.content.trim();
    final attName = (message.attachmentName ?? '').trim();

    if (cleanContent.isEmpty ||
        cleanContent == attName ||
        cleanContent == 'Client-Side Encrypted Document' ||
        cleanContent == '$attName\nClient-Side Encrypted Document' ||
        cleanContent == '📷 $attName (${message.attachmentSize})' ||
        cleanContent == '🎤 Voice Message' ||
        cleanContent.startsWith('📷 $attName')) {
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

    final isImage = ext == 'JPG' || ext == 'JPEG' || ext == 'PNG' || ext == 'WEBP' || ext == 'GIF' || (message.attachmentPath != null && message.attachmentPath!.startsWith('data:image'));

    if (isImage && message.attachmentPath != null) {
      Widget? imageWidget;
      if (message.attachmentPath!.startsWith('data:image')) {
        try {
          final b64 = message.attachmentPath!.split(',').last;
          final bytes = base64Decode(b64);
          imageWidget = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_rounded, color: iconColor, size: 36)),
          );
        } catch (_) {}
      } else if (File(message.attachmentPath!).existsSync()) {
        imageWidget = Image.file(
          File(message.attachmentPath!),
          fit: BoxFit.cover,
        );
      }

      if (imageWidget != null) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 280),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageWidget,
        );
      }
    }

    return InkWell(
      onTap: () {
        LajuToast.info(context, 'Membuka $fileName');
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
              child: message.attachmentPath != null && message.attachmentPath!.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(message.attachmentPath!.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : (message.attachmentPath != null && File(message.attachmentPath!).existsSync()
                      ? Image.file(
                          File(message.attachmentPath!),
                          fit: BoxFit.cover,
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
                        '${message.attachmentSize ?? '2.4 MB'} • $ext',
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
