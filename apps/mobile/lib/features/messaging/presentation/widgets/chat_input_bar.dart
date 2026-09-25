import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/services/voice_note_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/laju_toast.dart';
import '../../domain/models/message_model.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text) onSend;
  final VoidCallback onAttach;
  final VoidCallback? onVoiceRecord;
  final Function(VoiceRecordResult result)? onSendVoiceNote;
  final MessageModel? replyingTo;
  final VoidCallback? onCancelReply;
  final MessageModel? editingMessage;
  final VoidCallback? onCancelEdit;
  final Function(String newText)? onConfirmEdit;
  final ValueChanged<bool>? onTypingChanged;
  final VoidCallback? onStickerTap;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.onVoiceRecord,
    this.onSendVoiceNote,
    this.replyingTo,
    this.onCancelReply,
    this.editingMessage,
    this.onCancelEdit,
    this.onConfirmEdit,
    this.onTypingChanged,
    this.onStickerTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  Timer? _typingTimer;

  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.editingMessage != null) {
      _controller.text = widget.editingMessage!.content;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _hasText = _controller.text.trim().isNotEmpty;
    }

    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
      if (hasText) {
        widget.onTypingChanged?.call(true);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 2), () {
          widget.onTypingChanged?.call(false);
        });
      } else {
        _typingTimer?.cancel();
        widget.onTypingChanged?.call(false);
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != oldWidget.editingMessage) {
      if (widget.editingMessage != null) {
        _controller.text = widget.editingMessage!.content;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focusNode.requestFocus();
          }
        });
      } else if (oldWidget.editingMessage != null && widget.editingMessage == null) {
        _controller.clear();
        _focusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
      }
    }

    if (widget.replyingTo != oldWidget.replyingTo && widget.replyingTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _pulseController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      if (widget.editingMessage != null) {
        widget.onConfirmEdit?.call(text);
      } else {
        widget.onSend(text);
      }
      _controller.clear();
      _focusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      FocusScope.of(context).unfocus();
    }
  }

  void _cancelEdit() {
    _controller.clear();
    _focusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    widget.onCancelEdit?.call();
  }

  Future<void> _startRecording() async {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    // Check & request runtime microphone permission
    final hasPerm = await VoiceNoteService.instance.hasPermission();
    if (!hasPerm) {
      final granted = await VoiceNoteService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          LajuToast.info(context, 'Izin mikrofon diperlukan untuk merekam voice note');
        }
        return;
      }
    }

    final path = await VoiceNoteService.instance.startRecording();
    if (path != null && mounted) {
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    } else {
      if (mounted) {
        LajuToast.info(context, 'Gagal memulai perekam mikrofon');
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    await VoiceNoteService.instance.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
      LajuToast.info(context, 'Rekaman suara dibatalkan');
    }
  }

  Future<void> _finishAndSendRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final result = await VoiceNoteService.instance.stopRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }

    if (result != null) {
      if (result.durationMs < 800) {
        if (mounted) {
          LajuToast.info(context, 'Rekaman terlalu singkat');
        }
        return;
      }
      widget.onSendVoiceNote?.call(result);
    } else {
      if (mounted) {
        LajuToast.info(context, 'Gagal merekam suara');
      }
    }
  }

  String get _formattedRecordTime {
    final m = _recordSeconds ~/ 60;
    final s = _recordSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _onMicTap() {
    if (widget.onSendVoiceNote != null) {
      _startRecording();
    } else if (widget.onVoiceRecord != null) {
      widget.onVoiceRecord!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final barBorder = isDark ? AppColors.darkSurfaceBorder : AppColors.surfaceBorder;
    final inputBg = isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated;
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final hintCol = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF0F172A).withValues(alpha: 0.85),
                      const Color(0xFF0F172A).withValues(alpha: 0.95),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.90),
                      Colors.white.withValues(alpha: 0.82),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Editing Message Preview Banner
                if (widget.editingMessage != null && !_isRecording) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Edit Pesan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.editingMessage!.content,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hintCol,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: hintCol),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                          onPressed: _cancelEdit,
                          tooltip: 'Batal Edit',
                        ),
                      ],
                    ),
                  ),
                ],

                // Replying To Preview Banner
                if (widget.replyingTo != null && widget.editingMessage == null && !_isRecording) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.reply_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Membalas ${widget.replyingTo!.senderName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (widget.replyingTo!.contentType == MessageContentType.sticker) ...[
                                    Icon(Icons.emoji_emotions_rounded, size: 13, color: hintCol),
                                    const SizedBox(width: 3),
                                  ] else if (widget.replyingTo!.contentType == MessageContentType.voiceNote) ...[
                                    Icon(Icons.mic_rounded, size: 13, color: hintCol),
                                    const SizedBox(width: 3),
                                  ] else if (widget.replyingTo!.contentType == MessageContentType.location) ...[
                                    Icon(Icons.location_on_rounded, size: 13, color: hintCol),
                                    const SizedBox(width: 3),
                                  ] else if (widget.replyingTo!.contentType == MessageContentType.attachment) ...[
                                    Icon(Icons.photo_camera_rounded, size: 13, color: hintCol),
                                    const SizedBox(width: 3),
                                  ],
                                  Expanded(
                                    child: Text(
                                      widget.replyingTo!.displaySnippet,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: hintCol,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.replyingTo!.attachmentPath != null && widget.replyingTo!.attachmentPath!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: _buildReplyThumbnail(widget.replyingTo!.attachmentPath!),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 18, color: hintCol),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                          onPressed: widget.onCancelReply,
                          tooltip: 'Batal Balas',
                        ),
                      ],
                    ),
                  ),
                ],

                // Active Recording Bar or Normal Input Bar
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Cancel / Discard Recording Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
                          splashRadius: 22,
                          onPressed: _cancelRecording,
                          tooltip: 'Batalkan Rekaman',
                        ),
                        const SizedBox(width: 4),

                        // Live Recording Status
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Pulsing red dot
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _formattedRecordTime,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Merekam suara HP...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Send Voice Note Button
                        GestureDetector(
                          onTap: _finishAndSendRecording,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Normal Text Input Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Attachment Button (Encrypted file/media)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
                          splashRadius: 22,
                          onPressed: widget.onAttach,
                          tooltip: 'Attach Encrypted Content',
                        ),
                        if (widget.onStickerTap != null) ...[
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.primary, size: 26),
                            splashRadius: 22,
                            onPressed: () {
                              _focusNode.unfocus();
                              FocusManager.instance.primaryFocus?.unfocus();
                              FocusScope.of(context).unfocus();
                              widget.onStickerTap!();
                            },
                            tooltip: 'Stiker LAJU',
                          ),
                        ],
                        const SizedBox(width: 4),

                        // Clean Input Text Field
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: barBorder, width: 1),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: textCol, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: widget.editingMessage != null
                                    ? 'Edit pesan...'
                                    : 'LAJU encrypted message...',
                                hintStyle: TextStyle(color: hintCol, fontSize: 14),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    widget.editingMessage != null
                                        ? Icons.edit_rounded
                                        : Icons.lock_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                                suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Send / Voice Note / Confirm Edit Action Button
                        Builder(
                          builder: (context) {
                            final isEditing = widget.editingMessage != null;
                            final showSendOrConfirm = isEditing || _hasText;
                            final icon = isEditing
                                ? Icons.check_rounded
                                : (_hasText ? Icons.send_rounded : Icons.mic_rounded);

                            return GestureDetector(
                              onTap: showSendOrConfirm ? _handleSend : _onMicTap,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: showSendOrConfirm
                                      ? const LinearGradient(
                                          colors: [AppColors.primary, Color(0xFF059669)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: showSendOrConfirm
                                      ? null
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: showSendOrConfirm
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : const Color(0xFFE2E8F0)),
                                    width: 1,
                                  ),
                                  boxShadow: showSendOrConfirm
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  icon,
                                  color: showSendOrConfirm ? Colors.white : AppColors.primary,
                                  size: isEditing ? 22 : 20,
                                ),
                              ),
                            );
                          },
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

  Widget _buildReplyThumbnail(String path) {
    if (path.startsWith('data:image')) {
      try {
        final b64 = path.contains(',') ? path.split(',').last : path;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18, color: Colors.grey),
        );
      } catch (_) {}
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18, color: Colors.grey),
      );
    }
    if (File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18, color: Colors.grey),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 18, color: Colors.grey),
      );
    }
    return Container(
      color: Colors.black12,
      child: const Icon(Icons.image, size: 18, color: Colors.grey),
    );
  }
}
