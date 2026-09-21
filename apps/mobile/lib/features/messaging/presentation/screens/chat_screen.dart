import 'package:flutter/material.dart';
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
import '../../../../core/services/voice_note_service.dart';
import '../../../../core/services/local_database.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool isGroup;
  final String safetyNumber;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.isGroup = false,
    this.safetyNumber = '4812 ••• 9901',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  late List<MessageModel> _messages;
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;

  @override
  void initState() {
    super.initState();
    _messages = [];
    _loadMessagesFromApi();
  }

  void _loadMessagesFromApi() async {
    // Step 1: Load from SQLite cache instantly (offline-ready)
    final cached = await ConversationService.instance.getMessagesFromCache(widget.conversationId);
    if (mounted && cached.isNotEmpty) {
      setState(() {
        _messages = cached;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }

    // Step 2: Fetch fresh messages from API in background
    try {
      final apiMsgs = await ConversationService.instance.fetchMessages(widget.conversationId);
      if (mounted && apiMsgs.isNotEmpty) {
        setState(() {
          _messages = apiMsgs;
        });
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    } catch (_) {}
  }

  void _sendMessage(String text) async {
    LajuSoundService.playOutgoingTone();
    final localMsg = MessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
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

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });

    // Send to backend
    final sentMsg = await ConversationService.instance.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      clientMessageId: localMsg.id,
    );

    if (mounted && sentMsg != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localMsg.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            id: sentMsg.id,
            status: sentMsg.status,
          );
        }
      });
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
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index == -1) return;
      final existing = List<String>.from(_messages[index].reactions);
      if (existing.contains(emoji)) {
        existing.remove(emoji);
      } else {
        existing.add(emoji);
      }
      _messages[index] = _messages[index].copyWith(reactions: existing);
    });
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

  void _confirmEditMessage(String newText) {
    if (_editingMessage == null) return;
    final index = _messages.indexWhere((m) => m.id == _editingMessage!.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(
          content: newText,
          isEdited: true,
        );
        _editingMessage = null;
      });
      LajuToast.info(context, 'Pesan berhasil diperbarui (diedit)');
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

  void _openAttachmentMenu() async {
    final result = await AttachmentBottomSheet.show(context);
    if (result != null) {
      final filePath = result.data is String ? result.data as String : null;
      if (result.type == AttachmentType.document) {
        final docMsg = MessageModel(
          id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
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
        ConversationService.instance.sendMessage(
          conversationId: widget.conversationId,
          text: '📄 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: docMsg.id,
        );
        _scrollToBottom();
      } else if (result.type == AttachmentType.camera || result.type == AttachmentType.gallery) {
        final imgMsg = MessageModel(
          id: 'img-${DateTime.now().millisecondsSinceEpoch}',
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
        ConversationService.instance.sendMessage(
          conversationId: widget.conversationId,
          text: '📷 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: imgMsg.id,
        );
        _scrollToBottom();
      } else if (result.type == AttachmentType.audio) {
        final audMsg = MessageModel(
          id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
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
        ConversationService.instance.sendMessage(
          conversationId: widget.conversationId,
          text: '🎵 ${result.title} (${result.fileSize ?? ""})',
          clientMessageId: audMsg.id,
        );
        _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1015) : const Color(0xFFF3F4F6),
      appBar: LajuGlassAppBar(
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
                ),
              ),
            );
          },
          child: Row(
            children: [
              ModernAvatar(
                name: widget.title,
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
                    Row(
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
                          style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ],
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
              if (value == 'verify') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KeyVerificationScreen(
                      contactName: widget.title,
                      safetyNumber: '19402 48190 28471 00293 84729 48190',
                    ),
                  ),
                );
              } else if (value == 'disappearing') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DisappearingMessagesScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'verify',
                child: Text('Verify Security Key'),
              ),
              PopupMenuItem(
                value: 'disappearing',
                child: Text('Disappearing Messages'),
              ),
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

          return Stack(
            children: [
              // Background Wallpaper Color fallback
              Positioned.fill(
                child: Container(
                  color: isDark ? const Color(0xFF071216) : activeWallpaper.backgroundColor,
                ),
              ),

              // Wallpaper Image asset (Uploaded Official LAJU Doodle)
              if (assetPath != null)
                Positioned.fill(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
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
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return ChatBubble(
                                message: msg,
                                onReactionSelected: (emoji) => _handleReaction(msg, emoji),
                                onReply: _handleReply,
                                onEdit: _handleEditMessage,
                                onDelete: () {
                                  setState(() => _messages.removeAt(index));
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
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
