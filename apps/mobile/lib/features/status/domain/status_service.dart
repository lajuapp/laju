import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../presentation/screens/status_view_screen.dart';
import '../presentation/screens/status_screen.dart';

class StatusService {
  StatusService._();
  static final StatusService instance = StatusService._();

  /// In-memory cache for TanStack Query-style stale-while-revalidate hydration
  List<StatusStoryItem> cachedMyStatuses = [];
  List<StatusContactGroup> cachedContactGroups = [];

  /// Create a new status story (text or image)
  Future<StatusStoryItem?> postStatus({
    required String type, // 'TEXT' or 'IMAGE'
    required String content,
    String? caption,
    Color? backgroundColor,
    String? fontStyle,
  }) async {
    try {
      String processedContent = content;

      if (type == 'IMAGE' && !content.startsWith('http') && !content.startsWith('data:image')) {
        // Read local file as base64 data URI for instant cross-device delivery
        final file = File(content);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final b64 = base64Encode(bytes);
          processedContent = 'data:image/jpeg;base64,$b64';
        }
      }

      String? hexColor;
      if (backgroundColor != null) {
        hexColor = '#${backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.status,
        body: {
          'type': type,
          'content': processedContent,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
          if (hexColor != null) 'backgroundColor': hexColor,
          if (fontStyle != null) 'fontStyle': fontStyle,
        },
      );

      if (response.isSuccess && response.rawJson is Map) {
        final data = response.rawJson as Map<String, dynamic>;
        final story = _mapStoryItem(data);
        cachedMyStatuses.insert(0, story);
        return story;
      }
    } catch (e) {
      debugPrint('[StatusService] postStatus error: $e');
    }
    return null;
  }

  /// Get active statuses posted by current user
  Future<List<StatusStoryItem>> getMyStatuses() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.statusMe);
      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final items = list.map((item) => _mapStoryItem(item as Map<String, dynamic>)).toList();
        cachedMyStatuses = items;
        return items;
      }
    } catch (e) {
      debugPrint('[StatusService] getMyStatuses error: $e');
    }
    return cachedMyStatuses;
  }

  /// Get active statuses from contacts (shared conversation members / contacts)
  Future<List<StatusContactGroup>> getContactsStatuses() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.statusContacts);
      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final groups = <StatusContactGroup>[];

        for (final item in list) {
          if (item is! Map<String, dynamic>) continue;
          final username = item['username'] ?? 'Kontak';
          final userId = (item['userId'] ?? item['id']) as String?;
          final avatarUrl = item['avatarUrl'] as String? ?? item['avatar'] as String?;
          final storiesRaw = item['stories'] as List? ?? [];
          final stories = storiesRaw
              .map((s) => _mapStoryItem(s as Map<String, dynamic>))
              .toList();

          if (stories.isEmpty) continue;

          // Check if any story is viewed
          bool allViewed = true;
          for (final s in storiesRaw) {
            final views = (s as Map<String, dynamic>)['views'] as List? ?? [];
            if (views.isEmpty) {
              allViewed = false;
              break;
            }
          }

          final lastStory = stories.last;
          groups.add(
            StatusContactGroup(
              name: username,
              userId: userId,
              avatarUrl: avatarUrl,
              time: lastStory.time,
              storyCount: stories.length,
              storyColor: lastStory.backgroundColor,
              stories: stories,
              isViewed: allViewed,
            ),
          );
        }

        cachedContactGroups = groups;
        return groups;
      }
    } catch (e) {
      debugPrint('[StatusService] getContactsStatuses error: $e');
    }
    return cachedContactGroups;
  }

  /// Mark status as viewed
  Future<void> markStatusViewed(String storyId) async {
    try {
      await ApiClient.instance.post(ApiEndpoints.statusView(storyId));
    } catch (e) {
      debugPrint('[StatusService] markStatusViewed error: $e');
    }
  }

  /// Delete a status story
  Future<bool> deleteStatus(String storyId) async {
    try {
      final response = await ApiClient.instance.delete(ApiEndpoints.statusById(storyId));
      return response.isSuccess;
    } catch (e) {
      debugPrint('[StatusService] deleteStatus error: $e');
      return false;
    }
  }

  StatusStoryItem _mapStoryItem(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final type = json['type'] as String? ?? 'TEXT';
    final content = json['content'] as String? ?? '';
    final caption = json['caption'] as String?;
    final bgHex = json['backgroundColor'] as String?;
    final createdAtStr = json['createdAt'] as String?;

    Color bgColor = const Color(0xFF0F3E37);
    if (bgHex != null && bgHex.isNotEmpty) {
      try {
        final cleanHex = bgHex.replaceAll('#', '');
        if (cleanHex.length == 6) {
          bgColor = Color(int.parse('FF$cleanHex', radix: 16));
        } else if (cleanHex.length == 8) {
          bgColor = Color(int.parse(cleanHex, radix: 16));
        }
      } catch (_) {}
    }

    String timeStr = 'Baru saja';
    if (createdAtStr != null) {
      try {
        final dt = DateHelper.parseUtc(createdAtStr);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeStr = 'Baru saja';
        } else if (diff.inHours < 1) {
          timeStr = '${diff.inMinutes} menit yang lalu';
        } else if (diff.inHours < 24) {
          timeStr = '${diff.inHours} jam yang lalu';
        } else {
          timeStr = 'Kemarin';
        }
      } catch (_) {}
    }

    final isPhoto = type == 'IMAGE' || type == 'VIDEO';

    return StatusStoryItem(
      id: id,
      text: isPhoto ? (caption ?? '') : content,
      time: timeStr,
      backgroundColor: bgColor,
      imageAsset: isPhoto ? content : null,
      isPhoto: isPhoto,
    );
  }
}
