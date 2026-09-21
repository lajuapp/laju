import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/models/message_model.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../calls/presentation/screens/active_group_call_screen.dart';
import '../widgets/attachment_bottom_sheet.dart';
import '../../../conversations/presentation/screens/group_profile_screen.dart';

import '../../../conversations/domain/group_controller.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../../core/services/voice_note_service.dart';

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
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;
  List<MessageModel> _messages = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _loadMessages() async {
    // Step 1: Load from SQLite cache instantly
    final cached = await ConversationService.instance.getMessagesFromCache(widget.groupId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _messages = cached;
      });
    }

    // Step 2: Fetch fresh messages from API in background
    try {
      final msgs = await ConversationService.instance.fetchMessages(widget.groupId);
      if (mounted && msgs.isNotEmpty) {
        setState(() {
          _messages = msgs;
        });
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final msgs = await ConversationService.instance.fetchMessages(widget.groupId);
        if (mounted && msgs.isNotEmpty) {
          if (msgs.length != _messages.length ||
              (msgs.isNotEmpty && _messages.isNotEmpty && msgs.last.id != _messages.last.id)) {
            setState(() {
              _messages = msgs;
            });
          }
        }
      } catch (_) {}
    });
  }

  void _sendMessage(String text) async {
    LajuSoundService.playOutgoingTone();
    final localMsg = MessageModel(
      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.groupId,
      senderName: 'You',
      content: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageDeliveryStatus.sending,
      replyTo: _replyingTo,
    );

    setState(() {
      _messages.add(localMsg);
      _replyingTo = null;
    });

    await LocalDatabase.instance.insertSentMessage(localMsg);

    final sent = await ConversationService.instance.sendMessage(
      conversationId: widget.groupId,
      text: text,
      clientMessageId: localMsg.id,
    );

    if (mounted && sent != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localMsg.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            id: sent.id,
            status: sent.status,
          );
        }
      });
    }
  }

  void _handleSendVoiceNote(VoiceRecordResult result) async {
    final voiceMsg = MessageModel(
      id: 'voice-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.groupId,
      senderName: 'You',
      content: '🎤 Voice Message (${result.formattedDuration})',
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
      text: '🎤 Voice Message (${result.formattedDuration})',
      clientMessageId: voiceMsg.id,
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
        final docMsg = MessageModel(
          id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.groupId,
          senderName: 'You',
          content: result.subtitle ?? '📄 ${result.title}',
          attachmentName: result.title,
          attachmentSize: result.fileSize ?? '',
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sent,
        );
        setState(() {
          _messages.add(docMsg);
        });
        ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: '📄 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: docMsg.id,
        );
      } else if (result.type == AttachmentType.camera || result.type == AttachmentType.gallery) {
        final imgMsg = MessageModel(
          id: 'img-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.groupId,
          senderName: 'You',
          content: '📷 ${result.title} (${result.fileSize ?? ""})',
          attachmentName: result.title,
          attachmentSize: result.fileSize,
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sent,
        );
        setState(() {
          _messages.add(imgMsg);
        });
        ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: '📷 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: imgMsg.id,
        );
      } else if (result.type == AttachmentType.audio) {
        final audMsg = MessageModel(
          id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
          conversationId: widget.groupId,
          senderName: 'You',
          content: '🎵 ${result.title} (${result.fileSize ?? ""})',
          attachmentName: result.title,
          attachmentSize: result.fileSize,
          attachmentPath: filePath,
          timestamp: DateTime.now(),
          isOutgoing: true,
          contentType: MessageContentType.attachment,
          status: MessageDeliveryStatus.sent,
        );
        setState(() {
          _messages.add(audMsg);
        });
        ConversationService.instance.sendMessage(
          conversationId: widget.groupId,
          text: '🎵 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: audMsg.id,
        );
      } else if (result.type == AttachmentType.contact) {
        _sendMessage(result.title);
      }
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

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B1015) : const Color(0xFFF3F4F6),
          appBar: AppBar(
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
                        Text(
                          '$memberCount ${context.tr('members')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
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
              IconButton(
                icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                onPressed: () {
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
              ),
            ],
          ),
          body: Column(
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
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return ChatBubble(
                            message: msg,
                            onReactionSelected: (emoji) => _handleReaction(msg, emoji),
                            onReply: _handleReply,
                            onEdit: _handleEditMessage,
                            onDelete: () async {
                              final msgToDelete = _messages[index];
                              setState(() => _messages.removeAt(index));
                              await ConversationService.instance.deleteMessage(msgToDelete.id);
                            },
                          );
                        },
                      ),
              ),
              if (canSend)
                ChatInputBar(
                  onSend: _sendMessage,
                  onAttach: _openAttachmentMenu,
                  onSendVoiceNote: _handleSendVoiceNote,
                  replyingTo: _replyingTo,
                  onCancelReply: _cancelReply,
                  editingMessage: _editingMessage,
                  onCancelEdit: _cancelEdit,
                  onConfirmEdit: _confirmEditMessage,
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
        );
      },
    );

  }
}
