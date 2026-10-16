import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';
import '../domain/models/conversation_model.dart';
import 'group_controller.dart';
import '../../messaging/domain/models/message_model.dart';
import '../../messaging/presentation/screens/chat_screen.dart';
import '../../settings/domain/privacy_controller.dart';
import '../../settings/domain/data_storage_controller.dart';

class UserDirectoryItem {
  final String id;
  final String username;
  final String? email;
  final String? phoneNumber;
  final String? status;
  final String? avatarUrl;

  const UserDirectoryItem({
    required this.id,
    required this.username,
    this.email,
    this.phoneNumber,
    this.status,
    this.avatarUrl,
  });

  factory UserDirectoryItem.fromJson(Map<String, dynamic> json) {
    return UserDirectoryItem(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      status: json['status'],
      avatarUrl: json['avatarUrl'] ?? json['avatar'],
    );
  }
}

class ConversationService {
  ConversationService._() {
    initWebSocket();
  }
  static final ConversationService instance = ConversationService._();

  final Set<String> _seenMessageIds = {};

  /// Realtime stream of newly arrived messages
  final StreamController<MessageModel> _realtimeMessageStreamController =
      StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get realtimeMessageStream => _realtimeMessageStreamController.stream;

  /// Realtime stream of recalled/deleted message IDs
  final StreamController<Map<String, String>> _realtimeMessageDeletedController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get realtimeMessageDeletedStream =>
      _realtimeMessageDeletedController.stream;

  /// Realtime stream of purged/cleared conversation IDs
  final StreamController<String> _realtimePurgedController =
      StreamController<String>.broadcast();
  Stream<String> get realtimePurgedStream => _realtimePurgedController.stream;

  /// Realtime stream of deleted group conversation IDs
  final StreamController<String> _realtimeGroupDeletedController =
      StreamController<String>.broadcast();
  Stream<String> get realtimeGroupDeletedStream => _realtimeGroupDeletedController.stream;


  bool _isWsInitialized = false;

  void initWebSocket() {
    if (_isWsInitialized) return;
    _isWsInitialized = true;

    final ws = ChatWebSocketService.instance;
    ws.connect();

    ws.onNewMessage = (msgData) {
      final convId = (msgData['conversationId'] ?? '') as String;
      if (convId.isEmpty) return;
      final parsed = parseMessageFromJson(msgData, convId);
      _handleRealtimeNewMessage(convId, parsed);
    };

    ws.onMessageDeleted = (convId, msgId) {
      _handleRealtimeMessageDeleted(convId, msgId);
    };

    ws.onTyping = (convId, userId, username, isTyping) {
      if (userId != ApiClient.instance.userId) {
        setTypingDetails(convId, isTyping, username != null ? [username] : null);
      }
    };

    ws.onConversationPurged = (convId) {
      clearChatForMe(convId);
      _realtimePurgedController.add(convId);
    };

    ws.onGroupDeleted = (convId) {
      _inMemoryMessages.remove(convId);
      LocalDatabase.instance.deleteConversation(convId);
      _realtimeGroupDeletedController.add(convId);
      fetchConversations();
    };



    ws.onMessageReaction = (convId, msgId, userId, emoji, action) {
      _handleRealtimeMessageReaction(convId, msgId, userId, emoji, action);
    };
  }

  void _handleRealtimeNewMessage(String conversationId, MessageModel msg) {
    _seenMessageIds.add(msg.id);

    final current = _inMemoryMessages[conversationId] ?? [];
    final existingIdx = current.indexWhere((m) =>
        m.id == msg.id ||
        (m.clientMessageId != null &&
            msg.clientMessageId != null &&
            m.clientMessageId == msg.clientMessageId));
    final isNewMessage = existingIdx == -1;
    if (!isNewMessage) {
      current[existingIdx] = msg;
    } else {
      current.add(msg);
    }
    _inMemoryMessages[conversationId] = current;

    LocalDatabase.instance.upsertMessages(conversationId, [msg]).catchError((_) {});
    _realtimeMessageStreamController.add(msg);

    if (inMemoryConversations != null) {
      final realId = resolveConversationId(conversationId);
      final idx = inMemoryConversations!.indexWhere((c) => c.id == conversationId || c.id == realId);
      if (idx != -1) {
        final conv = inMemoryConversations![idx];
        final isCurOpen = isConversationOpen(conv.id) || isConversationOpen(conversationId);
        int newUnread;
        if (isCurOpen || msg.isOutgoing) {
          newUnread = 0;
        } else if (isNewMessage) {
          newUnread = conv.unreadCount + 1;
        } else {
          newUnread = conv.unreadCount;
        }
        final updated = conv.copyWith(
          lastMessage: msg.displaySnippet,
          lastMessageTime: msg.timestamp,
          unreadCount: newUnread,
        );
        inMemoryConversations![idx] = updated;
        conversationsNotifier.value = List.from(inMemoryConversations!);
        LocalDatabase.instance.upsertConversations([updated]).catchError((_) {});
      }
    }
  }

