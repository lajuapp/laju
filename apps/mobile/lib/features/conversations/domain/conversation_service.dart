import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/core.dart';
import '../domain/models/conversation_model.dart';
import '../../messaging/domain/models/message_model.dart';

class UserDirectoryItem {
  final String id;
  final String username;
  final String? email;
  final String? phoneNumber;
  final String? status;

  const UserDirectoryItem({
    required this.id,
    required this.username,
    this.email,
    this.phoneNumber,
    this.status,
  });

  factory UserDirectoryItem.fromJson(Map<String, dynamic> json) {
    return UserDirectoryItem(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      status: json['status'],
    );
  }
}

class ConversationService {
  ConversationService._();
  static final ConversationService instance = ConversationService._();

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

  /// Return conversations from local SQLite cache (offline-safe, instant).
  Future<List<ConversationModel>> getConversationsFromCache() {
    return LocalDatabase.instance.getConversations();
  }

  /// Fetch conversations for the current authenticated user
  Future<List<ConversationModel>> fetchConversations() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.conversations);

      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final currentUserId = ApiClient.instance.userId;
        final conversations = list.map((item) {
          final isGroup = item['type'] == 'GROUP';
          String title = item['title'] ?? '';
          if (title.isEmpty) {
            if (isGroup) {
              title = 'Group Chat';
            } else {
              final members = item['members'];
              if (members is List) {
                final otherMember = members.firstWhere(
                  (m) => m is Map && m['userId'] != currentUserId,
                  orElse: () => null,
                );
                if (otherMember != null && otherMember['user'] is Map) {
                  title = otherMember['user']['username'] ?? '';
                }
              }
              if (title.isEmpty) title = 'Direct Chat';
            }
          }
          final lastMsg = (item['messages'] is List && (item['messages'] as List).isNotEmpty)
              ? item['messages'][0]['ciphertext'] ?? 'Encrypted Message'
              : 'No messages yet';

          return ConversationModel(
            id: item['id'],
            title: title,
            lastMessage: lastMsg,
            lastMessageTime: DateTime.tryParse(item['updatedAt'] ?? '') ?? DateTime.now(),
            unreadCount: 0,
            isGroup: isGroup,
            isOnline: true,
            isKeyVerified: true,
          );
        }).toList();

        // Persist to local cache
        LocalDatabase.instance.upsertConversations(conversations);
        return conversations;
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchConversations error: $e');
    }
    return [];
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
  Future<List<MessageModel>> getMessagesFromCache(String conversationId) {
    return LocalDatabase.instance.getMessages(conversationId);
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

            if (msgType == 'IMAGE' || rawCiphertext.startsWith('data:image')) {
              contentType = MessageContentType.attachment;
              mediaData = rawCiphertext;
              attName = 'Foto.jpg';
              contentText = '📷 Foto';
            } else if (msgType == 'AUDIO' || rawCiphertext.startsWith('data:audio')) {
              contentType = MessageContentType.voiceNote;
              mediaData = rawCiphertext;
              attName = 'Voice Note';
              contentText = '🎤 Pesan Suara';
              attSize = '0:15';
            } else if (msgType == 'DOCUMENT') {
              contentType = MessageContentType.attachment;
              attName = 'Dokumen';
              contentText = rawCiphertext.startsWith('📄') ? rawCiphertext : '📄 Berkas Dokumen';
            }

            return MessageModel(
              id: m['id'],
              conversationId: conversationId,
              senderName: isOutgoing ? 'You' : (m['senderUser']?['username'] ?? 'Contact'),
              content: contentText,
              attachmentPath: mediaData,
              attachmentName: attName,
              attachmentSize: attSize,
              contentType: contentType,
              timestamp: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
              isOutgoing: isOutgoing,
              status: MessageDeliveryStatus.delivered,
              reactions: reactionsList,
            );
          }).toList();

          // Persist to local cache
          LocalDatabase.instance.upsertMessages(conversationId, messages);
          return messages;
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchMessages error: $e');
    }
    return [];
  }

  /// Send message to conversation (supports text, images, audio voice notes, and documents)
  Future<MessageModel?> sendMessage({
    required String conversationId,
    required String text,
    String? clientMessageId,
    String? messageType, // 'TEXT', 'IMAGE', 'AUDIO', 'DOCUMENT'
    String? attachmentPath,
    String? attachmentName,
    String? attachmentSize,
  }) async {
    final id = clientMessageId ?? 'msg-${DateTime.now().millisecondsSinceEpoch}';
    final type = messageType ?? 'TEXT';
    String payloadCiphertext = text;

    // Convert local media files to base64 data URI for instant cross-device transfer
    if (attachmentPath != null && (type == 'IMAGE' || type == 'AUDIO' || type == 'DOCUMENT')) {
      try {
        final file = File(attachmentPath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final b64 = base64Encode(bytes);
          final mime = type == 'IMAGE'
              ? 'image/jpeg'
              : (type == 'AUDIO' ? 'audio/m4a' : 'application/octet-stream');
          payloadCiphertext = 'data:$mime;base64,$b64';
        }
      } catch (_) {}
    }

    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationMessages(conversationId),
        body: {
          'clientMessageId': id,
          'ciphertext': payloadCiphertext,
          'nonce': base64Encode(List.generate(12, (i) => i)),
          'messageType': type,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final m = response.rawJson;
        final confirmedId = m['id'] ?? id;
        LocalDatabase.instance.updateMessageStatus(id, MessageDeliveryStatus.sent);
        return MessageModel(
          id: confirmedId,
          conversationId: conversationId,
          senderName: 'You',
          content: text,
          attachmentPath: attachmentPath,
          attachmentName: attachmentName,
          attachmentSize: attachmentSize,
          contentType: type == 'AUDIO'
              ? MessageContentType.voiceNote
              : (type == 'IMAGE' || type == 'DOCUMENT' ? MessageContentType.attachment : MessageContentType.text),
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MessageDeliveryStatus.sent,
        );
      }
    } catch (e) {
      debugPrint('[ConversationService] sendMessage error: $e');
      LocalDatabase.instance.updateMessageStatus(id, MessageDeliveryStatus.failed);
    }

    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderName: 'You',
      content: text,
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      contentType: type == 'AUDIO'
          ? MessageContentType.voiceNote
          : (type == 'IMAGE' || type == 'DOCUMENT' ? MessageContentType.attachment : MessageContentType.text),
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageDeliveryStatus.failed,
    );
  }

  /// Mark message as read on backend (Read Receipts / Blue Ticks)
  Future<void> markMessageRead(String messageId) async {
    try {
      await ApiClient.instance.post(ApiEndpoints.messageRead(messageId));
    } catch (_) {}
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

