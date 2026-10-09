import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'chat_media_gallery_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final String? avatarUrl;

  const GroupChatScreen({
    super.key,
    this.groupId = 'grp-1',
    this.groupName,
    this.avatarUrl,
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
  StreamSubscription<MessageModel>? _rtMsgSub;
  StreamSubscription<Map<String, String>>? _rtDelSub;
  StreamSubscription<String>? _rtPurgedSub;
  StreamSubscription<String>? _rtGroupDeletedSub;
  bool _showScrollToBottom = false;

  DateTime? _lastClearedAt;

  bool _isSearching = false;
  final TextEditingController _inGroupSearchController = TextEditingController();
  String _inGroupSearchQuery = '';
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ChatWebSocketService.instance.connect();
    ConversationService.instance.currentActiveConversationId = widget.groupId;
    ConversationService.instance.markConversationAsRead(widget.groupId);
    final mem = ConversationService.instance.getMemoryMessages(widget.groupId);
    if (mem != null) {
      _messages = List<MessageModel>.from(mem);
    }
    _loadMessages();
    _startPolling();

    // Listen to 0ms instant real-time message stream from WebSocket
    _rtMsgSub = ConversationService.instance.realtimeMessageStream.listen((msg) {
      if (!mounted) return;
      final realId = ConversationService.instance.resolveConversationId(widget.groupId);
      if (msg.conversationId == widget.groupId || msg.conversationId == realId) {
        ConversationService.instance.markConversationAsRead(widget.groupId);
        _mergeAndSetMessages([msg]);
      }
    });

    _rtDelSub = ConversationService.instance.realtimeMessageDeletedStream.listen((event) {
      if (!mounted) return;
      final cId = event['conversationId'];
      final mId = event['messageId'];
      if (cId == widget.groupId && mId != null) {
        final idx = _messages.indexWhere((m) => m.id == mId);
        if (idx != -1) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              isDeleted: true,
              content: '__DELETED_FOR_EVERYONE__',
            );
          });
        }
      }
    });

    _rtPurgedSub = ConversationService.instance.realtimePurgedStream.listen((cId) {
      if (!mounted) return;
      if (cId == widget.groupId) {
        setState(() {
          _messages.clear();
        });
      }
    });

    _rtGroupDeletedSub = ConversationService.instance.realtimeGroupDeletedStream.listen((cId) {
      if (!mounted) return;
      if (cId == widget.groupId) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        LajuToast.info(context, 'Grup ini telah dihapus oleh pemilik');
      }
    });

    ChatWebSocketService.instance.isConnectedNotifier.addListener(_onWsConnectionChanged);

    GroupController.instance.fetchGroupFromBackend(widget.groupId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(immediate: true);
    });
  }

  void _onWsConnectionChanged() {
    if (mounted) {
      _startPolling();
    }
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
    _rtMsgSub?.cancel();
    _rtDelSub?.cancel();
    _rtPurgedSub?.cancel();
    _rtGroupDeletedSub?.cancel();
    ChatWebSocketService.instance.isConnectedNotifier.removeListener(_onWsConnectionChanged);

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
    ConversationService.instance.markConversationAsRead(widget.groupId);
    for (final m in msgs) {
      if (!m.isOutgoing && m.status != MessageDeliveryStatus.read) {
        ConversationService.instance.markMessageRead(m.id);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Fast 1000ms polling while group chat is open, ensuring no noticeable delay
    const interval = 1000;
    _pollTimer = Timer.periodic(const Duration(milliseconds: interval), (_) async {
      _syncMessages();
    });
  }

  Future<void> _syncMessages() async {
    if (!mounted) return;
    try {
      final msgs = await ConversationService.instance.fetchMessages(widget.groupId);
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final clearedStr = prefs.getString('laju_chat_cleared_at_${widget.groupId}');
      if (clearedStr != null) {
        _lastClearedAt = DateTime.tryParse(clearedStr);
      }

      if (msgs.isEmpty) {
        if (_messages.isNotEmpty && (_lastClearedAt != null || msgs.isEmpty)) {
          setState(() {
            _messages.clear();
          });
          ConversationService.instance.updateMemoryMessages(widget.groupId, []);
        }
      } else {
        _mergeAndSetMessages(msgs);
      }
    } catch (_) {}
  }

  void _mergeAndSetMessages(List<MessageModel> incoming) {
    if (!mounted) return;
    if (incoming.isEmpty) {
      if (_messages.isNotEmpty) {
        setState(() {
          _messages.clear();
        });
      }
      return;
    }

    // Filter current base messages to exclude anything timestamped before the most recent clear/purge
    List<MessageModel> currentBase = _messages;
    if (_lastClearedAt != null) {
      currentBase = _messages.where((m) => m.timestamp.isAfter(_lastClearedAt!)).toList();
    }

    final existingIds = currentBase.map((m) => m.id).toSet();
    bool hasNewIncoming = false;
    for (final inc in incoming) {
      if (!inc.isOutgoing && !existingIds.contains(inc.id)) {
        hasNewIncoming = true;
        break;
      }
    }

    // Check for recalled status updates in incoming messages
    bool hasRecalledUpdate = false;
    for (final inc in incoming) {
      if (inc.isRecalled) {
        final existingIdx = _messages.indexWhere((m) =>
            m.id == inc.id ||
            (m.clientMessageId != null &&
                inc.clientMessageId != null &&
                m.clientMessageId == inc.clientMessageId));
        if (existingIdx != -1 && !_messages[existingIdx].isRecalled) {
          hasRecalledUpdate = true;
          break;
        }
      }
    }

    final combined = List<MessageModel>.from(currentBase)..addAll(incoming);
    final merged = MessageModel.deduplicate(combined);

    bool hasChanged = hasRecalledUpdate || (merged.length != _messages.length);
    if (!hasChanged) {
      for (int i = 0; i < merged.length; i++) {
        if (merged[i].id != _messages[i].id ||
            merged[i].status != _messages[i].status ||
            !listEquals(merged[i].reactions, _messages[i].reactions) ||
            merged[i].content != _messages[i].content ||
            merged[i].isDeleted != _messages[i].isDeleted ||
            merged[i].isRecalled != _messages[i].isRecalled) {
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

    if (mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == localId || m.clientMessageId == localId);
        if (idx != -1) {
          if (sent != null) {
            _messages[idx] = sent;
          } else {
            _messages[idx] = localMsg.copyWith(status: MessageDeliveryStatus.sent);
          }
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
        final contact = result.data is LajuContactData ? result.data as LajuContactData : null;
        if (contact != null) {
          final conId = 'con-${DateTime.now().millisecondsSinceEpoch}';
          final conJson = jsonEncode(contact.toJson());
          final conMsg = MessageModel(
            id: conId,
            clientMessageId: conId,
            conversationId: widget.groupId,
            senderName: 'You',
            content: conJson,
            attachmentName: contact.name,
            attachmentSize: contact.username,
            timestamp: DateTime.now(),
            isOutgoing: true,
            contentType: MessageContentType.contact,
            status: MessageDeliveryStatus.sending,
          );
          setState(() {
            _messages.add(conMsg);
          });
          await LocalDatabase.instance.insertSentMessage(conMsg);
          _scrollToBottom(immediate: false);

          final sent = await ConversationService.instance.sendMessage(
            conversationId: widget.groupId,
            text: conJson,
            clientMessageId: conId,
            messageType: 'CONTACT',
            attachmentName: contact.name,
            attachmentSize: contact.username,
          );
          if (mounted && sent != null) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == conId || m.clientMessageId == conId);
              if (idx != -1) {
                _messages[idx] = sent;
              }
            });
            _syncMessages();
          }
        } else {
          _sendMessage(result.title);
        }
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
      attachmentPath: sticker.effectivePathOrUrl,
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
      attachmentPath: sticker.effectivePathOrUrl,
      attachmentName: sticker.id,
      replyTo: replyToCopy,
    );

    if (mounted && sent != null) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == stkId || m.clientMessageId == stkId);
        if (idx != -1) {
          _messages[idx] = sent.copyWith(attachmentPath: sticker.effectivePathOrUrl);
        }
      });
      _syncMessages();
    }
  }


  void _confirmClearChat(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            context.tr('clearGroupChatConfirmTitle'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            context.tr('clearGroupChatConfirmDesc'),
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                context.tr('cancel'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                setState(() {
                  _messages.clear();
                });
                await ConversationService.instance.clearChatForMe(widget.groupId);
                if (context.mounted) {
                  LajuToast.info(context, context.tr('clearGroupChatSuccess'));
                }
              },
              child: Text(context.tr('clearGroupChatForMe'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (GroupController.instance.isCurrentUserAdmin(widget.groupId))
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  setState(() {
                    _messages.clear();
                  });
                  await ConversationService.instance.clearChatForAll(widget.groupId);
                  if (context.mounted) {
                    LajuToast.info(context, context.tr('clearGroupChatSuccess'));
                  }
                },
                child: Text(context.tr('clearGroupChatForAll'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        );

      },
    );
  }

  void _confirmDestructiveWipe(BuildContext context, bool isDark) {
    final pinController = TextEditingController();
    bool obscurePin = true;
    bool isWiping = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hancurkan Chat Grup?',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERINGATAN: Tindakan ini akan menghapus SEMUA riwayat obrolan grup ini secara permanen dari server dan semua perangkat anggota. Pesan tidak dapat dipulihkan.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Masukkan PIN Darurat untuk melanjutkan:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePin,
                    maxLength: 6,
                    autofocus: true,
                    enabled: !isWiping,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'PIN (4-6 Digit)',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        letterSpacing: 0,
                      ),
                      prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.danger),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() => obscurePin = !obscurePin);
                        },
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isWiping ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    context.tr('cancel'),
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
                  onPressed: isWiping
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          if (pin.length < 4 || pin.length > 6) {
                            LajuToast.error(context, context.tr('enterValidPin'));
                            return;
                          }

                          setDialogState(() => isWiping = true);

                          try {
                            await ConversationService.instance.destructiveWipeGroup(widget.groupId, pin);
                            if (mounted) {
                              setState(() {
                                _messages.clear();
                              });
                            }
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              LajuToast.success(context, 'Riwayat obrolan grup berhasil dihancurkan untuk semua orang');
                            }
                          } catch (e) {
                            setDialogState(() => isWiping = false);
                            final msg = e.toString().replaceAll('Exception: ', '');
                            if (context.mounted) {
                              LajuToast.error(context, msg);
                            }
                          }
                        },
                  child: isWiping
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Hancurkan Semua',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, bool isDark) {
    final pinController = TextEditingController();
    bool obscurePin = true;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('deleteGroupConfirmTitle'),
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('deleteGroupConfirmDesc'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('deleteGroupPinPrompt'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePin,
                    maxLength: 6,
                    autofocus: true,
                    enabled: !isDeleting,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        letterSpacing: 4,
                      ),
                      prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.danger),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePin ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() => obscurePin = !obscurePin);
                        },
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    context.tr('cancel'),
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
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          if (pin.length < 4 || pin.length > 6) {
                            LajuToast.error(context, context.tr('enterValidPin'));
                            return;
                          }

                          setDialogState(() => isDeleting = true);

                          try {
                            await ConversationService.instance.deleteGroup(widget.groupId, pin);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              LajuToast.success(context, context.tr('deleteGroupSuccess'));
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            final msg = e.toString().replaceAll('Exception: ', '');
                            if (context.mounted) {
                              LajuToast.error(context, msg);
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                  : Text(
                      context.tr('deleteGroup'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ),
              ],
            );
          },
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
            context.tr('exitGroupConfirmTitle'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            context.tr('exitGroupConfirmDesc'),
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFEF4444),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                context.tr('cancel'),
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
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await ConversationService.instance.leaveGroup(widget.groupId);
                if (context.mounted) {
                  Navigator.pop(context);
                  LajuToast.info(context, context.tr('leftGroupSuccess'));
                }
              },
              child: Text(
                context.tr('exitGroup'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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

    return AnimatedBuilder(
      animation: Listenable.merge([
        GroupController.instance,
        GroupController.instance.groupMembershipNotifier,
      ]),
      builder: (context, _) {
        final group = GroupController.instance.getGroup(widget.groupId);
        final displayName = (group?.name != null && group!.name.isNotEmpty)
            ? group.name
            : ((widget.groupName != null && widget.groupName!.isNotEmpty)
                ? widget.groupName!
                : context.tr('groupChat'));
        final memberCount = GroupController.instance.getMemberCount(widget.groupId) ?? (group?.members.length ?? 0);
        final isUserAdmin = GroupController.instance.isCurrentUserAdmin(widget.groupId);
        final isMember = GroupController.instance.groupMembershipNotifier.value[widget.groupId] ?? true;
        final canSend = (group == null || group.canSendMessages || isUserAdmin) && isMember;

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
                      final effectiveAvatar = (group?.avatarPath != null && group!.avatarPath!.isNotEmpty)
                          ? group!.avatarPath
                          : widget.avatarUrl;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupProfileScreen(
                            groupId: widget.groupId,
                            groupName: displayName,
                            groupDescription: group?.description ?? '',
                            avatarUrl: effectiveAvatar,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        ModernAvatar(
                          name: displayName,
                          imagePath: (group?.avatarPath != null && group!.avatarPath!.isNotEmpty)
                              ? group!.avatarPath
                              : widget.avatarUrl,
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
                              ListenableBuilder(
                                listenable: Listenable.merge([
                                  ConversationService.instance.typingStatusNotifier,
                                  ConversationService.instance.typingUserNamesNotifier,
                                ]),
                                builder: (context, _) {
                                  final realId = ConversationService.instance.resolveConversationId(widget.groupId);
                                  final isTyping = ConversationService.instance.typingStatusNotifier.value[widget.groupId] == true ||
                                      ConversationService.instance.typingStatusNotifier.value[realId] == true;
                                  final typingNames = ConversationService.instance.typingUserNamesNotifier.value[widget.groupId] ??
                                      ConversationService.instance.typingUserNamesNotifier.value[realId];
                                  if (isTyping) {
                                    final typingLabel = (typingNames != null && typingNames.isNotEmpty)
                                        ? '$typingNames sedang mengetik...'
                                        : 'sedang mengetik...';
                                    return Text(
                                      typingLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  }
                                  return Text(
                                    memberCount > 0
                                        ? '$memberCount ${context.tr('members')}'
                                        : context.tr('groupChat'),
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
                        final curUserId = ApiClient.instance.userId;
                        final otherMembers = group?.members
                                .where((m) => m.id != 'm-you' && (curUserId == null || m.id != curUserId))
                                .toList() ??
                            [];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveGroupCallScreen(
                              groupName: displayName,
                              initialParticipants: otherMembers.map((m) => m.name).toList(),
                              initialParticipantIds: otherMembers.map((m) => m.id).toList(),
                              isVideo: false,
                              conversationId: widget.groupId,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.videocam_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                      onPressed: () {
                        final curUserId = ApiClient.instance.userId;
                        final otherMembers = group?.members
                                .where((m) => m.id != 'm-you' && (curUserId == null || m.id != curUserId))
                                .toList() ??
                            [];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveGroupCallScreen(
                              groupName: displayName,
                              initialParticipants: otherMembers.map((m) => m.name).toList(),
                              initialParticipantIds: otherMembers.map((m) => m.id).toList(),
                              isVideo: true,
                              conversationId: widget.groupId,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                      icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
                      onSelected: (value) async {
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatMediaGalleryScreen(
                                  chatTitle: displayName,
                                  conversationId: widget.groupId,
                                  messages: _messages,
                                ),
                              ),
                            );
                            break;
                          case 'search':
                            setState(() => _isSearching = true);
                            break;
                          case 'wallpaper':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WallpaperSettingsScreen(
                                  chatId: widget.groupId,
                                  chatTitle: widget.groupName ?? 'Grup',
                                ),
                              ),
                            );
                            break;
                          case 'disappearing':
                            final res = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DisappearingMessagesScreen(initialTimer: 'Off'),
                              ),
                            );
                            if (res != null && mounted) {
                              int? seconds;
                              if (res == '24 hours') seconds = 86400;
                              else if (res == '7 days') seconds = 604800;
                              else if (res == '90 days') seconds = 7776000;
                              await ConversationService.instance.updateConversationDisappearingTimer(widget.groupId, seconds);
                            }
                            break;
                          case 'destructive_wipe':
                            _confirmDestructiveWipe(context, isDark);
                            break;
                          case 'delete_group':
                            _confirmDeleteGroup(context, isDark);
                            break;
                          case 'clear':
                            _confirmClearChat(context, isDark);
                            break;
                          case 'leave':
                            _confirmLeaveGroup(context, isDark);
                            break;
                        }
                      },

                      itemBuilder: (context) {
                        final currentGroup = GroupController.instance.getGroup(widget.groupId);
                        final curUserId = ApiClient.instance.userId;
                        final showDestructiveOption = currentGroup == null ||
                            (currentGroup.hasKillPin && currentGroup.canUserWipe(curUserId));

                        return [
                          _buildMenuItem('info', Icons.info_outline_rounded, context.tr('groupInfo'), isDark),
                          _buildMenuItem('media', Icons.perm_media_outlined, context.tr('mediaAndDocs'), isDark),
                          _buildMenuItem('search', Icons.search_rounded, context.tr('searchMessages'), isDark),
                          _buildMenuItem('wallpaper', Icons.wallpaper_rounded, context.tr('chatWallpaper'), isDark),
                          _buildMenuItem('disappearing', Icons.timer_outlined, context.tr('disappearingMessages'), isDark),
                          const PopupMenuDivider(height: 1),
                          if (showDestructiveOption) ...[
                            _buildMenuItem(
                              'destructive_wipe',
                              Icons.warning_amber_rounded,
                              context.tr('destructiveWipeGroup'),
                              isDark,
                              isDestructive: true,
                            ),
                            const PopupMenuDivider(height: 1),
                          ],
                          _buildMenuItem('clear', Icons.delete_sweep_outlined, context.tr('clearGroupChat'), isDark),
                          if (currentGroup?.isCurrentUserOwner == true) ...[
                            _buildMenuItem(
                              'delete_group',
                              Icons.delete_forever_rounded,
                              context.tr('deleteGroup'),
                              isDark,
                              isDestructive: true,
                            ),
                          ],
                          _buildMenuItem('leave', Icons.exit_to_app_rounded, context.tr('exitGroup'), isDark, isDestructive: true),
                        ];
                      },


                    ),
                  ],
                ),
          body: ListenableBuilder(
            listenable: ChatAppearanceController.instance,
            builder: (context, _) {
              final isDark = ThemeModeController.instance.isDarkMode(context);
              final groupWallpaperId = ChatAppearanceController.instance.getChatWallpaper(widget.groupId) ??
                  ChatAppearanceController.instance.selectedWallpaper;
              final activeWallpaper = ChatAppearanceController.instance.findWallpaper(groupWallpaperId);
              final screenSize = MediaQuery.sizeOf(context);

              // Clean neutral default background canvas when no wallpaper is selected
              final defaultCanvasColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    width: screenSize.width,
                    height: screenSize.height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeWallpaper != null ? activeWallpaper.backgroundColor : defaultCanvasColor,
                        gradient: activeWallpaper != null && activeWallpaper.category == 'GRADIENT'
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  activeWallpaper.backgroundColor,
                                  activeWallpaper.backgroundColor.withValues(alpha: 0.75),
                                  const Color(0xFF0F172A),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (activeWallpaper != null && activeWallpaper.hasRemoteImage)
                    Positioned(
                      top: 0,
                      left: 0,
                      width: screenSize.width,
                      height: screenSize.height,
                      child: LajuCachedImage(
                        imageUrlOrPath: activeWallpaper.remoteImageUrl,
                        width: screenSize.width,
                        height: screenSize.height,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        placeholder: const SizedBox(),
                        errorWidget: const SizedBox(),
                        fadeDuration: const Duration(milliseconds: 250),
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
                                onRecall: () async {
                                  final msgToRecall = displayedMsgs[index];
                                  final ok = await ConversationService.instance.recallMessage(
                                    msgToRecall.id,
                                    widget.groupId,
                                  );
                                  if (ok && mounted) {
                                    setState(() {
                                      final idx = _messages.indexWhere((m) => m.id == msgToRecall.id);
                                      if (idx != -1) {
                                        _messages[idx] = _messages[idx].copyWith(
                                          content: '__DELETED_FOR_EVERYONE__',
                                          isDeleted: true,
                                        );
                                      }
                                    });
                                    LajuToast.success(context, 'Pesan berhasil ditarik');
                                  }
                                },
                                onDelete: () async {
                                  final msgToDelete = displayedMsgs[index];
                                  setState(() => _messages.removeWhere((m) => m.id == msgToDelete.id));
                                  await ConversationService.instance.deleteMessageForMe(
                                    msgToDelete.id,
                                    widget.groupId,
                                  );
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
              if (!isMember)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Anda bukan lagi anggota grup ini',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else if (canSend)
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
