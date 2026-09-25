import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../domain/models/message_model.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../calls/presentation/screens/active_group_call_screen.dart';
import '../widgets/attachment_bottom_sheet.dart';
import '../../../conversations/presentation/screens/group_profile_screen.dart';

import '../../../conversations/domain/group_controller.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../settings/presentation/screens/wallpaper_settings_screen.dart';
import '../../../../core/services/voice_note_service.dart';
import 'disappearing_messages_screen.dart';
import 'image_preview_send_screen.dart';
import 'document_preview_send_screen.dart';
import '../widgets/sticker_picker_sheet.dart';
import '../../domain/models/sticker_model.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const GroupChatScreen({
    super.key,
    this.groupId = 'grp-1',
    this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ScrollController _scrollController = ScrollController();
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;
  List<MessageModel> _messages = [];
  Timer? _pollTimer;
  bool _showScrollToBottom = false;

  bool _isSearching = false;
  final TextEditingController _inGroupSearchController = TextEditingController();
  String _inGroupSearchQuery = '';
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ConversationService.instance.currentActiveConversationId = widget.groupId;
    final mem = ConversationService.instance.getMemoryMessages(widget.groupId);
    if (mem != null) {
      _messages = List<MessageModel>.from(mem);
    }
    _loadMessages();
    _startPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(immediate: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = (maxScroll - currentScroll) > 280;
    if (show != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = show;
      });
    }
  }

  void _scrollToBottom({bool immediate = false}) {
    void doScroll() {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (immediate) {
        _scrollController.jumpTo(maxScroll);
      } else {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }

    if (immediate) {
      doScroll();
      Future.delayed(const Duration(milliseconds: 50), doScroll);
      Future.delayed(const Duration(milliseconds: 150), doScroll);
    } else {
      doScroll();
    }
  }

  Widget _buildDateDivider(DateTime date, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          DateHelper.formatChatDivider(date),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    ConversationService.instance.sendTypingStatus(widget.groupId, false);
    ConversationService.instance.setTyping(widget.groupId, false);
    if (ConversationService.instance.currentActiveConversationId == widget.groupId) {
      ConversationService.instance.currentActiveConversationId = null;
    }
    _pollTimer?.cancel();
    _inGroupSearchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    // Step 1: Load from SQLite cache instantly (offline-ready)
    final cached = await ConversationService.instance.getMessagesFromCache(widget.groupId);
    if (mounted && cached.isNotEmpty) {
      _mergeAndSetMessages(cached);
      if (!_initialScrollDone) {
        _initialScrollDone = true;
        _scrollToBottom(immediate: true);
      }
    }

    // Step 2: Fetch fresh messages from API
    await _syncMessages();
    if (mounted && !_initialScrollDone) {
      _initialScrollDone = true;
      _scrollToBottom(immediate: true);
    }
  }

  void _markIncomingAsRead(List<MessageModel> msgs) {
    for (final m in msgs) {
      if (!m.isOutgoing && m.status != MessageDeliveryStatus.read) {
        ConversationService.instance.markMessageRead(m.id);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      _syncMessages();
    });
  }

  Future<void> _syncMessages() async {
    if (!mounted) return;
    try {
      final msgs = await ConversationService.instance.fetchMessages(widget.groupId);
      if (mounted && msgs.isNotEmpty) {
        _mergeAndSetMessages(msgs);
      }
    } catch (_) {}
  }

  void _mergeAndSetMessages(List<MessageModel> incoming) {
    if (!mounted || incoming.isEmpty) return;

    final existingIds = _messages.map((m) => m.id).toSet();
    bool hasNewIncoming = false;
    for (final inc in incoming) {
      if (!inc.isOutgoing && !existingIds.contains(inc.id)) {
        hasNewIncoming = true;
        break;
      }
    }

    final combined = List<MessageModel>.from(_messages)..addAll(incoming);
    final merged = MessageModel.deduplicate(combined);

    bool hasChanged = merged.length != _messages.length;
    if (!hasChanged) {
      for (int i = 0; i < merged.length; i++) {
        if (merged[i].id != _messages[i].id ||
            merged[i].status != _messages[i].status ||
            merged[i].reactions.length != _messages[i].reactions.length ||
            merged[i].content != _messages[i].content) {
          hasChanged = true;
          break;
        }
      }
    }

    if (hasChanged) {
      setState(() {
        _messages = merged;
      });
      ConversationService.instance.updateMemoryMessages(widget.groupId, merged);
      _markIncomingAsRead(merged);
      if (!_initialScrollDone) {
        _initialScrollDone = true;
        _scrollToBottom(immediate: true);
      } else {
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
      }
    } else {
      ConversationService.instance.updateMemoryMessages(widget.groupId, merged);
      if (!_initialScrollDone && merged.isNotEmpty) {
        _initialScrollDone = true;
        _scrollToBottom(immediate: true);
      }
    }

    if (hasNewIncoming) {
      LajuSoundService.playIncomingNotification(isGroup: true);
    }
  }

  void _sendMessage(String text) async {
    ConversationService.instance.sendTypingStatus(widget.groupId, false);
    LajuSoundService.playOutgoingTone();
    final localId = 'g-${DateTime.now().millisecondsSinceEpoch}';
    final replyingToMsg = _replyingTo;
    final localMsg = MessageModel(
      id: localId,
      clientMessageId: localId,
      conversationId: widget.groupId,
      senderName: 'You',
      content: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageDeliveryStatus.sending,
      replyTo: replyingToMsg,
    );

    setState(() {
      _messages.add(localMsg);
      _replyingTo = null;
    });

    // Save optimistically to SQLite
    await LocalDatabase.instance.insertSentMessage(localMsg);
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    final sent = await ConversationService.instance.sendMessage(
      conversationId: widget.groupId,
      text: text,
      clientMessageId: localId,
      replyTo: replyingToMsg,
    );

    if (mounted && sent != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localId || m.clientMessageId == localId);
        if (idx != -1) {
          _messages[idx] = sent;
        }
      });
      _syncMessages();
    }
  }

  void _handleSendVoiceNote(VoiceRecordResult result) async {
    final voiceMsg = MessageModel(
      id: 'voice-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.groupId,
      senderName: 'You',
      content: 'Voice Message (${result.formattedDuration})',
      timestamp: DateTime.now(),
      isOutgoing: true,
      contentType: MessageContentType.voiceNote,
      attachmentName: 'Group Voice Note (${result.formattedDuration})',
      attachmentSize: result.formattedDuration,
      attachmentPath: result.filePath,
      status: MessageDeliveryStatus.sending,
    );

    setState(() {
      _messages.add(voiceMsg);
    });

    await LocalDatabase.instance.insertSentMessage(voiceMsg);

    final sent = await ConversationService.instance.sendMessage(
      conversationId: widget.groupId,
      text: 'Voice Message (${result.formattedDuration})',
      clientMessageId: voiceMsg.id,
      messageType: 'AUDIO',
      attachmentPath: result.filePath,
      attachmentName: voiceMsg.attachmentName,
      attachmentSize: result.formattedDuration,
    );

    if (mounted && sent != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == voiceMsg.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            id: sent.id,
            status: sent.status,
          );
        }
      });
    }
  }

  void _handleReaction(MessageModel message, String emoji) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    final existing = List<String>.from(_messages[index].reactions);
    final isAdding = !existing.contains(emoji);
    if (isAdding) {
      existing.add(emoji);
    } else {
      existing.remove(emoji);
    }
    setState(() {
      _messages[index] = _messages[index].copyWith(reactions: existing);
    });
    ConversationService.instance.toggleReaction(message.id, emoji, isAdding);
  }

  void _handleReply(MessageModel message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _handleEditMessage(MessageModel message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
    });
  }

  void _cancelEdit() {
    setState(() => _editingMessage = null);
  }

  void _confirmEditMessage(String newText) async {
    if (_editingMessage == null) return;
    final targetMsg = _editingMessage!;
    final index = _messages.indexWhere((m) => m.id == targetMsg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          content: newText,
          isEdited: true,
        );
        _editingMessage = null;
      });
      await ConversationService.instance.editMessage(targetMsg.id, newText);
      if (mounted) {
        LajuToast.info(context, 'Pesan grup berhasil diperbarui (diedit)');
      }
    }
  }

  void _openAttachmentMenu() async {
    final result = await AttachmentBottomSheet.show(context);
    if (result != null) {
      final filePath = result.data is String ? result.data as String : null;
      if (result.type == AttachmentType.document) {
        if (filePath == null || !mounted) return;
        final previewResult = await Navigator.push<DocumentPreviewResult>(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewSendScreen(
              filePath: filePath,
              fileName: result.title,
              fileSize: result.fileSize ?? '',
              recipientName: widget.groupName ?? 'Grup',
            ),
          ),
        );
        if (previewResult == null || !mounted) return; // User cancelled

        final caption = previewResult.caption;
        final isImg = ConversationService.isImageFile(previewResult.fileName) || ConversationService.isImageFile(filePath);
        final docId = '${isImg ? 'img' : 'doc'}-${DateTime.now().millisecondsSinceEpoch}';
        final docMsg = MessageModel(
          id: docId,
          clientMessageId: docId,
          conversationId: widget.groupId,
          senderName: 'You',
          content: caption,
          attachmentName: previewResult.fileName,
          attachmentSize: previewResult.fileSize,
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sending,
        );
        setState(() {
          _messages.add(docMsg);
        });
        await LocalDatabase.instance.insertSentMessage(docMsg);
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

        final sent = await ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: caption,
          clientMessageId: docId,
          messageType: isImg ? 'IMAGE' : 'DOCUMENT',
          attachmentPath: filePath,
          attachmentName: previewResult.fileName,
          attachmentSize: previewResult.fileSize,
        );
        if (mounted && sent != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == docId || m.clientMessageId == docId);
            if (idx != -1) {
              _messages[idx] = sent.copyWith(attachmentPath: filePath);
            }
          });
          _syncMessages();
        }
      } else if (result.type == AttachmentType.camera || result.type == AttachmentType.gallery) {
        if (filePath == null) return;
        final previewResult = await Navigator.push<ImagePreviewResult>(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewSendScreen(
              imagePath: filePath,
              recipientName: widget.groupName ?? 'Grup',
            ),
          ),
        );
        if (previewResult == null) return; // User cancelled

        final caption = previewResult.caption;
        final imgId = 'img-${DateTime.now().millisecondsSinceEpoch}';
        final imgMsg = MessageModel(
          id: imgId,
          clientMessageId: imgId,
          conversationId: widget.groupId,
          senderName: 'You',
          content: caption,
          attachmentName: result.title,
          attachmentSize: result.fileSize,
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sending,
        );
        setState(() {
          _messages.add(imgMsg);
        });
        await LocalDatabase.instance.insertSentMessage(imgMsg);

        final sent = await ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: caption,
          clientMessageId: imgId,
          messageType: 'IMAGE',
          attachmentPath: filePath,
          attachmentName: result.title,
          attachmentSize: result.fileSize,
        );
        if (mounted && sent != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == imgId || m.clientMessageId == imgId);
            if (idx != -1) {
              _messages[idx] = sent.copyWith(attachmentPath: filePath);
            }
          });
          _syncMessages();
        }
      } else if (result.type == AttachmentType.audio) {
        if (filePath == null || !mounted) return;
        final previewResult = await Navigator.push<DocumentPreviewResult>(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentPreviewSendScreen(
              filePath: filePath,
              fileName: result.title,
              fileSize: result.fileSize ?? '',
              recipientName: widget.groupName ?? 'Grup',
            ),
          ),
        );
        if (previewResult == null || !mounted) return; // User cancelled

        final caption = previewResult.caption;
        final audId = 'aud-${DateTime.now().millisecondsSinceEpoch}';
        final audMsg = MessageModel(
          id: audId,
          clientMessageId: audId,
          conversationId: widget.groupId,
          senderName: 'You',
          content: caption,
          attachmentName: previewResult.fileName,
          attachmentSize: previewResult.fileSize,
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sending,
        );
        setState(() {
          _messages.add(audMsg);
        });
        await LocalDatabase.instance.insertSentMessage(audMsg);
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

        final sent = await ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: caption,
          clientMessageId: audId,
          messageType: 'AUDIO',
          attachmentPath: filePath,
          attachmentName: previewResult.fileName,
          attachmentSize: previewResult.fileSize,
        );
        if (mounted && sent != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == audId || m.clientMessageId == audId);
            if (idx != -1) {
              _messages[idx] = sent.copyWith(attachmentPath: filePath);
            }
          });
          _syncMessages();
        }
      } else if (result.type == AttachmentType.contact) {
        _sendMessage(result.title);
      } else if (result.type == AttachmentType.location) {
        final loc = result.data is LocationData ? result.data as LocationData : null;
        if (loc != null) {
          final locId = 'loc-${DateTime.now().millisecondsSinceEpoch}';
          final locJson = loc.toJson();
          final locMsg = MessageModel(
            id: locId,
            clientMessageId: locId,
            conversationId: widget.groupId,
            senderName: 'You',
            content: locJson,
            attachmentName: loc.name,
            attachmentSize: loc.address,
            timestamp: DateTime.now(),
            isOutgoing: true,
            contentType: MessageContentType.location,
            status: MessageDeliveryStatus.sending,
          );
          setState(() {
            _messages.add(locMsg);
          });
          await LocalDatabase.instance.insertSentMessage(locMsg);
          _scrollToBottom(immediate: false);

          final sent = await ConversationService.instance.sendMessage(
            conversationId: widget.groupId,
            text: locJson,
            clientMessageId: locId,
            messageType: 'LOCATION',
            attachmentName: loc.name,
            attachmentSize: loc.address,
          );
          if (mounted && sent != null) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == locId || m.clientMessageId == locId);
              if (idx != -1) {
                _messages[idx] = sent;
              }
            });
            _syncMessages();
          }
        }
      } else if (result.type == AttachmentType.sticker) {
        _openStickerPicker();
      }
    }
  }

  void _openStickerPicker() {
    StickerPickerSheet.show(
      context: context,
      onStickerSelected: _sendSticker,
    );
  }

  void _sendSticker(StickerItem sticker) async {
    final stkId = 'stk-${DateTime.now().millisecondsSinceEpoch}';
    final replyToCopy = _replyingTo;
    final stickerMsg = MessageModel(
      id: stkId,
      clientMessageId: stkId,
      conversationId: widget.groupId,
      senderName: 'You',
      content: sticker.name,
      attachmentName: sticker.id,
      attachmentPath: sticker.assetPath,
      timestamp: DateTime.now(),
      isOutgoing: true,
      contentType: MessageContentType.sticker,
      status: MessageDeliveryStatus.sending,
      replyTo: replyToCopy,
    );

    setState(() {
      _messages.add(stickerMsg);
      _replyingTo = null;
    });
    await LocalDatabase.instance.insertSentMessage(stickerMsg);
    Future.delayed(const Duration(milliseconds: 50), () => _scrollToBottom(immediate: true));

    final sent = await ConversationService.instance.sendMessage(
      conversationId: widget.groupId,
      text: sticker.name,
      clientMessageId: stkId,
      messageType: 'STICKER',
      attachmentPath: sticker.assetPath,
      attachmentName: sticker.id,
      replyTo: replyToCopy,
    );

    if (mounted && sent != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == stkId || m.clientMessageId == stkId);
        if (idx != -1) {
          _messages[idx] = sent.copyWith(attachmentPath: sticker.assetPath);
        }
      });
      _syncMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return AnimatedBuilder(
      animation: GroupController.instance,
      builder: (context, _) {
        final group = GroupController.instance.getGroup(widget.groupId);
        final displayName = group?.name ?? widget.groupName ?? 'Operations Team';
        final memberCount = group?.members.length ?? 6;
        final isUserAdmin = GroupController.instance.isCurrentUserAdmin(widget.groupId);
        final canSend = group == null || group.canSendMessages || isUserAdmin;

  void _showMediaSheet(BuildContext context, bool isDark) {
    final mediaList = _messages.where((m) => m.contentType == MessageContentType.attachment).toList();
    if (mediaList.isEmpty) {
      LajuToast.info(context, 'Belum ada media atau berkas dibagikan dalam grup ini');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Media Grup (${mediaList.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mediaList.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                    itemBuilder: (ctx, i) {
                      final item = mediaList[i];
                      final name = item.attachmentName ?? item.content;
                      final isImg = item.attachmentPath != null &&
                          (item.attachmentPath!.startsWith('data:image') ||
                              item.attachmentPath!.endsWith('.jpg') ||
                              item.attachmentPath!.endsWith('.png') ||
                              item.attachmentPath!.endsWith('.jpeg'));

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isImg ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal()),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          if (isImg && item.attachmentPath != null) {
                            LajuImageViewer.show(
                              context,
                              imagePath: item.attachmentPath!,
                              title: item.isOutgoing ? 'Anda' : item.senderName,
                              subtitle: DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal()),
                            );
                          } else {
                            LajuToast.info(context, 'Membuka $name');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmClearChat(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Bersihkan Chat Grup?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Semua pesan dalam grup ini akan dihapus dari perangkat Anda.',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() {
                  _messages.clear();
                });
                ConversationService.instance.updateMemoryMessages(widget.groupId, []);
                LajuToast.info(context, 'Pesan grup berhasil dibersihkan');
              },
              child: const Text('Bersihkan Pesan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveGroup(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Keluar dari Grup?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: const Text(
            'Anda tidak akan lagi menerima pesan dari grup ini.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFFEF4444),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
                LajuToast.info(context, 'Anda telah keluar dari grup');
              },
              child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String title,
    bool isDark, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.danger : (isDark ? Colors.white : const Color(0xFF1F2937));
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: isDestructive ? AppColors.danger : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B1015) : const Color(0xFFF3F4F6),
          appBar: _isSearching
              ? AppBar(
                  titleSpacing: 0,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _inGroupSearchController.clear();
                        _inGroupSearchQuery = '';
                      });
                    },
                  ),
                  title: TextField(
                    controller: _inGroupSearchController,
                    autofocus: true,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari dalam grup...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _inGroupSearchQuery = val.trim();
                      });
                    },
                  ),
                  actions: [
                    if (_inGroupSearchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                        onPressed: () {
                          _inGroupSearchController.clear();
                          setState(() => _inGroupSearchQuery = '');
                        },
                      ),
                  ],
                )
              : AppBar(
                  titleSpacing: 0,
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  title: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupProfileScreen(
                            groupId: widget.groupId,
                            groupName: displayName,
                            groupDescription: group?.description ?? '',
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        ModernAvatar(
                          name: displayName,
                          radius: 19,
                          isVerified: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              ValueListenableBuilder<Map<String, bool>>(
                                valueListenable: ConversationService.instance.typingStatusNotifier,
                                builder: (context, typings, _) {
                                  final isTyping = typings[widget.groupId] == true;
                                  if (isTyping) {
                                    return const Text(
                                      'sedang mengetik...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }
                                  return Text(
                                    '$memberCount ${context.tr('members')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
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
                  actions: [
                    IconButton(
                      icon: Icon(Icons.call_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveGroupCallScreen(
                              groupName: displayName,
                              initialParticipants: group?.members
                                      .where((m) => m.id != 'm-you')
                                      .map((m) => m.name)
                                      .toList() ??
                                  [],
                              isVideo: false,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.videocam_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveGroupCallScreen(
                              groupName: displayName,
                              initialParticipants: group?.members
                                      .where((m) => m.id != 'm-you')
                                      .map((m) => m.name)
                                      .toList() ??
                                  [],
                              isVideo: true,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                      onSelected: (value) {
                        switch (value) {
                          case 'info':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GroupProfileScreen(
                                  groupId: widget.groupId,
                                  groupName: displayName,
                                  groupDescription: group?.description ?? '',
                                ),
                              ),
                            );
                            break;
                          case 'media':
                            _showMediaSheet(context, isDark);
                            break;
                          case 'search':
                            setState(() => _isSearching = true);
                            break;
                          case 'wallpaper':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WallpaperSettingsScreen(),
                              ),
                            );
                            break;
                          case 'disappearing':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DisappearingMessagesScreen(initialTimer: 'Off'),
                              ),
                            );
                            break;
                          case 'clear':
                            _confirmClearChat(context, isDark);
                            break;
                          case 'leave':
                            _confirmLeaveGroup(context, isDark);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        _buildMenuItem('info', Icons.info_outline_rounded, 'Info Grup', isDark),
                        _buildMenuItem('media', Icons.perm_media_outlined, 'Media & Lampiran', isDark),
                        _buildMenuItem('search', Icons.search_rounded, 'Cari Pesan', isDark),
                        _buildMenuItem('wallpaper', Icons.wallpaper_rounded, 'Wallpaper Chat', isDark),
                        _buildMenuItem('disappearing', Icons.timer_outlined, 'Pesan Sementara', isDark),
                        const PopupMenuDivider(height: 1),
                        _buildMenuItem('clear', Icons.delete_sweep_outlined, 'Bersihkan Chat', isDark),
                        _buildMenuItem('leave', Icons.exit_to_app_rounded, 'Keluar dari Grup', isDark, isDestructive: true),
                      ],
                    ),
                  ],
                ),
          body: ListenableBuilder(
            listenable: ChatAppearanceController.instance,
            builder: (context, _) {
              final activeWallpaperId = ChatAppearanceController.instance.selectedWallpaper;
              final activeWallpaper = kPresetWallpapers.firstWhere(
                (w) => w.id == activeWallpaperId,
                orElse: () => kPresetWallpapers.first,
              );
              final assetPath = activeWallpaper.getAssetPath(isDark);
              final screenSize = MediaQuery.sizeOf(context);

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    width: screenSize.width,
                    height: screenSize.height,
                    child: Container(
                      color: isDark ? const Color(0xFF071216) : activeWallpaper.backgroundColor,
                    ),
                  ),
                  if (assetPath != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      width: screenSize.width,
                      height: screenSize.height,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  Column(
                    children: [
                      Expanded(
                        child: _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.black12,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.groups_rounded, size: 24, color: AppColors.primary),
                                const SizedBox(height: 8),
                                Text(
                                  'Grup Terenkripsi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pesan dalam grup ini dienkripsi secara end-to-end. Hanya anggota grup yang dapat membaca pesan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final displayedMsgs = _isSearching && _inGroupSearchQuery.isNotEmpty
                              ? _messages
                                  .where((m) => m.content
                                      .toLowerCase()
                                      .contains(_inGroupSearchQuery.toLowerCase()))
                                  .toList()
                              : _messages;

                          if (displayedMsgs.isEmpty && _isSearching) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black26),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tidak ada pesan yang cocok',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '"$_inGroupSearchQuery"',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            itemCount: displayedMsgs.length,
                            itemBuilder: (context, index) {
                              final msg = displayedMsgs[index];
                              final isFirstOrDiffDay = index == 0 ||
                                  !DateHelper.isSameDay(msg.timestamp, displayedMsgs[index - 1].timestamp);

                              final isSameSenderAsPrev = index > 0 &&
                                  !isFirstOrDiffDay &&
                                  displayedMsgs[index - 1].isOutgoing == msg.isOutgoing &&
                                  displayedMsgs[index - 1].senderName == msg.senderName;
                              final topMargin = isSameSenderAsPrev ? 1.0 : 4.0;

                              final bubble = ChatBubble(
                                message: msg,
                                isGroup: true,
                                topMargin: topMargin,
                                bottomMargin: 1.0,
                                onReactionSelected: (emoji) => _handleReaction(msg, emoji),
                                onReply: _handleReply,
                                onEdit: _handleEditMessage,
                                onDelete: () async {
                                  final msgToDelete = displayedMsgs[index];
                                  setState(() => _messages.removeWhere((m) => m.id == msgToDelete.id));
                                  await ConversationService.instance.deleteMessage(msgToDelete.id);
                                },
                              );

                              if (isFirstOrDiffDay) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDateDivider(msg.timestamp, isDark),
                                    bubble,
                                  ],
                                );
                              }
                              return bubble;
                            },
                          );
                        },
                      ),
              ),
              if (canSend)
                ChatInputBar(
                  onSend: _sendMessage,
                  onAttach: _openAttachmentMenu,
                  onStickerTap: _openStickerPicker,
                  onSendVoiceNote: _handleSendVoiceNote,
                  replyingTo: _replyingTo,
                  onCancelReply: _cancelReply,
                  editingMessage: _editingMessage,
                  onCancelEdit: _cancelEdit,
                  onConfirmEdit: _confirmEditMessage,
                  onTypingChanged: (isTyping) {
                    ConversationService.instance.sendTypingStatus(widget.groupId, isTyping);
                  },
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  child: Center(
                    child: Text(
                      context.tr('onlyAdminsCanSend'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Scroll-to-bottom Floating Action Button (WhatsApp style)
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 74,
                child: Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black38,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _scrollToBottom,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 26,
                        color: isDark ? AppColors.cyan : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
      },
    );
  }
}