  void _handleRealtimeMessageDeleted(String conversationId, String messageId) {
    final current = _inMemoryMessages[conversationId];
    if (current != null) {
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final old = current[idx];
        final updated = old.copyWith(
          isDeleted: true,
          content: '__DELETED_FOR_EVERYONE__',
          attachmentPath: null,
          attachmentName: null,
          attachmentSize: null,
        );
        current[idx] = updated;
        _inMemoryMessages[conversationId] = current;
        LocalDatabase.instance.upsertMessages(conversationId, [updated]).catchError((_) {});
      }
    }
    _realtimeMessageDeletedController.add({'conversationId': conversationId, 'messageId': messageId});
  }

  void _handleRealtimeMessageReaction(
    String conversationId,
    String messageId,
    String userId,
    String emoji,
    String action,
  ) {
    void updateForConv(String cid) {
      final current = _inMemoryMessages[cid];
      if (current != null) {
        final idx = current.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final msg = current[idx];
          final reactions = List<String>.from(msg.reactions);
          if (action == 'ADD') {
            if (!reactions.contains(emoji)) {
              reactions.add(emoji);
            }
          } else if (action == 'REMOVE') {
            reactions.remove(emoji);
          }
          final updated = msg.copyWith(reactions: reactions);
          current[idx] = updated;
          _inMemoryMessages[cid] = current;
          _realtimeMessageStreamController.add(updated);
          LocalDatabase.instance.upsertMessages(cid, [updated]).catchError((_) {});
        }
      }
    }

    updateForConv(conversationId);
    final mapped = _tempToRealConvMap[conversationId];
    if (mapped != null && mapped != conversationId) {
      updateForConv(mapped);
    }
  }

  /// Current conversation screen open by user to prevent banner popup for active chat
  String? currentActiveConversationId;

  /// Check whether a conversation is currently open and visible on screen
  bool isConversationOpen(String conversationId) {
    if (currentActiveConversationId == null || currentActiveConversationId!.isEmpty) {
      return false;
    }
    if (currentActiveConversationId == conversationId) return true;
    final resolvedOpen = resolveConversationId(currentActiveConversationId!);
    final resolvedTarget = resolveConversationId(conversationId);
    return resolvedOpen == resolvedTarget ||
        resolvedOpen == conversationId ||
        currentActiveConversationId == resolvedTarget;
  }

  /// Mark all messages in a conversation as read: resets unread count to 0 locally & in cache
  Future<void> markConversationAsRead(String conversationId) async {
    if (conversationId.isEmpty) return;
    final realId = resolveConversationId(conversationId);

    final allIds = <String>{conversationId, realId};
    _tempToRealConvMap.forEach((tempId, rId) {
      if (rId == conversationId || rId == realId) {
        allIds.add(tempId);
      }
      if (tempId == conversationId || tempId == realId) {
        allIds.add(rId);
      }
    });

    // 1. Reset in-memory conversation list immediately
    final list = List<ConversationModel>.from(inMemoryConversations ?? conversationsNotifier.value);
    bool changed = false;
    for (int i = 0; i < list.length; i++) {
      final c = list[i];
      final isMatch = allIds.contains(c.id) ||
          (c.participantUserId != null &&
              (allIds.contains(c.participantUserId) || allIds.contains('conv-${c.participantUserId}')));
      if (isMatch) {
        allIds.add(c.id);
        if (c.participantUserId != null) {
          allIds.add(c.participantUserId!);
          allIds.add('conv-${c.participantUserId}');
        }
        if (c.unreadCount > 0) {
          list[i] = c.copyWith(unreadCount: 0);
          changed = true;
        }
      }
    }

    if (changed || inMemoryConversations == null) {
      inMemoryConversations = list;
      conversationsNotifier.value = List.unmodifiable(list);
    }

    // 2. Persist unread_count = 0 atomically in SQLite local database for all aliases
    await LocalDatabase.instance.resetUnreadCount(allIds);
  }

  bool _isInitialSyncComplete = false;
  final Map<String, String> _tempToRealConvMap = {};
  String resolveConversationId(String id) => _tempToRealConvMap[id] ?? id;

  /// Detects MIME type from file extension
  static String detectMimeType(String path, {String? fileName}) {
    final target = (fileName != null && fileName.isNotEmpty) ? fileName : path;
    final ext = target.contains('.') ? target.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/m4a';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'mp4':
        return 'video/mp4';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Checks whether a filename or path represents an image
  static bool isImageFile(String pathOrName) {
    if (pathOrName.isEmpty) return false;
    final clean = pathOrName.split('?').first.split('#').first;
    final ext = clean.contains('.') ? clean.split('.').last.toLowerCase() : '';
    return ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png' ||
        ext == 'webp' ||
        ext == 'gif' ||
        ext == 'heic' ||
        ext == 'heif' ||
        ext == 'bmp';
  }

  /// In-memory cache for TanStack Query-style instantaneous hydration
  List<ConversationModel>? inMemoryConversations;
  final ValueNotifier<List<ConversationModel>> conversationsNotifier = ValueNotifier<List<ConversationModel>>([]);
  List<ConversationModel> get conversations =>
      conversationsNotifier.value.isNotEmpty ? conversationsNotifier.value : (inMemoryConversations ?? []);
  final Map<String, List<MessageModel>> _inMemoryMessages = {};

  List<MessageModel>? getMemoryMessages(String conversationId) {
    final list = _inMemoryMessages[conversationId];
    if (list != null && list.isNotEmpty) {
      return List<MessageModel>.unmodifiable(list);
    }
    return null;
  }

  void updateMemoryMessages(String conversationId, List<MessageModel> messages) {
    if (messages.isNotEmpty) {
      _inMemoryMessages[conversationId] = List<MessageModel>.from(messages);
    } else {
      _inMemoryMessages[conversationId] = [];
    }
  }

  /// Active typing indicators per conversation ID (true if remote participant is typing)
  final ValueNotifier<Map<String, bool>> typingStatusNotifier = ValueNotifier({});

  /// Active typing user names per conversation ID (e.g. 'Alice')
  final ValueNotifier<Map<String, String?>> typingUserNamesNotifier = ValueNotifier({});

  /// Real-time peer online status per conversation ID
  final ValueNotifier<Map<String, bool>> peerOnlineStatusNotifier = ValueNotifier({});

  /// Update remote typing indicator state (received from backend sync)
  void setTyping(String conversationId, bool isTyping) {
    setTypingDetails(conversationId, isTyping, null);
  }

  /// Update remote typing indicator state with user names
  void setTypingDetails(String conversationId, bool isTyping, [List<String>? typingUsers]) {
    final currentStatus = Map<String, bool>.from(typingStatusNotifier.value);
    final currentNames = Map<String, String?>.from(typingUserNamesNotifier.value);

    final idsToUpdate = <String>{conversationId};
    final resolved = resolveConversationId(conversationId);
    idsToUpdate.add(resolved);
    _tempToRealConvMap.forEach((tempId, realId) {
      if (realId == conversationId || realId == resolved) {
        idsToUpdate.add(tempId);
      }
    });

    for (final cid in idsToUpdate) {
      if (isTyping) {
        currentStatus[cid] = true;
        if (typingUsers != null && typingUsers.isNotEmpty) {
          currentNames[cid] = typingUsers.join(', ');
        } else {
          currentNames[cid] = null;
        }
      } else {
        currentStatus.remove(cid);
        currentNames.remove(cid);
      }
    }
    typingStatusNotifier.value = currentStatus;
    typingUserNamesNotifier.value = currentNames;
  }

  /// Update peer online status for a conversation
  void setPeerOnline(String conversationId, bool isOnline) {
    final current = Map<String, bool>.from(peerOnlineStatusNotifier.value);
    if (current[conversationId] != isOnline) {
      current[conversationId] = isOnline;
      peerOnlineStatusNotifier.value = current;
    }
  }

  /// Inform backend of current user's typing activity so the other party sees it
  Future<void> sendTypingStatus(String conversationId, bool isTyping) async {
    final effectiveConvId = resolveConversationId(conversationId);
    // Instant WebSocket typing broadcast (0ms delay)
    ChatWebSocketService.instance.sendTyping(effectiveConvId, isTyping);
    try {
      await ApiClient.instance.post(
        ApiEndpoints.conversationTyping(effectiveConvId),
        body: {'isTyping': isTyping},
      );
    } catch (_) {
      // Ignored non-critical broadcast
    }
  }

  /// Search users in the backend directory for new chats or group members
  Future<List<UserDirectoryItem>> searchUsers(String query) async {
    final cleanQ = query.trim();
    // Zero-Knowledge Privacy Policy: Do not query public directory with empty or short string
    if (cleanQ.isEmpty || cleanQ.length < 3) {
      return [];
    }
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.users,
        queryParams: {'q': cleanQ},
      );

      if (response.isSuccess && response.rawJson is Map) {
        final usersList = response.rawJson['users'];
        if (usersList is List) {
          return usersList
              .map((u) => UserDirectoryItem.fromJson(u as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] searchUsers error: $e');
    }
    return [];
  }

  /// Fetch user profile by ID or username from backend API
  Future<Map<String, dynamic>?> fetchUserProfile(String userIdOrUsername) async {
    if (userIdOrUsername.trim().isEmpty) return null;
    try {
      final response = await ApiClient.instance.get('${ApiEndpoints.users}/${userIdOrUsername.trim()}');
      if (response.isSuccess && response.rawJson is Map) {
        return Map<String, dynamic>.from(response.rawJson as Map);
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchUserProfile error: $e');
    }
    return null;
  }

  /// Toggles mute status for a conversation and persists to SQLite and memory cache
  Future<void> toggleMute(String conversationId, bool isMuted) async {
    if (inMemoryConversations != null) {
      final idx = inMemoryConversations!.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        final updated = inMemoryConversations![idx].copyWith(isMuted: isMuted);
        inMemoryConversations![idx] = updated;
        await LocalDatabase.instance.upsertConversations([updated]);
      }
    }
  }

  /// Updates local state of a conversation (pin, lock, archive, mute, read) and persists to SQLite and memory
  Future<void> updateConversationLocally(ConversationModel updated) async {
    if (inMemoryConversations != null) {
      final idx = inMemoryConversations!.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        inMemoryConversations![idx] = updated;
      } else {
        inMemoryConversations!.add(updated);
      }
    } else {
      inMemoryConversations = [updated];
    }
    await LocalDatabase.instance.upsertConversations([updated]);
    conversationsNotifier.value = List.from(inMemoryConversations!);
  }

  /// Blocks a user locally and adds to blocked list
  Future<void> blockUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blocked = prefs.getStringList('blocked_user_ids') ?? [];
      if (!blocked.contains(userId)) {
        blocked.add(userId);
        await prefs.setStringList('blocked_user_ids', blocked);
      }
    } catch (e) {
      debugPrint('[ConversationService] blockUser error: $e');
    }
  }

  /// Checks if a user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blocked = prefs.getStringList('blocked_user_ids') ?? [];
      return blocked.contains(userId);
    } catch (_) {
      return false;
    }
  }

  /// Return conversations from local SQLite cache (offline-safe, instant).
  Future<List<ConversationModel>> getConversationsFromCache() async {
    final cached = await LocalDatabase.instance.getConversations();
    if (cached.isNotEmpty) {
      inMemoryConversations = cached;
      conversationsNotifier.value = cached;
    }
    return cached;
  }

  /// Fetch conversations for the current authenticated user
  Future<List<ConversationModel>> fetchConversations() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.conversations);

      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final currentUserId = ApiClient.instance.userId;

        // Load existing conversations from SQLite and memory to preserve user settings:
        // isPinned, isLocked, isArchived, isMuted, unreadCount
        final cachedMap = <String, ConversationModel>{};
        final dbConvs = await LocalDatabase.instance.getConversations();
        for (final c in dbConvs) {
          cachedMap[c.id] = c;
        }
        if (inMemoryConversations != null && inMemoryConversations!.isNotEmpty) {
          for (final c in inMemoryConversations!) {
            cachedMap[c.id] = c;
          }
        }

        // Check for new incoming messages across conversations and trigger notifications
        for (final item in list) {
          final convId = item['id'] as String?;
          if (convId == null) continue;

          // Register alias mapping for instant 1-on-1 contact lookup
          final members = item['members'];
          if (members is List) {
            for (final m in members) {
              if (m is Map) {
                final uId = m['userId'] as String?;
                if (uId != null && uId != currentUserId) {
                  _tempToRealConvMap['conv-$uId'] = convId;
                  _tempToRealConvMap[uId] = convId;
                }
              }
            }
          }

          final serverPurgedAt = item['purgedAt'] as String?;
          if (serverPurgedAt != null) {
            final prefs = await SharedPreferences.getInstance();
            final localClearedStr = prefs.getString('laju_chat_cleared_at_$convId');
            final pDate = DateTime.tryParse(serverPurgedAt);
            final lDate = localClearedStr != null ? DateTime.tryParse(localClearedStr) : null;
            if (pDate != null && (lDate == null || pDate.isAfter(lDate))) {
              await LocalDatabase.instance.clearMessages(convId);
              _inMemoryMessages[convId] = [];
              await prefs.setString('laju_chat_cleared_at_$convId', serverPurgedAt);
            }
          }

          final msgs = item['messages'] as List?;
          if (msgs != null && msgs.isNotEmpty) {
            final latest = msgs[0];
            final rawMsg = (latest['ciphertext'] ?? '') as String;
            if (rawMsg.contains('"type":"wallpaper_change"') || rawMsg.contains('"wallpaper_change"')) {
              try {
                final parsed = jsonDecode(rawMsg);
                if (parsed is Map && parsed['type'] == 'wallpaper_change') {
                  final wpId = parsed['wallpaperId'] as String? ?? 'none';
                  ChatAppearanceController.instance.syncRemoteChatWallpaper(convId, wpId);
                }
              } catch (_) {}
            }

            final latestMsgId = latest['id'] as String?;
            final senderId = latest['senderUserId'] as String?;

            if (latestMsgId != null) {
              final isSeen = _seenMessageIds.contains(latestMsgId);
              _seenMessageIds.add(latestMsgId);

              // Update in-memory message cache & SQLite without falsely incrementing unreadCount on historical messages
              final parsedMsg = parseMessageFromJson(latest, convId);
              final current = _inMemoryMessages[convId] ?? [];
              final existingIdx = current.indexWhere((m) => m.id == parsedMsg.id);
              if (existingIdx != -1) {
                current[existingIdx] = parsedMsg;
              } else {
                current.add(parsedMsg);
              }
              _inMemoryMessages[convId] = current;
              LocalDatabase.instance.upsertMessages(convId, [parsedMsg]).catchError((_) {});

              final old = cachedMap[convId];
              final isOutgoing = senderId == currentUserId;
              final msgTimestamp = parsedMsg.timestamp;
              final isGenuinelyNew = !isSeen &&
                  _isInitialSyncComplete &&
                  old != null &&
                  msgTimestamp.isAfter(old.lastMessageTime) &&
                  !isOutgoing;

              if (isGenuinelyNew) {
                _handleRealtimeNewMessage(convId, parsedMsg);
              }

              if (senderId != null && senderId != currentUserId) {
                if (_isInitialSyncComplete && isGenuinelyNew) {
                  final msgType = latest['messageType'] as String?;
                  DataStorageController.instance.recordMessageReceived(
                    bytes: rawMsg.isNotEmpty ? rawMsg.length : 64,
                    isMedia: msgType == 'ATTACHMENT' || rawMsg.contains('"media"'),
                  );
                }

                // If initial sync is complete and user is not currently in this chat, trigger notification!
                final isConvMuted = cachedMap[convId]?.isMuted ?? false;
                if (_isInitialSyncComplete && isGenuinelyNew && !isConversationOpen(convId) && !isConvMuted) {
                  final isGroup = item['type'] == 'GROUP';
                  String notifTitle = item['title'] ?? '';
                  String? avatarUrl;
                  final members = item['members'];
                  if (members is List) {
                    final otherMember = members.firstWhere(
                      (m) => m is Map && m['userId'] != currentUserId,
                      orElse: () => null,
                    );
                    if (otherMember != null && otherMember['user'] is Map) {
                      if (notifTitle.isEmpty || !isGroup) {
                        notifTitle = otherMember['user']['username'] ?? notifTitle;
                      }
                      avatarUrl = otherMember['user']['avatarUrl'];
                    }
                  }
                  if (notifTitle.isEmpty) notifTitle = isGroup ? 'Group Chat' : 'Pesan Baru';

                  String preview = (latest['ciphertext'] ?? '') as String;
                  if (preview.startsWith('{') && (preview.contains('"media"') || preview.contains('"type"'))) {
                    try {
                      final parsed = jsonDecode(preview);
                      final msgType = parsed['type'] as String?;
                      final cap = (parsed['caption'] ?? '') as String;
                      if (msgType == 'wallpaper_change') {
                        final wpName = (parsed['wallpaperName'] ?? '') as String;
                        preview = wpName == 'Default Polos'
                            ? 'Menyetel wallpaper ke default'
                            : 'Mengubah wallpaper ke "$wpName"';
                      } else if (msgType == 'document') {
                        final fn = (parsed['fileName'] as String?) ?? 'Dokumen';
                        preview = cap.isNotEmpty ? cap : fn;
                      } else if (msgType == 'audio') {
                        preview = 'Pesan Suara';
                      } else if (cap.isNotEmpty) {
                        preview = cap;
                      } else {
                        preview = 'Foto';
                      }
                    } catch (_) {
                      preview = 'Lampiran';
                    }
                  } else if (preview.startsWith('data:image')) {
                    preview = 'Foto';
                  } else if (preview.startsWith('data:audio')) {
                    preview = 'Pesan Suara';
                  } else if (preview.startsWith('data:') || preview.startsWith('Berkas Dokumen')) {
                    preview = 'Berkas Dokumen';
                  }

                  AppNotificationService.instance.showIncomingMessage(
                    conversationId: convId,
                    senderName: notifTitle,
                    message: preview,
                    isGroup: isGroup,
                    avatarUrl: avatarUrl,
                    onOpenChat: () {
                      AppNavigation.navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: convId,
                            title: notifTitle,
                            isGroup: isGroup,
                            avatarUrl: avatarUrl,
                          ),
                        ),
                      );
                    },
                    onQuickReply: (replyText) {
                      sendMessage(
                        conversationId: convId,
                        text: replyText,
                      );
                    },
                  );
                }
              }
            }
          }
        }
        _isInitialSyncComplete = true;

        final conversations = list.map((item) {
          final isGroup = item['type'] == 'GROUP';
          String title = item['title'] ?? '';
          String? avatarUrl;
          String? participantUserId;
          String? participantPhone;
          String? participantAbout;
          int? participantTrustScore;

          final members = item['members'];
          if (members is List) {
            final otherMember = members.firstWhere(
              (m) => m is Map && m['userId'] != currentUserId,
              orElse: () => null,
            );
            if (otherMember != null) {
              participantUserId = otherMember['userId'] as String?;
              if (otherMember['user'] is Map) {
                final u = otherMember['user'];
                participantUserId ??= u['id'] as String?;
                participantPhone = u['phoneNumber'] as String?;
                participantAbout = u['about'] as String?;
                if (u['trustScore'] is num) {
                  participantTrustScore = (u['trustScore'] as num).toInt();
                }
                if (!isGroup) {
                  if (title.isEmpty) title = u['username'] ?? '';
                  avatarUrl = u['avatarUrl'] as String?;
                }
              }
            }
          }

          if (isGroup) {
            avatarUrl = item['avatarUrl'] as String? ??
                GroupController.instance.getGroup(item['id']?.toString() ?? '')?.avatarPath;
          }

          if (title.isEmpty) {
            title = isGroup ? 'Group Chat' : 'Direct Chat';
          }

          final firstMsgMap = (item['messages'] is List && (item['messages'] as List).isNotEmpty)
              ? item['messages'][0] as Map?
              : null;
          final isMsgRecalled = firstMsgMap != null &&
              (firstMsgMap['state'] == 'DELETED' || firstMsgMap['ciphertext'] == '__DELETED_FOR_EVERYONE__');

          final isOutgoingLatest = firstMsgMap != null && firstMsgMap['senderUserId'] == currentUserId;
          final recallText = isOutgoingLatest ? 'Anda menarik pesan ini' : 'Pesan ini telah ditarik';

          final lastMsgRaw = firstMsgMap != null
              ? (isMsgRecalled ? recallText : (firstMsgMap['ciphertext'] ?? 'Encrypted Message'))
              : (item['purgedAt'] != null ? 'Pesan telah dihancurkan' : 'No messages yet');
          String lastMsg = lastMsgRaw;
          if (!isMsgRecalled && lastMsg.startsWith('{') && (lastMsg.contains('"media"') || lastMsg.contains('"type"'))) {
            try {
              final parsed = jsonDecode(lastMsg);
              final msgType = parsed['type'] as String?;
              final cap = (parsed['caption'] ?? '') as String;
              if (msgType == 'call_log') {
                final isVideo = parsed['isVideo'] == true;
                final status = (parsed['status'] ?? 'COMPLETED') as String;
                final dur = (parsed['durationSeconds'] as num?)?.toInt() ?? 0;
                final durStr = dur > 0 ? ' (${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')})' : '';
                if (status == 'MISSED') {
                  lastMsg = isVideo ? '📹 Panggilan video tak terjawab' : '📞 Panggilan tak terjawab';
                } else if (status == 'REJECTED') {
                  lastMsg = '❌ Panggilan ditolak';
                } else {
                  lastMsg = isVideo ? '📹 Panggilan video$durStr' : '📞 Panggilan suara$durStr';
                }
              } else if (msgType == 'wallpaper_change') {
                final wpName = (parsed['wallpaperName'] ?? '') as String;
                lastMsg = wpName == 'Default Polos'
                    ? 'Menyetel wallpaper ke default'
                    : 'Mengubah wallpaper ke "$wpName"';
              } else if (msgType == 'audio') {
                lastMsg = 'Pesan Suara';
              } else if (msgType == 'sticker') {
                lastMsg = 'Stiker';
              } else if (msgType == 'document') {
                final fn = (parsed['fileName'] as String?) ?? 'Dokumen';
                lastMsg = cap.isNotEmpty ? cap : fn;
              } else if (msgType == 'location') {
                lastMsg = 'Berbagi Lokasi';
              } else if (cap.isNotEmpty) {
                lastMsg = cap;
              } else {
                lastMsg = 'Foto';
              }
            } catch (_) {
              lastMsg = 'Foto';
            }
          } else if (lastMsg.startsWith('data:image')) {
            lastMsg = 'Foto';
          } else if (lastMsg.startsWith('data:audio')) {
            lastMsg = 'Pesan Suara';
          } else if (lastMsg.startsWith('data:')) {
            lastMsg = 'Berkas Dokumen';
          }

          if (lastMsg.length > 250) {
            lastMsg = '${lastMsg.substring(0, 250)}...';
          }

          final convId = item['id'] as String? ?? '';
          final safetyPreview = SafetyNumberHelper.getPreview(
            SafetyNumberHelper.deriveSafetyNumber(convId, participantUserId ?? currentUserId ?? 'peer'),
          );

          final old = cachedMap[convId];
          final isPinned = old?.isPinned ?? false;
          final isLocked = old?.isLocked ?? false;
          final isArchived = old?.isArchived ?? false;
          final isMuted = old?.isMuted ?? false;
          final isCurOpen = isConversationOpen(convId);
          final unreadCount = (isCurOpen || isOutgoingLatest) ? 0 : (old?.unreadCount ?? 0);

          return ConversationModel(
            id: convId,
            title: title,
            lastMessage: lastMsg,
            lastMessageTime: DateHelper.parseUtc(item['updatedAt']),
            unreadCount: unreadCount,
            isGroup: isGroup,
            isOnline: !isGroup && (item['isOnline'] == true),
            isKeyVerified: true,
            isPinned: isPinned,
            isLocked: isLocked,
            isArchived: isArchived,
            isMuted: isMuted,
            avatarUrl: avatarUrl ?? old?.avatarUrl,
            safetyNumberPreview: safetyPreview,
            participantUserId: participantUserId,
            participantPhone: participantPhone,
            participantAbout: participantAbout,
            participantTrustScore: participantTrustScore,
            isOutgoingLatest: isOutgoingLatest,
          );
        }).toList();

        // Detect newly arrived messages and trigger native system notification
        if (inMemoryConversations != null && inMemoryConversations!.isNotEmpty) {
          for (final conv in conversations) {
            final old = inMemoryConversations!.firstWhere(
              (c) => c.id == conv.id,
              orElse: () => ConversationModel(id: '', title: '', lastMessage: '', lastMessageTime: DateTime.fromMillisecondsSinceEpoch(0)),
            );
            if (old.id.isNotEmpty && conv.lastMessageTime.isAfter(old.lastMessageTime) && conv.lastMessage != old.lastMessage) {
              if (!conv.isMuted && !conv.isOutgoingLatest && !isConversationOpen(conv.id)) {
                PushNotificationService.showMessageNotification(
                  conversationId: conv.id,
                  title: conv.title,
                  message: conv.lastMessage,
                );
              }
            }
          }
        }

        // Prune groups in SQLite that are no longer in server list (e.g. left or kicked)
        final serverConvIds = conversations.map((c) => c.id).toSet();
        final cached = await LocalDatabase.instance.getConversations();
        for (final c in cached) {
          if (c.isGroup && !serverConvIds.contains(c.id)) {
            await LocalDatabase.instance.deleteConversation(c.id);
            _inMemoryMessages.remove(c.id);
            GroupController.instance.removeGroup(c.id);
          }
        }

        // Persist to local cache and memory cache only if data has changed
        final hasChanged = !ConversationModel.areListsEqual(inMemoryConversations, conversations);
        if (hasChanged) {
          inMemoryConversations = conversations;
          conversationsNotifier.value = conversations;
          LocalDatabase.instance.upsertConversations(conversations);
        }
        return conversations;
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchConversations error: $e');
    }
    return [];
  }

  /// Fast foreground poll to check for any new messages
  Future<void> syncForegroundMessages() async {
    await fetchConversations();
  }

  /// Create a 1-on-1 personal conversation
  Future<String?> createPersonalConversation(String otherUserId) async {
    var cleanId = otherUserId.trim();
    if (cleanId.startsWith('conv-')) {
      cleanId = cleanId.substring(5).trim();
    }
    if (cleanId.isEmpty || cleanId.startsWith('grp-') || cleanId == 'm-you') {
      debugPrint('[ConversationService] createPersonalConversation diabaikan, format identifier tidak valid: $cleanId');
      return null;
    }

    if (_tempToRealConvMap.containsKey('conv-$cleanId')) {
      return _tempToRealConvMap['conv-$cleanId'];
    }

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversations,
        body: {
          'type': 'PERSONAL',
          'participantUserIds': [cleanId],
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final convId = response.rawJson['id'] as String?;
        if (convId != null && convId.isNotEmpty) {
          _tempToRealConvMap['conv-$cleanId'] = convId;
          _tempToRealConvMap[cleanId] = convId;
          return convId;
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] createPersonalConversation error: $e');
    }
    return null;
  }

  /// Create a new group conversation
  Future<String?> createGroupConversation({
    required String title,
    required List<String> participantUserIds,
    String? description,
    String? wallpaperId,
    String? killPin,
    List<String>? authorizedWipeUserIds,
    String? avatarUrl,
  }) async {
    final validParticipants = participantUserIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !id.startsWith('conv-') && !id.startsWith('grp-') && !id.startsWith('m-'))
        .toList();

    if (validParticipants.isEmpty) {
      debugPrint('[ConversationService] createGroupConversation diabaikan, tidak ada anggota valid');
      return null;
    }

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversations,
        body: {
          'type': 'GROUP',
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
          'participantUserIds': validParticipants,
          if (wallpaperId != null && wallpaperId.isNotEmpty) 'wallpaperId': wallpaperId,
          if (killPin != null && killPin.isNotEmpty) 'killPin': killPin,
          if (authorizedWipeUserIds != null && authorizedWipeUserIds.isNotEmpty)
            'authorizedWipeUserIds': authorizedWipeUserIds,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final convId = response.rawJson['id']?.toString();
        return convId;
      } else {
        debugPrint('[ConversationService] createGroupConversation failed: ${response.statusCode} ${response.errorMessage}');
      }
    } catch (e) {
      debugPrint('[ConversationService] createGroupConversation error: $e');
    }
    return null;
  }

  /// Permanently wipe all messages and data for this conversation for all members
  Future<bool> destructiveWipeGroup(String conversationId, String pin) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationDestructiveWipe(conversationId),
        body: {'pin': pin.trim()},
      );

      if (response.isSuccess) {
        // Clear local database messages for this conversation
        await LocalDatabase.instance.clearMessages(conversationId);
        // Also update local conversation entry lastMessage
        final conv = await LocalDatabase.instance.getConversation(conversationId);
        if (conv != null) {
          final updated = conv.copyWith(
            lastMessage: 'Pesan telah dihancurkan',
            unreadCount: 0,
          );
          await LocalDatabase.instance.upsertConversations([updated]);
        }
        return true;
      } else {
        final msg = response.errorMessage ?? 'Gagal menghancurkan riwayat obrolan';
        debugPrint('[ConversationService] destructiveWipeGroup failed: ${response.statusCode} $msg');
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('[ConversationService] destructiveWipeGroup error: $e');
      rethrow;
    }
  }

  /// Permanently delete a group and evict all members
  Future<bool> deleteGroup(String conversationId, String pin) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationDeleteGroup(conversationId),
        body: {'pin': pin.trim()},
      );

      if (response.isSuccess) {
        _inMemoryMessages.remove(conversationId);
        await LocalDatabase.instance.deleteConversation(conversationId);
        await LocalDatabase.instance.clearMessages(conversationId);
        _realtimeGroupDeletedController.add(conversationId);
        await fetchConversations();
        return true;

      } else {
        final msg = response.errorMessage ?? 'Gagal menghapus grup';
        debugPrint('[ConversationService] deleteGroup failed: ${response.statusCode} $msg');
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('[ConversationService] deleteGroup error: $e');
      rethrow;
    }
  }

  /// Update group info (title, description, permissions)

  Future<bool> updateGroup({
    required String conversationId,
    String? title,
    String? description,
    Map<String, dynamic>? permissions,
    String? avatarUrl,
  }) async {
    try {
      final response = await ApiClient.instance.patch(
        ApiEndpoints.conversationById(conversationId),
        body: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (permissions != null) 'permissions': permissions,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        },
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] updateGroup error: $e');
      return false;
    }
  }

  /// Add member to group
  Future<bool> addMember(String conversationId, String userId, [String role = 'MEMBER']) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationMembers(conversationId),
        body: {
          'userId': userId,
          'role': role,
        },
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] addMember error: $e');
      return false;
    }
  }

  /// Change member role (ADMIN or MEMBER)
  Future<bool> changeMemberRole(String conversationId, String targetUserId, bool isAdmin) async {
    try {
      final response = await ApiClient.instance.patch(
        ApiEndpoints.conversationMemberRole(conversationId, targetUserId),
        body: {
          'role': isAdmin ? 'ADMIN' : 'MEMBER',
        },
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] changeMemberRole error: $e');
      return false;
    }
  }

  /// Remove member from group
  Future<bool> removeMember(String conversationId, String targetUserId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.conversationMemberRole(conversationId, targetUserId),
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] removeMember error: $e');
      return false;
    }
  }

  /// Leave a group conversation
  Future<bool> leaveGroup(String conversationId, {String? newOwnerUserId}) async {
    try {
      final realId = resolveConversationId(conversationId);
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationLeave(realId),
        body: newOwnerUserId != null ? {'newOwnerUserId': newOwnerUserId} : {},
      );
      if (response.isSuccess) {
        // Completely delete group and history from local storage and memory
        await LocalDatabase.instance.deleteConversation(conversationId);
        if (realId != conversationId) {
          await LocalDatabase.instance.deleteConversation(realId);
        }
        _inMemoryMessages.remove(conversationId);
        _inMemoryMessages.remove(realId);
        GroupController.instance.removeGroup(conversationId);
        GroupController.instance.removeGroup(realId);

        if (inMemoryConversations != null) {
          inMemoryConversations = inMemoryConversations!
              .where((c) => c.id != conversationId && c.id != realId)
              .toList();
          conversationsNotifier.value = List.from(inMemoryConversations!);
        } else {
          final cur = List<ConversationModel>.from(conversationsNotifier.value);
          cur.removeWhere((c) => c.id == conversationId || c.id == realId);
          conversationsNotifier.value = cur;
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ConversationService] leaveGroup error: $e');
      return false;
    }
  }

  /// Transfer ownership of a group to another member
  Future<bool> transferGroupOwnership(String conversationId, String newOwnerUserId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationTransferOwnership(conversationId),
        body: {'newOwnerUserId': newOwnerUserId},
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] transferGroupOwnership error: $e');
      return false;
    }
  }

  /// Fetch full details of a conversation (including all members and roles)
  Future<Map<String, dynamic>?> getConversationDetails(String conversationId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.conversationById(conversationId),
      );
      if (response.isSuccess && response.rawJson is Map) {
        return Map<String, dynamic>.from(response.rawJson);
      }
    } catch (e) {
      debugPrint('[ConversationService] getConversationDetails error: $e');
    }
    return null;
  }

  /// Return messages from local SQLite cache for a conversation (offline-safe, instant).
  Future<List<MessageModel>> getMessagesFromCache(String conversationId) async {
    final cached = await LocalDatabase.instance.getMessages(conversationId);
    final prefs = await SharedPreferences.getInstance();
    final clearedStr = prefs.getString('laju_chat_cleared_at_$conversationId');
    List<MessageModel> result = cached;
    if (clearedStr != null) {
      final clearedAt = DateTime.tryParse(clearedStr);
      if (clearedAt != null) {
        result = cached.where((m) => m.timestamp.isAfter(clearedAt)).toList();
      }
    }
    if (result.isNotEmpty) {
      updateMemoryMessages(conversationId, result);
    } else {
      updateMemoryMessages(conversationId, []);
    }
    return result;
  }

  /// Fetch message history for a conversation
  Future<List<MessageModel>> fetchMessages(String conversationId, {int limit = 50, int? cursor}) async {
    String effectiveConvId = _tempToRealConvMap[conversationId] ?? conversationId;
    if (effectiveConvId.startsWith('conv-')) {
      final targetUserId = effectiveConvId.substring(5).trim();
      final resolvedId = await createPersonalConversation(targetUserId);
      if (resolvedId != null && resolvedId.isNotEmpty) {
        effectiveConvId = resolvedId;
      }
    }

    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor.toString(),
      };

      final response = await ApiClient.instance.get(
        ApiEndpoints.conversationMessages(effectiveConvId),
        queryParams: queryParams,
      );

      if (response.isSuccess && response.rawJson is Map) {
        if (response.rawJson.containsKey('isTyping')) {
          final isTyping = response.rawJson['isTyping'] == true;
          final typingUsersRaw = response.rawJson['typingUsers'] as List?;
          final typingUsers = typingUsersRaw != null ? typingUsersRaw.map((u) => u.toString()).toList() : <String>[];
          setTypingDetails(conversationId, isTyping, typingUsers);
          if (effectiveConvId != conversationId) {
            setTypingDetails(effectiveConvId, isTyping, typingUsers);
          }
        }

        if (response.rawJson.containsKey('peerOnline')) {
          final isPeerOnline = response.rawJson['peerOnline'] == true;
          setPeerOnline(conversationId, isPeerOnline);
          if (effectiveConvId != conversationId) {
            setPeerOnline(effectiveConvId, isPeerOnline);
          }
        }

        if (response.rawJson.containsKey('groupInfo') && response.rawJson['groupInfo'] is Map) {
          final gInfo = response.rawJson['groupInfo'] as Map;
          GroupController.instance.updateGroupFromRealtime(
            groupId: effectiveConvId,
            title: gInfo['title'] as String?,
            description: gInfo['description'] as String?,
            avatarUrl: gInfo['avatarUrl'] as String?,
            memberCount: (gInfo['memberCount'] as num?)?.toInt(),
            isMember: gInfo['isMember'] == true,
            role: gInfo['role'] as String?,
          );
        }

        final messagesList = response.rawJson['messages'];
        if (messagesList is List) {
          final messages = messagesList.map((m) {
            return parseMessageFromJson(m as Map<String, dynamic>, conversationId);
          }).toList();

          final deduplicated = MessageModel.deduplicate(messages);
          final prefs = await SharedPreferences.getInstance();
          final serverPurgedAtStr = response.rawJson['purgedAt'] as String?;
          String? clearedStr = prefs.getString('laju_chat_cleared_at_$conversationId') ??
              prefs.getString('laju_chat_cleared_at_$effectiveConvId');

          if (serverPurgedAtStr != null) {
            final serverPurgedAt = DateTime.tryParse(serverPurgedAtStr);
            final localClearedAt = clearedStr != null ? DateTime.tryParse(clearedStr) : null;

            if (serverPurgedAt != null && (localClearedAt == null || serverPurgedAt.isAfter(localClearedAt))) {
              await LocalDatabase.instance.clearMessages(conversationId);
              if (effectiveConvId != conversationId) {
                await LocalDatabase.instance.clearMessages(effectiveConvId);
              }
              _inMemoryMessages[conversationId] = [];
              if (effectiveConvId != conversationId) {
                _inMemoryMessages[effectiveConvId] = [];
              }
              await prefs.setString('laju_chat_cleared_at_$conversationId', serverPurgedAtStr);
              if (effectiveConvId != conversationId) {
                await prefs.setString('laju_chat_cleared_at_$effectiveConvId', serverPurgedAtStr);
              }
              clearedStr = serverPurgedAtStr;

              final currentList = inMemoryConversations ?? conversationsNotifier.value;
              final idx = currentList.indexWhere((c) => c.id == conversationId || c.id == effectiveConvId);
              if (idx != -1) {
                final old = currentList[idx];
                final updated = old.copyWith(
                  lastMessage: 'Pesan telah dihancurkan',
                  unreadCount: 0,
                );
                currentList[idx] = updated;
                inMemoryConversations = List.from(currentList);
                conversationsNotifier.value = List.from(currentList);
                await LocalDatabase.instance.upsertConversations([updated]);
              }
            }
          }

          List<MessageModel> finalMessages = deduplicated;
          if (clearedStr != null) {
            final clearedAt = DateTime.tryParse(clearedStr);
            if (clearedAt != null) {
              finalMessages = deduplicated.where((m) => m.timestamp.isAfter(clearedAt)).toList();
            }
          }

          final deletedForMe = await LocalDatabase.instance.getDeletedForMeIds();
          final filtered = finalMessages.where((m) => !deletedForMe.contains(m.id)).toList();

          // Persist to local cache and memory cache
          updateMemoryMessages(conversationId, filtered);
          if (effectiveConvId != conversationId) {
            updateMemoryMessages(effectiveConvId, filtered);
          }
          if (filtered.isNotEmpty) {
            LocalDatabase.instance.upsertMessages(conversationId, filtered);
            if (effectiveConvId != conversationId) {
              LocalDatabase.instance.upsertMessages(effectiveConvId, filtered);
            }
            for (final m in filtered) {
              if (m.isRecalled) {
                LocalDatabase.instance.markMessageDeleted(m.id);
              }
            }
          } else if (serverPurgedAtStr != null) {
            await LocalDatabase.instance.clearMessages(conversationId);
            if (effectiveConvId != conversationId) {
              await LocalDatabase.instance.clearMessages(effectiveConvId);
            }
          }
          return filtered;
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchMessages error: $e');
    }
    return [];
  }

  /// Helper to convert backend JSON into MessageModel
  MessageModel parseMessageFromJson(Map<String, dynamic> m, String conversationId) {
    final currentUserId = ApiClient.instance.userId;
    final isOutgoing = m['senderUserId'] == currentUserId;
    final reactionsRaw = m['reactions'] as List?;
    final reactionsList = reactionsRaw != null
        ? reactionsRaw
            .where((r) => r is Map && r['emoji'] != null)
            .map((r) => r['emoji'] as String)
            .toList()
        : <String>[];

    final rawCiphertext = (m['ciphertext'] ?? '') as String;
    final msgType = (m['messageType'] ?? 'TEXT') as String;

    MessageContentType contentType = MessageContentType.text;
    String contentText = rawCiphertext;
    String? mediaData;
    String? attName;
    String? attSize;
    MessageModel? parsedReplyTo;

    if (rawCiphertext.startsWith('{')) {
      try {
        final parsed = jsonDecode(rawCiphertext);
        if (parsed is Map) {
          if (parsed['replyTo'] is Map) {
            final r = parsed['replyTo'] as Map;
            parsedReplyTo = MessageModel(
              id: (r['id'] ?? '') as String,
              conversationId: conversationId,
              senderName: (r['senderName'] ?? 'Contact') as String,
              content: (r['content'] ?? '') as String,
              attachmentPath: r['attachmentPath'] as String?,
              attachmentName: r['attachmentName'] as String?,
              timestamp: DateTime.now(),
              isOutgoing: false,
              contentType: MessageContentType.values.firstWhere(
                (ct) => ct.name == r['contentType'],
                orElse: () => MessageContentType.text,
              ),
            );
          }

          if (parsed['type'] == 'image') {
            contentType = MessageContentType.attachment;
            mediaData = parsed['media'] as String?;
            attName = (parsed['fileName'] ?? 'Foto.jpg') as String;
            contentText = (parsed['caption'] ?? '') as String;
          } else if (parsed['type'] == 'audio') {
            final fn = (parsed['fileName'] ?? 'Voice Note') as String;
            final isAudioFile = fn != 'Voice Note' &&
                (fn.toLowerCase().endsWith('.mp3') ||
                 fn.toLowerCase().endsWith('.wav') ||
                 fn.toLowerCase().endsWith('.m4a') ||
                 fn.toLowerCase().endsWith('.aac') ||
                 fn.toLowerCase().endsWith('.ogg') ||
                 fn.toLowerCase().endsWith('.flac'));
            contentType = isAudioFile ? MessageContentType.attachment : MessageContentType.voiceNote;
            mediaData = parsed['media'] as String?;
            attName = fn;
            attSize = (parsed['duration'] ?? '') as String;
            final cap = (parsed['caption'] ?? '') as String;
            contentText = isAudioFile
                ? cap
                : (attSize.isNotEmpty ? 'Pesan Suara ($attSize)' : 'Pesan Suara');
          } else if (parsed['type'] == 'document') {
            contentType = MessageContentType.attachment;
            mediaData = parsed['media'] as String?;
            attName = (parsed['fileName'] ?? 'Dokumen') as String;
            attSize = (parsed['fileSize'] ?? '') as String;
            contentText = (parsed['caption'] ?? '') as String;
            if (attSize.isEmpty && mediaData != null && mediaData.contains(',')) {
              final b64Part = mediaData.split(',').last;
              final approxBytes = (b64Part.length * 3) ~/ 4;
              if (approxBytes > 0) {
                attSize = approxBytes < 1024 * 1024
                    ? '${(approxBytes / 1024).toStringAsFixed(1)} KB'
                    : '${(approxBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
              }
            }

            if (isImageFile(attName) && mediaData != null && mediaData.startsWith('data:') && !mediaData.startsWith('data:image')) {
              final b64 = mediaData.split(',').last;
              final imgMime = detectMimeType(attName);
              mediaData = 'data:${imgMime.startsWith('image/') ? imgMime : 'image/jpeg'};base64,$b64';
            }
          } else if (parsed['type'] == 'location') {
            contentType = MessageContentType.location;
            attName = (parsed['name'] ?? 'Lokasi') as String;
            attSize = (parsed['address'] ?? '') as String;
            contentText = rawCiphertext;
          } else if (parsed['type'] == 'contact') {
            contentType = MessageContentType.contact;
            attName = (parsed['name'] ?? 'Kontak LAJU') as String;
            attSize = (parsed['username'] ?? '') as String;
            contentText = rawCiphertext;
            if (rawCiphertext.startsWith('{')) {
              try {
                final pContact = jsonDecode(rawCiphertext);
                if (pContact is Map) {
                  attName = (pContact['name'] ?? 'Kontak LAJU') as String;
                  attSize = (pContact['username'] ?? '') as String;
                }
              } catch (_) {}
            }
          } else if (parsed['type'] == 'sticker') {
            contentType = MessageContentType.sticker;
            attName = (parsed['stickerId'] ?? 'cat_thumbs_up') as String;
            mediaData = parsed['assetPath'] as String? ?? parsed['media'] as String?;
            contentText = (parsed['caption'] ?? '') as String;
          } else if (parsed['type'] == 'reply') {
            contentText = (parsed['text'] ?? '') as String;
          } else if (parsed['type'] == 'wallpaper_change') {
            contentType = MessageContentType.systemNotice;
            final wpId = parsed['wallpaperId'] as String? ?? 'none';
            final wpName = (parsed['wallpaperName'] ?? (wpId == 'none' ? 'Default Polos' : wpId)) as String;
            final senderName = isOutgoing ? 'Anda' : (m['senderUser']?['username'] ?? 'Kontak');
            contentText = wpId == 'none'
                ? '$senderName menyetel wallpaper obrolan ke default'
                : '$senderName mengubah wallpaper obrolan menjadi "$wpName"';
            ChatAppearanceController.instance.syncRemoteChatWallpaper(conversationId, wpId);
          }
        }
      } catch (_) {}
    }

    if (mediaData == null && contentType != MessageContentType.location && contentType != MessageContentType.sticker) {
      if (msgType == 'STICKER') {
        contentType = MessageContentType.sticker;
        attName = rawCiphertext;
      } else if (msgType == 'IMAGE' || rawCiphertext.startsWith('data:image')) {
        contentType = MessageContentType.attachment;
        mediaData = rawCiphertext;
        attName = 'Foto.jpg';
        contentText = '';
      } else if (msgType == 'AUDIO' || rawCiphertext.startsWith('data:audio')) {
        contentType = MessageContentType.voiceNote;
        mediaData = rawCiphertext;
        attName = 'Voice Note';
        contentText = 'Pesan Suara';
        attSize = '0:00';
      } else if (msgType == 'VIDEO' || rawCiphertext.contains('"type":"video"') || rawCiphertext.contains('"type": "video"')) {
        contentType = MessageContentType.attachment;
        if (rawCiphertext.startsWith('{')) {
          try {
            final parsed = jsonDecode(rawCiphertext);
            if (parsed is Map) {
              mediaData = (parsed['media'] ?? parsed['mediaUrl'] ?? parsed['videoUrl']) as String?;
              attName = (parsed['fileName'] ?? 'Video.mp4') as String;
              contentText = (parsed['caption'] ?? '') as String;
            }
          } catch (_) {}
        }
        if (mediaData == null && rawCiphertext.startsWith('http')) {
          mediaData = rawCiphertext;
          attName = 'Video.mp4';
        }
      } else if (rawCiphertext.contains('"type":"status_forward"') || rawCiphertext.contains('"type": "status_forward"')) {
        contentType = MessageContentType.attachment;
        contentText = rawCiphertext;
        try {
          final parsed = jsonDecode(rawCiphertext);
          if (parsed is Map) {
            mediaData = (parsed['mediaUrl'] ?? parsed['media'] ?? parsed['thumbnailUrl']) as String?;
            attName = parsed['statusType'] == 'video' ? 'status_video.mp4' : 'status_photo.jpg';
          }
        } catch (_) {}
      } else if (msgType == 'DOCUMENT' || rawCiphertext.startsWith('data:') || rawCiphertext.startsWith('Dokumen')) {
        contentType = MessageContentType.attachment;
        mediaData = rawCiphertext.startsWith('data:') ? rawCiphertext : null;
        attName = 'Dokumen';
      } else if (rawCiphertext.contains('"type":"call_log"') || rawCiphertext.contains('"type": "call_log"')) {
        contentType = MessageContentType.callLog;
        contentText = rawCiphertext;
      } else if (msgType == 'LOCATION' || rawCiphertext.contains('"type":"location"') || rawCiphertext.contains('"type": "location"')) {
        contentType = MessageContentType.location;
        contentText = rawCiphertext;
      } else if (msgType == 'CONTACT' || rawCiphertext.contains('"type":"contact"') || rawCiphertext.contains('"type": "contact"')) {
        contentType = MessageContentType.contact;
        contentText = rawCiphertext;
        if (rawCiphertext.startsWith('{')) {
          try {
            final parsed = jsonDecode(rawCiphertext);
            if (parsed is Map) {
              attName = (parsed['name'] ?? 'Kontak LAJU') as String;
              attSize = (parsed['username'] ?? '') as String;
            }
          } catch (_) {}
        }
      } else if (msgType == 'ATTACHMENT') {
        if (rawCiphertext.contains('"type":"contact"') || rawCiphertext.contains('"type": "contact"')) {
          contentType = MessageContentType.contact;
          contentText = rawCiphertext;
          if (rawCiphertext.startsWith('{')) {
            try {
              final parsed = jsonDecode(rawCiphertext);
              if (parsed is Map) {
                attName = (parsed['name'] ?? 'Kontak LAJU') as String;
                attSize = (parsed['username'] ?? '') as String;
              }
            } catch (_) {}
          }
        } else if (rawCiphertext.startsWith('{')) {
          try {
            final parsed = jsonDecode(rawCiphertext);
            if (parsed is Map) {
              mediaData = parsed['media'] as String?;
              attName = (parsed['fileName'] ?? 'Dokumen') as String;
              attSize = (parsed['fileSize'] ?? '') as String;
              contentText = (parsed['caption'] ?? '') as String;
            } else {
              contentText = '';
            }
          } catch (_) {
            contentText = '';
          }
        } else if (rawCiphertext.startsWith('data:')) {
          mediaData = rawCiphertext;
          attName = 'Dokumen';
          contentText = '';
        } else {
          contentText = rawCiphertext;
        }
      }
    }

    final isDeletedState = m['state'] == 'DELETED' || rawCiphertext == '__DELETED_FOR_EVERYONE__';

    MessageDeliveryStatus deliveryStatus = MessageDeliveryStatus.delivered;
    final mState = m['state'] as String?;
    final deliveries = m['deliveries'] as List?;
    if (mState == 'READ') {
      deliveryStatus = MessageDeliveryStatus.read;
    } else if (deliveries != null && deliveries.isNotEmpty) {
      final hasRead = deliveries.any((d) => d is Map && d['status'] == 'READ');
      if (hasRead) {
        deliveryStatus = MessageDeliveryStatus.read;
      }
    }

    return MessageModel(
      id: m['id'] ?? '',
      clientMessageId: m['clientMessageId'] as String?,
      conversationId: conversationId,
      senderName: isOutgoing ? 'You' : (m['senderUser']?['username'] ?? 'Contact'),
      senderUserId: m['senderUserId'] as String?,
      content: isDeletedState ? '__DELETED_FOR_EVERYONE__' : contentText,
      attachmentPath: isDeletedState ? null : mediaData,
      attachmentName: isDeletedState ? null : attName,
      attachmentSize: isDeletedState ? null : attSize,
      contentType: isDeletedState ? MessageContentType.text : contentType,
      timestamp: DateHelper.parseUtc(m['createdAt']),
      isOutgoing: isOutgoing,
      status: deliveryStatus,
      replyTo: isDeletedState ? null : parsedReplyTo,
      reactions: isDeletedState ? const [] : reactionsList,
      isDeleted: isDeletedState,
    );
  }

  /// Send message to conversation (supports text, images, audio voice notes, documents, and replies)
  Future<MessageModel?> sendMessage({
    required String conversationId,
    required String text,
    String? clientMessageId,
    String? messageType, // 'TEXT', 'IMAGE', 'AUDIO', 'DOCUMENT', 'LOCATION'
    String? attachmentPath,
    String? attachmentName,
    String? attachmentSize,
    MessageModel? replyTo,
  }) async {
    final id = clientMessageId ?? 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final type = messageType ?? 'TEXT';
    String payloadCiphertext = text;

    Map<String, dynamic>? replyToMap;
    if (replyTo != null) {
      replyToMap = {
        'id': replyTo.id,
        'senderName': replyTo.senderName,
        'content': replyTo.displaySnippet,
        'contentType': replyTo.contentType.name,
        if (replyTo.attachmentPath != null) 'attachmentPath': replyTo.attachmentPath,
        if (replyTo.attachmentName != null) 'attachmentName': replyTo.attachmentName,
      };
    }

    // Convert local media files to base64 data URI for instant cross-device transfer
    if (type == 'STICKER') {
      payloadCiphertext = jsonEncode({
        'type': 'sticker',
        'stickerId': attachmentName ?? text,
        'assetPath': attachmentPath,
        'caption': text.trim(),
        if (replyToMap != null) 'replyTo': replyToMap,
      });
    } else if (type == 'STATUS' || payloadCiphertext.contains('"type":"status_forward"') || payloadCiphertext.contains('"type": "status_forward"')) {
      // Status forward payload is already encoded JSON
      if (replyToMap != null) {
        try {
          final parsed = jsonDecode(payloadCiphertext);
          if (parsed is Map<String, dynamic>) {
            parsed['replyTo'] = replyToMap;
            payloadCiphertext = jsonEncode(parsed);
          }
        } catch (_) {}
      }
    } else if (attachmentPath != null && (type == 'IMAGE' || type == 'VIDEO' || type == 'AUDIO' || type == 'DOCUMENT')) {
      try {
        String effectivePath = attachmentPath;
        final detectedMime = detectMimeType(effectivePath, fileName: attachmentName);
        final isImg = type == 'IMAGE' || isImageFile(attachmentName ?? '') || isImageFile(effectivePath) || detectedMime.startsWith('image/');
        final isVid = type == 'VIDEO' || (attachmentName ?? '').toLowerCase().endsWith('.mp4') || effectivePath.toLowerCase().endsWith('.mp4') || detectedMime.startsWith('video/');

        if (type == 'IMAGE') {
          effectivePath = await DeviceMediaService.compressImage(attachmentPath);
        }
        final file = File(effectivePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = isImg
              ? (detectedMime.startsWith('image/') ? detectedMime : 'image/jpeg')
              : (isVid
                  ? (detectedMime.startsWith('video/') ? detectedMime : 'video/mp4')
                  : (type == 'AUDIO'
                      ? (detectedMime.startsWith('audio/') ? detectedMime : 'audio/m4a')
                      : (detectedMime.isNotEmpty ? detectedMime : 'application/octet-stream')));

          if (isImg) {
            payloadCiphertext = jsonEncode({
              'type': 'image',
              'media': 'data:$mime;base64,$b64',
              'fileName': attachmentName ?? 'Foto.jpg',
              'fileSize': attachmentSize ?? '',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          } else if (isVid) {
            payloadCiphertext = jsonEncode({
              'type': 'video',
              'media': 'data:$mime;base64,$b64',
              'fileName': attachmentName ?? 'Video.mp4',
              'fileSize': attachmentSize ?? '',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          } else if (type == 'AUDIO') {
            payloadCiphertext = jsonEncode({
              'type': 'audio',
              'media': 'data:$mime;base64,$b64',
              'duration': attachmentSize ?? '0:00',
              'fileName': attachmentName ?? 'Voice Note',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          } else {
            payloadCiphertext = jsonEncode({
              'type': 'document',
              'media': 'data:$mime;base64,$b64',
              'fileName': attachmentName ?? 'Dokumen',
              'fileSize': attachmentSize ?? '',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          }
        } else if (effectivePath.startsWith('http://') || effectivePath.startsWith('https://') || effectivePath.startsWith('admin/media')) {
          if (isVid) {
            payloadCiphertext = jsonEncode({
              'type': 'video',
              'media': effectivePath,
              'fileName': attachmentName ?? 'Video.mp4',
              'fileSize': attachmentSize ?? '',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          } else if (isImg) {
            payloadCiphertext = jsonEncode({
              'type': 'image',
              'media': effectivePath,
              'fileName': attachmentName ?? 'Foto.jpg',
              'fileSize': attachmentSize ?? '',
              'caption': text.trim(),
              if (replyToMap != null) 'replyTo': replyToMap,
            });
          }
        }
      } catch (_) {}
    } else if (replyToMap != null) {
      if (type == 'LOCATION' || payloadCiphertext.startsWith('{')) {
        try {
          final parsed = jsonDecode(payloadCiphertext);
          if (parsed is Map) {
            parsed['replyTo'] = replyToMap;
            payloadCiphertext = jsonEncode(parsed);
          }
        } catch (_) {
          payloadCiphertext = jsonEncode({
            'type': 'reply',
            'text': text,
            'replyTo': replyToMap,
          });
        }
      } else {
        payloadCiphertext = jsonEncode({
          'type': 'reply',
          'text': text,
          'replyTo': replyToMap,
        });
      }
    }

    try {
      final backendMessageType = (type == 'IMAGE' || type == 'VIDEO' || type == 'STATUS' || type == 'AUDIO' || type == 'DOCUMENT' || type == 'ATTACHMENT' || type == 'STICKER' || type == 'CONTACT')
          ? 'ATTACHMENT'
          : (type == 'LOCATION' ? 'LOCATION' : 'TEXT');

      String effectiveConvId = _tempToRealConvMap[conversationId] ?? conversationId;
      if (effectiveConvId.startsWith('conv-')) {
        final targetUserId = effectiveConvId.substring(5).trim();
        final resolvedId = await createPersonalConversation(targetUserId);
        if (resolvedId != null && resolvedId.isNotEmpty) {
          effectiveConvId = resolvedId;
        }
      }

      final convList = inMemoryConversations ?? conversationsNotifier.value;
      final convMatch = convList.where((c) => c.id == effectiveConvId || c.id == conversationId).toList();
      final effectiveDisappearingSeconds = (convMatch.isNotEmpty && convMatch.first.disappearingSeconds != null)
          ? convMatch.first.disappearingSeconds
          : PrivacyController.instance.disappearingSeconds;

      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationMessages(effectiveConvId),
        body: {
          'clientMessageId': id,
          'ciphertext': payloadCiphertext,
          'nonce': base64Encode(List.generate(12, (i) => i)),
          'messageType': backendMessageType,
          if (effectiveDisappearingSeconds != null && effectiveDisappearingSeconds > 0)
            'expiresInSeconds': effectiveDisappearingSeconds,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final m = response.rawJson;
        final confirmedId = m['id'] ?? id;
        final realConvId = (m['conversationId'] as String?) ?? effectiveConvId;
        _tempToRealConvMap[conversationId] = realConvId;
        _tempToRealConvMap[effectiveConvId] = realConvId;

        final confirmedMsg = MessageModel(
          id: confirmedId,
          clientMessageId: id,
          conversationId: realConvId,
          senderName: 'You',
          content: text.trim(),
          attachmentPath: attachmentPath,
          attachmentName: attachmentName,
          attachmentSize: attachmentSize,
          replyTo: replyTo,
          contentType: type == 'STICKER'
              ? MessageContentType.sticker
              : (type == 'AUDIO'
                  ? MessageContentType.voiceNote
                  : (type == 'IMAGE' || type == 'DOCUMENT' || type == 'VIDEO' || type == 'STATUS'
                      ? MessageContentType.attachment
                      : (type == 'LOCATION'
                          ? MessageContentType.location
                          : (type == 'CONTACT' ? MessageContentType.contact : MessageContentType.text)))),
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MessageDeliveryStatus.sent,
          isDisappearing: effectiveDisappearingSeconds != null && effectiveDisappearingSeconds > 0,
          remainingSeconds: effectiveDisappearingSeconds,
        );

        // Replace optimistic message in SQLite and update status
        await LocalDatabase.instance.replaceOptimisticMessage(id, confirmedMsg);

        // Update in-memory messages if present
        for (final cid in [conversationId, effectiveConvId, realConvId]) {
          final currentMemory = _inMemoryMessages[cid];
          if (currentMemory != null) {
            final updatedMemory = List<MessageModel>.from(currentMemory);
            final idx = updatedMemory.indexWhere((msg) => msg.id == id || msg.clientMessageId == id);
            if (idx != -1) {
              updatedMemory[idx] = confirmedMsg;
            } else {
              updatedMemory.add(confirmedMsg);
            }
            _inMemoryMessages[cid] = MessageModel.deduplicate(updatedMemory);
          }
        }

        // Record network usage
        final isMedia = type == 'IMAGE' || type == 'AUDIO' || type == 'DOCUMENT' || type == 'ATTACHMENT' || type == 'STICKER';
        DataStorageController.instance.recordMessageSent(
          bytes: payloadCiphertext.length,
          isMedia: isMedia,
        );

        return confirmedMsg;
      }
    } catch (e) {
      debugPrint('[ConversationService] sendMessage error: $e');
      LocalDatabase.instance.updateMessageStatus(id, MessageDeliveryStatus.failed);
    }

    return MessageModel(
      id: id,
      clientMessageId: id,
      conversationId: conversationId,
      senderName: 'You',
      content: text,
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      replyTo: replyTo,
      contentType: type == 'STICKER'
          ? MessageContentType.sticker
          : (type == 'AUDIO'
              ? MessageContentType.voiceNote
              : (type == 'IMAGE' || type == 'DOCUMENT'
                  ? MessageContentType.attachment
                  : (type == 'LOCATION'
                      ? MessageContentType.location
                      : (type == 'CONTACT' ? MessageContentType.contact : MessageContentType.text)))),
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageDeliveryStatus.failed,
    );
  }

  /// Mark message as read on backend (Read Receipts / Blue Ticks)
  Future<void> markMessageRead(String messageId) async {
    if (!PrivacyController.instance.readReceipts) {
      return; // Privacy: Read receipts disabled by user
    }
    try {
      await ApiClient.instance.post(ApiEndpoints.messageRead(messageId));
    } catch (_) {}
  }

  /// Update disappearing messages timer for a specific conversation
  Future<void> updateConversationDisappearingTimer(String conversationId, int? seconds) async {
    final list = List<ConversationModel>.from(inMemoryConversations ?? conversationsNotifier.value);
    final idx = list.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final updated = list[idx].copyWith(
        disappearingSeconds: seconds,
        hasDisappearingMessages: seconds != null && seconds > 0,
      );
      list[idx] = updated;
      inMemoryConversations = list;
      conversationsNotifier.value = List.unmodifiable(list);
      await LocalDatabase.instance.upsertConversations([updated]);
    }
  }

  /// Broadcast chat wallpaper change to all participants in conversation
  Future<void> sendWallpaperChange({
    required String conversationId,
    required String wallpaperId,
    String? wallpaperName,
  }) async {
    final wpName = wallpaperName ?? (wallpaperId == 'none' ? 'Default Polos' : wallpaperId);
    final payload = jsonEncode({
      'type': 'wallpaper_change',
      'wallpaperId': wallpaperId,
      'wallpaperName': wpName,
    });

    final msgId = 'wp-${DateTime.now().millisecondsSinceEpoch}';
    final sent = await sendMessage(
      conversationId: conversationId,
      text: payload,
      clientMessageId: msgId,
      messageType: 'TEXT',
    );

    final noticeText = wallpaperId == 'none'
        ? 'Anda menyetel wallpaper obrolan ke default'
        : 'Anda mengubah wallpaper obrolan menjadi "$wpName"';

    final systemMsg = (sent != null)
        ? sent.copyWith(
            contentType: MessageContentType.systemNotice,
            content: noticeText,
          )
        : MessageModel(
            id: msgId,
            clientMessageId: msgId,
            conversationId: conversationId,
            senderName: 'You',
            content: noticeText,
            timestamp: DateTime.now(),
            isOutgoing: true,
            contentType: MessageContentType.systemNotice,
            status: MessageDeliveryStatus.sent,
          );

    await LocalDatabase.instance.insertSentMessage(systemMsg);

    final mem = _inMemoryMessages[conversationId];
    if (mem != null) {
      mem.add(systemMsg);
      _inMemoryMessages[conversationId] = mem;
    }
  }

  /// Recall a message for everyone (only permitted if <= 30 minutes old)
  Future<bool> recallMessage(String messageId, [String? conversationId]) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.messageById(messageId),
      );
      if (response.isSuccess) {
        await LocalDatabase.instance.markMessageDeleted(messageId);
        void updateMemList(String cid) {
          if (_inMemoryMessages.containsKey(cid)) {
            final list = _inMemoryMessages[cid]!;
            final idx = list.indexWhere((m) => m.id == messageId || (m.clientMessageId != null && m.clientMessageId == messageId));
            if (idx != -1) {
              list[idx] = list[idx].copyWith(
                content: '__DELETED_FOR_EVERYONE__',
                isDeleted: true,
                attachmentName: null,
                attachmentSize: null,
                attachmentPath: null,
              );
            }
          }
        }
        if (conversationId != null) {
          updateMemList(conversationId);
          final mapped = _tempToRealConvMap[conversationId];
          if (mapped != null) updateMemList(mapped);
          _tempToRealConvMap.forEach((k, v) {
            if (v == conversationId) updateMemList(k);
          });
        }
        return true;
      } else {
        final err = response.errorMessage ?? 'Gagal menarik pesan';
        debugPrint('[ConversationService] recallMessage failed: ${response.statusCode} $err');
        return false;
      }
    } catch (e) {
      debugPrint('[ConversationService] recallMessage error: $e');
      return false;
    }
  }

  /// Delete a message for current user only
  Future<void> deleteMessageForMe(String messageId, [String? conversationId]) async {
    await LocalDatabase.instance.deleteMessageForMe(messageId);
    if (conversationId != null && _inMemoryMessages.containsKey(conversationId)) {
      _inMemoryMessages[conversationId]!.removeWhere((m) => m.id == messageId);
    }
  }

  /// Delete a message locally (delegates to deleteMessageForMe)
  Future<bool> deleteMessage(String messageId, [String? conversationId]) async {
    await deleteMessageForMe(messageId, conversationId);
    return true;
  }

  /// Edit an existing message
  Future<bool> editMessage(String messageId, String newText) async {
    try {
      final response = await ApiClient.instance.patch(
        ApiEndpoints.messageById(messageId),
        body: {'ciphertext': newText},
      );
      await LocalDatabase.instance.updateMessageContent(messageId, newText);
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] editMessage error: $e');
      await LocalDatabase.instance.updateMessageContent(messageId, newText);
      return false;
    }
  }

  /// Delete an entire conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.conversationById(conversationId),
      );
      await LocalDatabase.instance.deleteConversation(conversationId);
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] deleteConversation error: $e');
      await LocalDatabase.instance.deleteConversation(conversationId);
      return false;
    }
  }

  /// Toggle a reaction on a message
  Future<bool> toggleReaction(String messageId, String emoji, bool isAdding) async {
    try {
      if (isAdding) {
        final response = await ApiClient.instance.post(
          ApiEndpoints.messageReactions(messageId),
          body: {'emoji': emoji},
        );
        return response.isSuccess;
      } else {
        final response = await ApiClient.instance.delete(
          ApiEndpoints.messageReactionDelete(messageId, Uri.encodeComponent(emoji)),
        );
        return response.isSuccess;
      }
    } catch (e) {
      debugPrint('[ConversationService] toggleReaction error: $e');
      return false;
    }
  }

  /// Clear all messages of a conversation locally on this device
  /// Clear conversation messages for current user only (persisted on server & local)
  Future<void> clearChatForMe(String conversationId) async {
    final effectiveConvId = _tempToRealConvMap[conversationId] ?? conversationId;

    // 1. Clear locally first for instant UI response
    _inMemoryMessages[conversationId] = [];
    if (effectiveConvId != conversationId) {
      _inMemoryMessages[effectiveConvId] = [];
    }
    await LocalDatabase.instance.clearMessages(conversationId);
    if (effectiveConvId != conversationId) {
      await LocalDatabase.instance.clearMessages(effectiveConvId);
    }

    final nowIso = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('laju_chat_cleared_at_$conversationId', nowIso);
    if (effectiveConvId != conversationId) {
      await prefs.setString('laju_chat_cleared_at_$effectiveConvId', nowIso);
    }

    final currentList = inMemoryConversations ?? conversationsNotifier.value;
    final idx = currentList.indexWhere((c) => c.id == conversationId || c.id == effectiveConvId);
    if (idx != -1) {
      final old = currentList[idx];
      final updated = old.copyWith(
        lastMessage: '',
        unreadCount: 0,
      );
      currentList[idx] = updated;
      inMemoryConversations = List.from(currentList);
      conversationsNotifier.value = List.from(currentList);
      await LocalDatabase.instance.upsertConversations([updated]);
    }

    _realtimePurgedController.add(conversationId);
    if (effectiveConvId != conversationId) {
      _realtimePurgedController.add(effectiveConvId);
    }

    // 2. Call backend to persist clearedAt in Postgres
    try {
      await ApiClient.instance.post(
        ApiEndpoints.conversationClearForMe(effectiveConvId),
      );
    } catch (e) {
      debugPrint('[ConversationService] clearChatForMe backend error: $e');
    }
  }

  /// Permanently clear conversation messages for all members (owner/admin)
  Future<void> clearChatForAll(String conversationId) async {
    final effectiveConvId = _tempToRealConvMap[conversationId] ?? conversationId;

    _inMemoryMessages[conversationId] = [];
    if (effectiveConvId != conversationId) {
      _inMemoryMessages[effectiveConvId] = [];
    }
    await LocalDatabase.instance.clearMessages(conversationId);
    if (effectiveConvId != conversationId) {
      await LocalDatabase.instance.clearMessages(effectiveConvId);
    }

    final nowIso = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('laju_chat_cleared_at_$conversationId', nowIso);
    if (effectiveConvId != conversationId) {
      await prefs.setString('laju_chat_cleared_at_$effectiveConvId', nowIso);
    }

    final currentList = inMemoryConversations ?? conversationsNotifier.value;
    final idx = currentList.indexWhere((c) => c.id == conversationId || c.id == effectiveConvId);
    if (idx != -1) {
      final old = currentList[idx];
      final updated = old.copyWith(
        lastMessage: '',
        unreadCount: 0,
      );
      currentList[idx] = updated;
      inMemoryConversations = List.from(currentList);
      conversationsNotifier.value = List.from(currentList);
      await LocalDatabase.instance.upsertConversations([updated]);
    }

    _realtimePurgedController.add(conversationId);
    if (effectiveConvId != conversationId) {
      _realtimePurgedController.add(effectiveConvId);
    }

    try {
      await ApiClient.instance.post(
        ApiEndpoints.conversationClearAll(effectiveConvId),
      );
    } catch (e) {
      debugPrint('[ConversationService] clearChatForAll backend error: $e');
    }
  }

  /// Backward-compatible alias
  Future<void> clearConversationMessages(String conversationId) => clearChatForMe(conversationId);
}

