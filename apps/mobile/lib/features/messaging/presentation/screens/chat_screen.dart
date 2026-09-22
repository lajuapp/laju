import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/core.dart';
import '../../domain/models/message_model.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../../security/presentation/screens/key_verification_screen.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../widgets/attachment_bottom_sheet.dart';
import 'disappearing_messages_screen.dart';
import '../../../conversations/presentation/screens/user_profile_screen.dart';
import '../../../settings/presentation/screens/wallpaper_settings_screen.dart';
import '../../../../core/services/voice_note_service.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool isGroup;
  final String safetyNumber;
  final String? avatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.isGroup = false,
    this.safetyNumber = '4812 ••• 9901',
    this.avatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<MessageModel> _messages;
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;
  Timer? _pollTimer;
  bool _showScrollToBottom = false;

  bool _isSearching = false;
  final TextEditingController _inChatSearchController = TextEditingController();
  String _inChatSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ConversationService.instance.currentActiveConversationId = widget.conversationId;
    final mem = ConversationService.instance.getMemoryMessages(widget.conversationId);
    _messages = mem != null ? List<MessageModel>.from(mem) : [];
    _loadMessagesFromApi();
    _startPolling();
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

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      _syncMessages();
    });
  }

  Future<void> _syncMessages() async {
    if (!mounted) return;
    try {
      final apiMsgs = await ConversationService.instance.fetchMessages(widget.conversationId);
      if (mounted && apiMsgs.isNotEmpty) {
        _mergeAndSetMessages(apiMsgs);
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

    final merged = List<MessageModel>.from(_messages);
    for (final inc in incoming) {
      final idx = merged.indexWhere((m) =>
          m.id == inc.id ||
          (inc.clientMessageId != null && (m.id == inc.clientMessageId || m.clientMessageId == inc.clientMessageId)));

      if (idx != -1) {
        merged[idx] = inc.copyWith(
          attachmentPath: merged[idx].attachmentPath ?? inc.attachmentPath,
          attachmentName: merged[idx].attachmentName ?? inc.attachmentName,
          replyTo: merged[idx].replyTo ?? inc.replyTo,
        );
      } else {
        merged.add(inc);
      }
    }

    merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    bool hasChanged = merged.length != _messages.length;
    if (!hasChanged) {
      for (int i = 0; i < merged.length; i++) {
        if (merged[i].id != _messages[i].id ||
            merged[i].status != _messages[i].status ||
            merged[i].reactions.length != _messages[i].reactions.length) {
          hasChanged = true;
          break;
        }
      }
    }

    if (hasChanged) {
      setState(() {
        _messages = merged;
      });
      ConversationService.instance.updateMemoryMessages(widget.conversationId, merged);
      _markIncomingAsRead(merged);
      Future.delayed(const Duration(milliseconds: 60), _scrollToBottom);
    } else {
      ConversationService.instance.updateMemoryMessages(widget.conversationId, merged);
    }

    if (hasNewIncoming) {
      LajuSoundService.playIncomingNotification();
    }
  }

  void _markIncomingAsRead(List<MessageModel> msgs) {
    for (final m in msgs) {
      if (!m.isOutgoing && m.status != MessageDeliveryStatus.read) {
        ConversationService.instance.markMessageRead(m.id);
      }
    }
  }

  @override
  void dispose() {
    if (ConversationService.instance.currentActiveConversationId == widget.conversationId) {
      ConversationService.instance.currentActiveConversationId = null;
    }
    _pollTimer?.cancel();
    _inChatSearchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessagesFromApi() async {
    // Step 1: Load from SQLite cache instantly (offline-ready)
    final cached = await ConversationService.instance.getMessagesFromCache(widget.conversationId);
    if (mounted && cached.isNotEmpty) {
      _mergeAndSetMessages(cached);
    }

    // Step 2: Fetch fresh messages from API
    _syncMessages();
  }

  void _sendMessage(String text) async {
    LajuSoundService.playOutgoingTone();
    final localId = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final localMsg = MessageModel(
      id: localId,
      clientMessageId: localId,
      conversationId: widget.conversationId,
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

    // Save optimistically to SQLite
    await LocalDatabase.instance.insertSentMessage(localMsg);

    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    // Send to backend
    final sentMsg = await ConversationService.instance.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      clientMessageId: localId,
    );

    if (mounted && sentMsg != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localId || m.clientMessageId == localId);
        if (idx != -1) {
          _messages[idx] = sentMsg;
        }
      });
      _syncMessages();
    }
  }

  void _handleSendVoiceNote(VoiceRecordResult result) async {
    final voiceMsg = MessageModel(
      id: 'voice-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderName: 'You',
      content: '🎤 Voice Message (${result.formattedDuration})',
      timestamp: DateTime.now(),
      isOutgoing: true,
      contentType: MessageContentType.voiceNote,
      attachmentName: 'Voice Note (${result.formattedDuration})',
      attachmentSize: result.formattedDuration,
      attachmentPath: result.filePath,
      status: MessageDeliveryStatus.sending,
    );

    setState(() {
      _messages.add(voiceMsg);
    });

    // Save optimistically to SQLite
    await LocalDatabase.instance.insertSentMessage(voiceMsg);

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    final sentMsg = await ConversationService.instance.sendMessage(
      conversationId: widget.conversationId,
      text: '🎤 Voice Message (${result.formattedDuration})',
      clientMessageId: voiceMsg.id,
      messageType: 'AUDIO',
      attachmentPath: result.filePath,
      attachmentName: voiceMsg.attachmentName,
      attachmentSize: result.formattedDuration,
    );

    if (mounted && sentMsg != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == voiceMsg.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            id: sentMsg.id,
            status: sentMsg.status,
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
        LajuToast.info(context, 'Pesan berhasil diperbarui (diedit)');
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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

  void _openAttachmentMenu() async {
    final result = await AttachmentBottomSheet.show(context);
    if (result != null) {
      final filePath = result.data is String ? result.data as String : null;
      if (result.type == AttachmentType.document) {
        final docId = 'doc-${DateTime.now().millisecondsSinceEpoch}';
        final docMsg = MessageModel(
          id: docId,
          clientMessageId: docId,
          conversationId: widget.conversationId,
          senderName: 'You',
          content: result.subtitle ?? '📄 ${result.title}',
          attachmentName: result.title,
          attachmentSize: result.fileSize ?? '',
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
          conversationId: widget.conversationId,
          text: '📄 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: docId,
          messageType: 'DOCUMENT',
          attachmentPath: filePath,
          attachmentName: result.title,
          attachmentSize: result.fileSize,
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
        final imgId = 'img-${DateTime.now().millisecondsSinceEpoch}';
        final imgMsg = MessageModel(
          id: imgId,
          clientMessageId: imgId,
          conversationId: widget.conversationId,
          senderName: 'You',
          content: '📷 ${result.title} (${result.fileSize ?? ""})',
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
        Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

        final sent = await ConversationService.instance.sendMessage(
          conversationId: widget.conversationId,
          text: '📷 ${result.title} (${result.fileSize ?? ""})',
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
        final audId = 'aud-${DateTime.now().millisecondsSinceEpoch}';
        final audMsg = MessageModel(
          id: audId,
          clientMessageId: audId,
          conversationId: widget.conversationId,
          senderName: 'You',
          content: '🎵 ${result.title} (${result.fileSize ?? ""})',
          attachmentName: result.title,
          attachmentSize: result.fileSize,
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
          conversationId: widget.conversationId,
          text: '🎵 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: audId,
          messageType: 'AUDIO',
          attachmentPath: filePath,
          attachmentName: result.title,
          attachmentSize: result.fileSize,
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
      }
    }
  }

  void _startCall(bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveCallScreen(
          contactName: widget.title,
          isVideo: isVideo,
        ),
      ),
    );
  }

  void _showMediaSheet(BuildContext context, bool isDark) {
    final mediaList = _messages.where((m) => m.contentType == MessageContentType.attachment).toList();
    if (mediaList.isEmpty) {
      LajuToast.info(context, 'Belum ada media atau berkas dibagikan dalam obrolan ini');
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
                      'Media & Lampiran (${mediaList.length})',
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
            'Bersihkan Chat?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Semua pesan dalam obrolan ini akan dihapus dari perangkat Anda.',
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
                ConversationService.instance.updateMemoryMessages(widget.conversationId, []);
                LajuToast.info(context, 'Chat berhasil dibersihkan');
              },
              child: const Text('Bersihkan Pesan', style: TextStyle(fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1015) : const Color(0xFFF3F4F6),
      appBar: _isSearching
          ? LajuGlassAppBar(
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _inChatSearchController.clear();
                    _inChatSearchQuery = '';
                  });
                },
              ),
              title: TextField(
                controller: _inChatSearchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari dalam obrolan...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _inChatSearchQuery = val.trim();
                  });
                },
              ),
              actions: [
                if (_inChatSearchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                    onPressed: () {
                      _inChatSearchController.clear();
                      setState(() => _inChatSearchQuery = '');
                    },
                  ),
              ],
            )
          : LajuGlassAppBar(
              titleSpacing: 0,
              title: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        contactName: widget.title,
                        isOnline: true,
                        isVerified: true,
                        safetyNumber: widget.safetyNumber,
                        avatarUrl: widget.avatarUrl,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ModernAvatar(
                      name: widget.title,
                      imagePath: widget.avatarUrl,
                      radius: 19,
                      isOnline: true,
                      isVerified: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ValueListenableBuilder<Map<String, bool>>(
                            valueListenable: ConversationService.instance.typingStatusNotifier,
                            builder: (context, typings, _) {
                              final isTyping = typings[widget.conversationId] == true;
                              if (isTyping) {
                                return const Text(
                                  'sedang mengetik...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF10B981),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                  icon: Icon(Icons.call_rounded, size: 21, color: isDark ? Colors.white : const Color(0xFF374151)),
                  onPressed: () => _startCall(false),
                  tooltip: 'Voice Call',
                ),
                IconButton(
                  icon: Icon(Icons.videocam_rounded, size: 23, color: isDark ? Colors.white : const Color(0xFF374151)),
                  onPressed: () => _startCall(true),
                  tooltip: 'Video Call',
                ),
                PopupMenuButton<String>(
                  color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
                  onSelected: (value) {
                    switch (value) {
                      case 'contact':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              contactName: widget.title,
                              isOnline: true,
                              isVerified: true,
                              safetyNumber: widget.safetyNumber,
                              avatarUrl: widget.avatarUrl,
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
                            builder: (context) => const DisappearingMessagesScreen(),
                          ),
                        );
                        break;
                      case 'verify':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KeyVerificationScreen(
                              contactName: widget.title,
                              safetyNumber: '19402 48190 28471 00293 84729 48190',
                            ),
                          ),
                        );
                        break;
                      case 'clear':
                        _confirmClearChat(context, isDark);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    _buildMenuItem('contact', Icons.person_outline_rounded, 'Lihat Kontak', isDark),
                    _buildMenuItem('media', Icons.perm_media_outlined, 'Media & Lampiran', isDark),
                    _buildMenuItem('search', Icons.search_rounded, 'Cari Pesan', isDark),
                    _buildMenuItem('wallpaper', Icons.wallpaper_rounded, 'Wallpaper Chat', isDark),
                    _buildMenuItem('disappearing', Icons.timer_outlined, 'Pesan Sementara', isDark),
                    _buildMenuItem('verify', Icons.verified_user_outlined, 'Kunci Keamanan', isDark),
                    const PopupMenuDivider(height: 1),
                    _buildMenuItem('clear', Icons.delete_sweep_outlined, 'Bersihkan Chat', isDark, isDestructive: true),
                  ],
                ),
              ],
            ),
      body: ListenableBuilder(
        listenable: ChatAppearanceController.instance,
        builder: (context, _) {
          final isDark = ThemeModeController.instance.isDarkMode(context);
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
              // Fixed Background Wallpaper Color fallback (unaffected by keyboard resize)
              Positioned(
                top: 0,
                left: 0,
                width: screenSize.width,
                height: screenSize.height,
                child: Container(
                  color: isDark ? const Color(0xFF071216) : activeWallpaper.backgroundColor,
                ),
              ),

              // Fixed Wallpaper Image asset (never jumps/rescales when keyboard appears)
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

              // Messages & Input Bar
              Column(
                children: [
                  // Message List
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
                                    const Icon(Icons.lock_rounded, size: 22, color: AppColors.primary),
                                    const SizedBox(height: 8),
                                    Text(
                                      'End-to-End Encrypted',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pesan dan obrolan diamankan dengan enkripsi end-to-end. Tidak ada pihak luar yang dapat membaca atau mendengarkannya.',
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
                              final displayedMsgs = _isSearching && _inChatSearchQuery.isNotEmpty
                                  ? _messages
                                      .where((m) => m.content
                                          .toLowerCase()
                                          .contains(_inChatSearchQuery.toLowerCase()))
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
                                          '"$_inChatSearchQuery"',
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
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                itemCount: displayedMsgs.length,
                                itemBuilder: (context, index) {
                                  final msg = displayedMsgs[index];
                                  final isFirstOrDiffDay = index == 0 ||
                                      !DateHelper.isSameDay(msg.timestamp, displayedMsgs[index - 1].timestamp);

                                  final bubble = ChatBubble(
                                    message: msg,
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

                  // Custom Input Bar matching design board (NO emoji keyboard button)
                  ChatInputBar(
                    onSend: _sendMessage,
                    onAttach: _openAttachmentMenu,
                    onSendVoiceNote: _handleSendVoiceNote,
                    replyingTo: _replyingTo,
                    onCancelReply: _cancelReply,
                    editingMessage: _editingMessage,
                    onCancelEdit: _cancelEdit,
                    onConfirmEdit: _confirmEditMessage,
                    onTypingChanged: (isTyping) {
                      ConversationService.instance.setTyping(widget.conversationId, isTyping);
                    },
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
  }
}
