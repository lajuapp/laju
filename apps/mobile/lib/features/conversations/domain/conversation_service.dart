import 'dart:convert';
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

  /// Fetch conversations for the current authenticated user
  Future<List<ConversationModel>> fetchConversations() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.conversations);

      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        return list.map((item) {
          final isGroup = item['type'] == 'GROUP';
          final title = item['title'] ?? (isGroup ? 'Group Chat' : 'Direct Chat');
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
          return messagesList.map((m) {
            final isOutgoing = m['senderUserId'] == currentUserId;
            return MessageModel(
              id: m['id'],
              conversationId: conversationId,
              senderName: isOutgoing ? 'You' : (m['senderUser']?['username'] ?? 'Contact'),
              content: m['ciphertext'] ?? '',
              timestamp: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
              isOutgoing: isOutgoing,
              status: MessageDeliveryStatus.delivered,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('[ConversationService] fetchMessages error: $e');
    }
    return [];
  }

  /// Send message to conversation
  Future<MessageModel?> sendMessage({
    required String conversationId,
    required String text,
    String? clientMessageId,
  }) async {
    try {
      final id = clientMessageId ?? 'msg-${DateTime.now().millisecondsSinceEpoch}';
      final response = await ApiClient.instance.post(
        ApiEndpoints.conversationMessages(conversationId),
        body: {
          'clientMessageId': id,
          'ciphertext': text,
          'nonce': base64Encode(List.generate(12, (i) => i)),
          'messageType': 'TEXT',
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final m = response.rawJson;
        return MessageModel(
          id: m['id'] ?? id,
          conversationId: conversationId,
          senderName: 'You',
          content: text,
          timestamp: DateTime.now(),
          isOutgoing: true,
          status: MessageDeliveryStatus.sent,
        );
      }
    } catch (e) {
      debugPrint('[ConversationService] sendMessage error: $e');
    }

    // Fallback: return local message model
    return MessageModel(
      id: clientMessageId ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderName: 'You',
      content: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageDeliveryStatus.sent,
    );
  }
}
