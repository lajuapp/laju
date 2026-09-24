import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/core.dart';
import '../domain/models/conversation_model.dart';
import '../../messaging/domain/models/message_model.dart';
import '../../messaging/presentation/screens/chat_screen.dart';
import '../../settings/domain/privacy_controller.dart';

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
  ConversationService._();
  static final ConversationService instance = ConversationService._();

  /// Current conversation screen open by user to prevent banner popup for active chat
  String? currentActiveConversationId;

  bool _isInitialSyncComplete = false;
  final Set<String> _seenMessageIds = {};

  /// In-memory cache for TanStack Query-style instantaneous hydration
  List<ConversationModel>? inMemoryConversations;
  final ValueNotifier<List<ConversationModel>> conversationsNotifier = ValueNotifier<List<ConversationModel>>([]);
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
    }
  }

  /// Active typing indicators per conversation ID (true if remote participant is typing)
  final ValueNotifier<Map<String, bool>> typingStatusNotifier = ValueNotifier({});

  /// Update remote typing indicator state (received from backend sync)
  void setTyping(String conversationId, bool isTyping) {
    final current = Map<String, bool>.from(typingStatusNotifier.value);
    if (isTyping) {
      current[conversationId] = true;
    } else {
      current.remove(conversationId);
    }
    typingStatusNotifier.value = current;
  }

  /// Inform backend of current user's typing activity so the other party sees it
  Future<void> sendTypingStatus(String conversationId, bool isTyping) async {
    try {
      await ApiClient.instance.post(
        ApiEndpoints.conversationTyping(conversationId),
        body: {'isTyping': isTyping},
      );
    } catch (_) {
      // Ignored non-critical broadcast
    }
  }

  /// Search users in the backend directory for new chats or group members
  Future<List<UserDirectoryItem>> searchUsers(String query) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.users,
        queryParams: {'q': query.trim()},
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

          final msgs = item['messages'] as List?;
          if (msgs != null && msgs.isNotEmpty) {
            final latest = msgs[0];
            final latestMsgId = latest['id'] as String?;
            final senderId = latest['senderUserId'] as String?;

            if (latestMsgId != null && senderId != null && senderId != currentUserId) {
              if (!_seenMessageIds.contains(latestMsgId)) {
                _seenMessageIds.add(latestMsgId);

                // If initial sync is complete and user is not currently in this chat, trigger notification!
                final isConvMuted = cachedMap[convId]?.isMuted ?? false;
                if (_isInitialSyncComplete && currentActiveConversationId != convId && !isConvMuted) {
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
                      if (msgType == 'document') {
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
                  } else if (preview.startsWith('data:') || preview.startsWith('📄')) {
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
            } else if (latestMsgId != null) {
              _seenMessageIds.add(latestMsgId);
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

          if (title.isEmpty) {
            title = isGroup ? 'Group Chat' : 'Direct Chat';
          }

          final lastMsgRaw = (item['messages'] is List && (item['messages'] as List).isNotEmpty)
              ? item['messages'][0]['ciphertext'] ?? 'Encrypted Message'
              : 'No messages yet';
          String lastMsg = lastMsgRaw;
          if (lastMsg.startsWith('{') && (lastMsg.contains('"media"') || lastMsg.contains('"type"'))) {
            try {
              final parsed = jsonDecode(lastMsg);
              final msgType = parsed['type'] as String?;
              final cap = (parsed['caption'] ?? '') as String;
              if (msgType == 'audio') {
                lastMsg = 'Pesan Suara';
              } else if (msgType == 'sticker') {
                lastMsg = '💟 Stiker';
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
          final unreadCount = old?.unreadCount ?? 0;

          return ConversationModel(
            id: convId,
            title: title,
            lastMessage: lastMsg,
            lastMessageTime: DateHelper.parseUtc(item['updatedAt']),
            unreadCount: unreadCount,
            isGroup: isGroup,
            isOnline: true,
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
              if (!conv.isMuted) {
                PushNotificationService.showMessageNotification(
                  conversationId: conv.id,
                  title: conv.title,
                  message: conv.lastMessage,
                );
              }
            }
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
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversations,
        body: {
          'type': 'PERSONAL',
          'participantUserIds': [otherUserId],
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        return response.rawJson['id'];
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
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversations,
        body: {
          'type': 'GROUP',
          'title': title,
          'participantUserIds': participantUserIds,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final convId = response.rawJson['id'];
        if (description != null && description.isNotEmpty && convId != null) {
          await updateGroup(conversationId: convId, description: description);
        }
        return convId;
      }
    } catch (e) {
      debugPrint('[ConversationService] createGroupConversation error: $e');
    }
    return null;
  }

  /// Update group info (title, description, permissions)
  Future<bool> updateGroup({
    required String conversationId,
    String? title,
    String? description,
    Map<String, dynamic>? permissions,
  }) async {
    try {
      final response = await ApiClient.instance.patch(
        ApiEndpoints.conversationById(conversationId),
        body: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (permissions != null) 'permissions': permissions,
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
  Future<bool> leaveGroup(String conversationId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationLeave(conversationId),
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] leaveGroup error: $e');
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
    if (cached.isNotEmpty) {
      updateMemoryMessages(conversationId, cached);
    }
    return cached;
  }

  /// Fetch message history for a conversation
  Future<List<MessageModel>> fetchMessages(String conversationId, {int limit = 50, int? cursor}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (cursor != null) 'cursor': cursor.toString(),
      };

      final response = await ApiClient.instance.get(
        ApiEndpoints.conversationMessages(conversationId),
        queryParams: queryParams,
      );

      if (response.isSuccess && response.rawJson is Map) {
        if (response.rawJson.containsKey('isTyping')) {
          setTyping(conversationId, response.rawJson['isTyping'] == true);
        }

        final messagesList = response.rawJson['messages'];
        if (messagesList is List) {
          final currentUserId = ApiClient.instance.userId;
          final messages = messagesList.map((m) {
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
                    attName = 'Foto.jpg';
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
                  } else if (parsed['type'] == 'location') {
                    contentType = MessageContentType.location;
                    attName = (parsed['name'] ?? 'Lokasi') as String;
                    attSize = (parsed['address'] ?? '') as String;
                    contentText = rawCiphertext;
                  } else if (parsed['type'] == 'sticker') {
                    contentType = MessageContentType.sticker;
                    attName = (parsed['stickerId'] ?? 'cat_thumbs_up') as String;
                    mediaData = parsed['assetPath'] as String? ?? parsed['media'] as String?;
                    contentText = (parsed['caption'] ?? '') as String;
                  } else if (parsed['type'] == 'reply') {
                    contentText = (parsed['text'] ?? '') as String;
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
                contentText = ''; // No generic description
              } else if (msgType == 'AUDIO' || rawCiphertext.startsWith('data:audio')) {
                contentType = MessageContentType.voiceNote;
                mediaData = rawCiphertext;
                attName = 'Voice Note';
                contentText = 'Pesan Suara';
                attSize = '0:00';
              } else if (msgType == 'DOCUMENT' || rawCiphertext.startsWith('data:') || rawCiphertext.startsWith('📄')) {
                contentType = MessageContentType.attachment;
                mediaData = rawCiphertext.startsWith('data:') ? rawCiphertext : null;
                attName = 'Dokumen';
                contentText = '';
              } else if (msgType == 'LOCATION' || rawCiphertext.contains('"type":"location"') || rawCiphertext.contains('"type": "location"')) {
                contentType = MessageContentType.location;
                contentText = rawCiphertext;
              } else if (msgType == 'ATTACHMENT') {
                contentType = MessageContentType.attachment;
                if (rawCiphertext.startsWith('{')) {
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

            return MessageModel(
              id: m['id'],
              clientMessageId: m['clientMessageId'] as String?,
              conversationId: conversationId,
              senderName: isOutgoing ? 'You' : (m['senderUser']?['username'] ?? 'Contact'),
              content: contentText,
              attachmentPath: mediaData,
              attachmentName: attName,
              attachmentSize: attSize,
              contentType: contentType,
              timestamp: DateHelper.parseUtc(m['createdAt']),
              isOutgoing: isOutgoing,
              status: MessageDeliveryStatus.delivered,
              replyTo: parsedReplyTo,
              reactions: reactionsList,
            );
          }).toList();

          final deduplicated = MessageModel.deduplicate(messages);
          // Persist to local cache and memory cache
          updateMemoryMessages(conversationId, deduplicated);
          LocalDatabase.instance.upsertMessages(conversationId, deduplicated);
          return deduplicated;
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchMessages error: $e');
    }
    return [];
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
    } else if (attachmentPath != null && (type == 'IMAGE' || type == 'AUDIO' || type == 'DOCUMENT')) {
      try {
        String effectivePath = attachmentPath;
        if (type == 'IMAGE') {
          effectivePath = await DeviceMediaService.compressImage(attachmentPath);
        }
        final file = File(effectivePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = type == 'IMAGE'
              ? 'image/jpeg'
              : (type == 'AUDIO' ? 'audio/m4a' : 'application/octet-stream');
          if (type == 'IMAGE') {
            payloadCiphertext = jsonEncode({
              'type': 'image',
              'media': 'data:$mime;base64,$b64',
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
      final backendMessageType = (type == 'IMAGE' || type == 'AUDIO' || type == 'DOCUMENT' || type == 'ATTACHMENT' || type == 'STICKER')
          ? 'ATTACHMENT'
          : (type == 'LOCATION' ? 'LOCATION' : 'TEXT');

      final convList = inMemoryConversations ?? conversationsNotifier.value;
      final convMatch = convList.where((c) => c.id == conversationId).toList();
      final effectiveDisappearingSeconds = (convMatch.isNotEmpty && convMatch.first.disappearingSeconds != null)
          ? convMatch.first.disappearingSeconds
          : PrivacyController.instance.disappearingSeconds;

      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationMessages(conversationId),
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
        final confirmedMsg = MessageModel(
          id: confirmedId,
          clientMessageId: id,
          conversationId: conversationId,
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
                  : (type == 'IMAGE' || type == 'DOCUMENT'
                      ? MessageContentType.attachment
                      : (type == 'LOCATION' ? MessageContentType.location : MessageContentType.text))),
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MessageDeliveryStatus.sent,
          isDisappearing: effectiveDisappearingSeconds != null && effectiveDisappearingSeconds > 0,
          remainingSeconds: effectiveDisappearingSeconds,
        );

        // Replace optimistic message in SQLite and update status
        await LocalDatabase.instance.replaceOptimisticMessage(id, confirmedMsg);

        // Update in-memory messages if present
        final currentMemory = _inMemoryMessages[conversationId];
        if (currentMemory != null) {
          final updatedMemory = List<MessageModel>.from(currentMemory);
          final idx = updatedMemory.indexWhere((msg) => msg.id == id || msg.clientMessageId == id);
          if (idx != -1) {
            updatedMemory[idx] = confirmedMsg;
          } else {
            updatedMemory.add(confirmedMsg);
          }
          _inMemoryMessages[conversationId] = MessageModel.deduplicate(updatedMemory);
        }

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
                  : (type == 'LOCATION' ? MessageContentType.location : MessageContentType.text))),
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

  /// Delete a message for everyone
  Future<bool> deleteMessage(String messageId) async {
    try {
      final response = await ApiClient.instance.delete(
        ApiEndpoints.messageById(messageId),
      );
      await LocalDatabase.instance.deleteMessage(messageId);
      return response.isSuccess;
    } catch (e) {
      debugPrint('[ConversationService] deleteMessage error: $e');
      await LocalDatabase.instance.deleteMessage(messageId);
      return false;
    }
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
}

