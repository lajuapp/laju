import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/core.dart';
import '../../../../core/network/api_client.dart';
import 'conversation_service.dart';

class GroupMemberItem {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isAdmin;
  final bool isOwner;
  final bool isOnline;
  final String? avatarUrl;

  const GroupMemberItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isAdmin = false,
    this.isOwner = false,
    this.isOnline = false,
    this.avatarUrl,
  });

  GroupMemberItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    bool? isAdmin,
    bool? isOwner,
    bool? isOnline,
    String? avatarUrl,
  }) {
    return GroupMemberItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      isOwner: isOwner ?? this.isOwner,
      isOnline: isOnline ?? this.isOnline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class GroupModel {
  final String id;
  String name;
  String description;
  String? avatarPath;
  final String creatorId;
  final DateTime createdAt;
  int? disappearingSeconds;
  String? wallpaperId;
  bool hasKillPin;
  List<String> authorizedWipeUserIds;

  // Permissions
  bool canEditGroupInfo; // true: All members, false: Only admins
  bool canSendMessages; // true: All members, false: Only admins
  bool canAddMembers; // true: All members, false: Only admins
  bool requireApprovalToJoin; // true: New members must be approved by admin

  final List<GroupMemberItem> members;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.avatarPath,
    required this.creatorId,
    required this.createdAt,
    this.disappearingSeconds,
    this.wallpaperId,
    this.hasKillPin = false,
    this.authorizedWipeUserIds = const [],
    this.canEditGroupInfo = true,
    this.canSendMessages = true,
    this.canAddMembers = true,
    this.requireApprovalToJoin = false,
    required List<GroupMemberItem> members,
  }) : members = List.from(members);

  bool canUserWipe(String? userId) {
    if (!hasKillPin) return false;
    if (userId == null) return false;
    if (userId == creatorId || userId == 'm-you') return true;
    return authorizedWipeUserIds.contains(userId);
  }

  bool get isCurrentUserOwner {
    final curUserId = ApiClient.instance.userId;
    if (creatorId == curUserId || (curUserId == null && creatorId == 'm-you')) return true;
    final user = members.firstWhere(
      (m) => (curUserId != null && m.id == curUserId) || m.id == 'm-you',
      orElse: () => const GroupMemberItem(id: '', name: '', phone: '', role: ''),
    );
    return user.isOwner;
  }
}


class GroupController extends ChangeNotifier {
  static const String currentUserId = 'm-you';

  GroupController._() {
    _initializeDefaultGroups();
  }
  static final GroupController instance = GroupController._();

  final Map<String, GroupModel> _groups = {};

  void resetToDefaults() {
    _groups.clear();
    _initializeDefaultGroups();
    notifyListeners();
  }

  void _initializeDefaultGroups() {
    // No hardcoded mock groups. Groups are created dynamically by the user or fetched from backend.
  }

  List<GroupModel> get allGroups => _groups.values.toList();

  GroupModel? getGroup(String id) => _groups[id];

  final ValueNotifier<Map<String, bool>> groupMembershipNotifier = ValueNotifier({});
  final Map<String, int> _memberCounts = {};

  int? getMemberCount(String groupId) => _memberCounts[groupId] ?? _groups[groupId]?.members.length;

  void setMembership(String groupId, bool isMember) {
    final cur = Map<String, bool>.from(groupMembershipNotifier.value);
    if (cur[groupId] != isMember) {
      cur[groupId] = isMember;
      groupMembershipNotifier.value = cur;
    }
  }

  void updateGroupFromRealtime({
    required String groupId,
    String? title,
    String? description,
    String? avatarUrl,
    int? memberCount,
    bool isMember = true,
    String? role,
  }) {
    setMembership(groupId, isMember);
    if (memberCount != null) {
      _memberCounts[groupId] = memberCount;
    }
    final existing = _groups[groupId];
    if (existing != null) {
      bool changed = false;
      if (title != null && title.isNotEmpty && existing.name != title) {
        existing.name = title;
        changed = true;
      }
      if (description != null && existing.description != description) {
        existing.description = description;
        changed = true;
      }
      if (avatarUrl != null && existing.avatarPath != avatarUrl) {
        existing.avatarPath = avatarUrl;
        changed = true;
      }
      if (changed) {
        notifyListeners();
      }
    } else if (title != null && title.isNotEmpty) {
      _groups[groupId] = GroupModel(
        id: groupId,
        name: title,
        description: description ?? '',
        avatarPath: avatarUrl,
        creatorId: '',
        createdAt: DateTime.now(),
        members: [],
      );
      notifyListeners();
    }
  }

  bool isCurrentUserAdmin(String groupId) {
    final group = _groups[groupId];
    if (group == null) return false;
    final curUserId = ApiClient.instance.userId;
    final user = group.members.firstWhere(
      (m) => (curUserId != null && m.id == curUserId) || m.id == 'm-you',
      orElse: () => const GroupMemberItem(id: '', name: '', phone: '', role: ''),
    );
    return user.isAdmin;
  }

  bool isCurrentUserOwner(String groupId) {
    final group = _groups[groupId];
    if (group == null) return false;
    final curUserId = ApiClient.instance.userId;
    if (group.creatorId == curUserId || (curUserId == null && group.creatorId == 'm-you')) return true;
    final user = group.members.firstWhere(
      (m) => (curUserId != null && m.id == curUserId) || m.id == 'm-you',
      orElse: () => const GroupMemberItem(id: '', name: '', phone: '', role: ''),
    );
    return user.isOwner;
  }

  GroupModel createGroup({
    String? id,
    required String name,
    required String description,
    String? avatarPath,
    required List<GroupMemberItem> members,
    int? disappearingSeconds,
    String? wallpaperId,
    bool hasKillPin = false,
    List<String> authorizedWipeUserIds = const [],
    bool canEditGroupInfo = true,
    bool canSendMessages = true,
    bool canAddMembers = true,
    bool requireApprovalToJoin = false,
  }) {
    final newId = id ?? 'grp-${DateTime.now().millisecondsSinceEpoch}';
    final curUserId = ApiClient.instance.userId ?? 'm-you';

    // Current user is always owner & admin of created groups
    final initialMembers = <GroupMemberItem>[
      GroupMemberItem(
        id: curUserId,
        name: 'Anda',
        phone: '',
        role: 'Admin Grup • Owner',
        isAdmin: true,
        isOnline: true,
      ),
    ];

    for (final m in members) {
      if (m.id != 'm-you' && m.id != curUserId) {
        initialMembers.add(m);
      }
    }

    final newGroup = GroupModel(
      id: newId,
      name: name.trim().isEmpty ? 'New Group' : name.trim(),
      description: description.trim(),
      avatarPath: avatarPath,
      creatorId: curUserId,
      createdAt: DateTime.now(),
      disappearingSeconds: disappearingSeconds,
      wallpaperId: wallpaperId,
      hasKillPin: hasKillPin,
      authorizedWipeUserIds: authorizedWipeUserIds,
      canEditGroupInfo: canEditGroupInfo,
      canSendMessages: canSendMessages,
      canAddMembers: canAddMembers,
      requireApprovalToJoin: requireApprovalToJoin,
      members: initialMembers,
    );

    _groups[newId] = newGroup;
    notifyListeners();
    return newGroup;
  }

  /// Prepare avatar payload: uploads local file/base64 to backend storage and returns public URL
  Future<String?> _prepareAvatarPayload(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/attachments/') ||
        trimmed.startsWith('attachments/')) {
      return trimmed;
    }

    try {
      String base64String = '';
      if (trimmed.startsWith('data:')) {
        base64String = trimmed;
      } else {
        final file = File(trimmed);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          base64String = base64Encode(bytes);
        }
      }

      if (base64String.isNotEmpty) {
        final uploadResp = await ApiClient.instance.post(
          ApiEndpoints.attachmentAvatar,
          body: {
            'base64Data': base64String,
            'filename': 'group_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            'mimeType': 'image/jpeg',
          },
        );
        if (uploadResp.isSuccess && uploadResp.rawJson is Map) {
          final url = uploadResp.rawJson['url'] as String?;
          if (url != null && url.isNotEmpty) {
            return url;
          }
        }
      }
    } catch (e) {
      debugPrint('[GroupController] _prepareAvatarPayload upload error: $e');
    }
    return trimmed;
  }

  Future<void> updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
    String? avatarPath,
  }) async {
    final group = _groups[groupId];
    String? permanentAvatar = avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty && !avatarPath.startsWith('http://') && !avatarPath.startsWith('https://') && !avatarPath.startsWith('data:')) {
      permanentAvatar = await DeviceMediaService.savePermanentAvatar(avatarPath);
    }
    final avatarPayload = await _prepareAvatarPayload(permanentAvatar ?? avatarPath);

    if (group != null) {
      if (name != null && name.trim().isNotEmpty) {
        group.name = name.trim();
      }
      if (description != null) {
        group.description = description.trim();
      }
      if (avatarPayload != null) {
        group.avatarPath = avatarPayload.isEmpty ? null : (permanentAvatar ?? avatarPayload);
      }
      notifyListeners();
    }

    try {
      final cachedConv = await LocalDatabase.instance.getConversation(groupId);
      if (cachedConv != null) {
        final updated = cachedConv.copyWith(
          title: name?.trim().isNotEmpty == true ? name!.trim() : cachedConv.title,
          avatarUrl: avatarPayload != null ? (avatarPayload.isEmpty ? null : avatarPayload) : cachedConv.avatarUrl,
        );
        await LocalDatabase.instance.upsertConversations([updated]);
        final inMem = ConversationService.instance.inMemoryConversations;
        if (inMem != null) {
          final idx = inMem.indexWhere((c) => c.id == groupId);
          if (idx != -1) {
            inMem[idx] = updated;
            ConversationService.instance.conversationsNotifier.value = List.from(inMem);
          }
        }
      }
    } catch (_) {}

    await ConversationService.instance.updateGroup(
      conversationId: groupId,
      title: name,
      description: description,
      avatarUrl: avatarPayload,
    );
  }

  void updatePermissions(
    String groupId, {
    bool? canEditGroupInfo,
    bool? canSendMessages,
    bool? canAddMembers,
    bool? requireApprovalToJoin,
  }) {
    final group = _groups[groupId];
    if (group != null) {
      if (canEditGroupInfo != null) group.canEditGroupInfo = canEditGroupInfo;
      if (canSendMessages != null) group.canSendMessages = canSendMessages;
      if (canAddMembers != null) group.canAddMembers = canAddMembers;
      if (requireApprovalToJoin != null) group.requireApprovalToJoin = requireApprovalToJoin;
      notifyListeners();
    }
  }

  Future<void> toggleAdmin(String groupId, String memberId) async {
    final group = _groups[groupId];
    if (group != null) {
      final index = group.members.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        final current = group.members[index];
        final newIsAdmin = !current.isAdmin;
        group.members[index] = current.copyWith(
          isAdmin: newIsAdmin,
          role: newIsAdmin ? 'Admin Grup' : 'Anggota',
        );
        notifyListeners();
        await ConversationService.instance.changeMemberRole(groupId, memberId, newIsAdmin);
      }
    }
  }

  Future<bool> transferOwnership(String groupId, String targetMemberId) async {
    final success = await ConversationService.instance.transferGroupOwnership(groupId, targetMemberId);
    if (success) {
      await fetchGroupFromBackend(groupId);
      notifyListeners();
    }
    return success;
  }

  void setDisappearingSeconds(String groupId, int? seconds) {
    final group = _groups[groupId];
    if (group != null) {
      group.disappearingSeconds = seconds;
      notifyListeners();
    }
  }

  Future<void> removeMember(String groupId, String memberId) async {
    final group = _groups[groupId];
    if (group != null) {
      group.members.removeWhere((m) => m.id == memberId);
      notifyListeners();
      await ConversationService.instance.removeMember(groupId, memberId);
    }
  }

  Future<void> addMembers(String groupId, List<GroupMemberItem> newMembers) async {
    final group = _groups[groupId];
    if (group != null) {
      for (final m in newMembers) {
        if (!group.members.any((existing) => existing.id == m.id)) {
          group.members.add(m);
          await ConversationService.instance.addMember(groupId, m.id);
        }
      }
      notifyListeners();
    }
  }

  /// Fetch and update group details and members directly from backend
  Future<GroupModel?> fetchGroupFromBackend(String groupId) async {
    try {
      final details = await ConversationService.instance.getConversationDetails(groupId);
      if (details != null) {
        final curUserId = ApiClient.instance.userId;
        final membersList = details['members'];
        final groupMembers = <GroupMemberItem>[];

        if (membersList is List) {
          for (final m in membersList) {
            if (m is Map) {
              if (m['leftAt'] != null) continue;
              final user = m['user'] as Map?;
              final uId = (m['userId'] ?? user?['id'] ?? '').toString();
              final isCurrentUser = uId == curUserId;
              final role = (m['role'] ?? '').toString().toUpperCase();
              final isOwner = role == 'OWNER';
              final isAdmin = isOwner || role == 'ADMIN';

              groupMembers.add(GroupMemberItem(
                id: uId,
                name: isCurrentUser ? 'Anda' : (user?['username'] ?? 'User'),
                phone: (user?['phoneNumber'] ?? '').toString(),
                role: isOwner ? 'Admin Grup • Owner' : (isAdmin ? 'Admin Grup' : 'Anggota'),
                isAdmin: isAdmin,
                isOwner: isOwner,
                isOnline: true,
                avatarUrl: user?['avatarUrl'] as String?,
              ));
            }
          }
        }

        String creatorId = curUserId ?? '';
        final rawMembers = details['members'] as List?;
        if (rawMembers != null) {
          for (final m in rawMembers) {
            if (m is Map && (m['role'] == 'OWNER' || m['userId'] == details['creatorId'])) {
              creatorId = (m['userId'] ?? creatorId).toString();
              break;
            }
          }
        }

        final wallpaperId = details['wallpaperId'] as String?;
        final avatarUrl = details['avatarUrl'] as String?;
        final hasKillPin = details['hasKillPin'] == true;
        final rawAuth = details['authorizedWipeUserIds'];
        final List<String> authorizedWipeUserIds = rawAuth is List ? List<String>.from(rawAuth) : [];

        if (wallpaperId != null && wallpaperId.isNotEmpty) {
          ChatAppearanceController.instance.syncRemoteChatWallpaper(groupId, wallpaperId);
        }

        final model = GroupModel(
          id: groupId,
          name: details['title'] ?? 'Group Chat',
          description: details['description'] ?? '',
          avatarPath: avatarUrl ?? _groups[groupId]?.avatarPath,
          creatorId: creatorId,
          createdAt: DateHelper.parseUtc(details['createdAt']),
          wallpaperId: wallpaperId,
          hasKillPin: hasKillPin,
          authorizedWipeUserIds: authorizedWipeUserIds,
          members: groupMembers,
        );

        _groups[groupId] = model;
        notifyListeners();
        return model;
      }
    } catch (e) {
      debugPrint('[GroupController] fetchGroupFromBackend error: $e');
    }
    return _groups[groupId];
  }

  Future<GroupModel> createGroupAsync({
    required String name,
    required String description,
    String? avatarPath,
    required List<GroupMemberItem> members,
    int? disappearingSeconds,
    String? wallpaperId,
    String? killPin,
    List<String> authorizedWipeUserIds = const [],
    bool canEditGroupInfo = true,
    bool canSendMessages = true,
    bool canAddMembers = true,
    bool requireApprovalToJoin = false,
  }) async {
    String? backendConvId;
    final participantIds = members
        .map((m) => m.id)
        .where((id) => id != 'm-you' && !id.startsWith('m-'))
        .toList();

    String? permanentAvatar = avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty && !avatarPath.startsWith('http://') && !avatarPath.startsWith('https://') && !avatarPath.startsWith('data:')) {
      try {
        permanentAvatar = await DeviceMediaService.savePermanentAvatar(avatarPath);
      } catch (_) {}
    }
    final avatarPayload = await _prepareAvatarPayload(permanentAvatar ?? avatarPath);

    try {
      backendConvId = await ConversationService.instance.createGroupConversation(
        title: name,
        participantUserIds: participantIds,
        description: description,
        wallpaperId: wallpaperId,
        killPin: killPin,
        authorizedWipeUserIds: authorizedWipeUserIds,
        avatarUrl: avatarPayload,
      );
    } catch (e) {
      debugPrint('[GroupController] createGroupConversation error: $e');
    }

    final newId = backendConvId ?? 'grp-${DateTime.now().millisecondsSinceEpoch}';
    final group = createGroup(
      id: newId,
      name: name,
      description: description,
      avatarPath: avatarPayload ?? permanentAvatar,
      members: members,
      disappearingSeconds: disappearingSeconds,
      wallpaperId: wallpaperId,
      hasKillPin: killPin != null && killPin.trim().isNotEmpty,
      authorizedWipeUserIds: authorizedWipeUserIds,
      canEditGroupInfo: canEditGroupInfo,
      canSendMessages: canSendMessages,
      canAddMembers: canAddMembers,
      requireApprovalToJoin: requireApprovalToJoin,
    );

    return group;
  }

  /// Updates the wallpaperId for a group locally and notifies listeners
  void updateGroupWallpaper(String groupId, String? wallpaperId) {
    if (_groups.containsKey(groupId)) {
      _groups[groupId]!.wallpaperId = wallpaperId;
      notifyListeners();
    }
  }

  /// Remove group from local controller when leaving or deleting group
  void removeGroup(String groupId) {
    if (_groups.containsKey(groupId)) {
      _groups.remove(groupId);
      notifyListeners();
    }
  }
}

