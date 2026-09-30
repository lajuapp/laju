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
  final bool isOnline;
  final String? avatarUrl;

  const GroupMemberItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isAdmin = false,
    this.isOnline = false,
    this.avatarUrl,
  });

  GroupMemberItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    bool? isAdmin,
    bool? isOnline,
    String? avatarUrl,
  }) {
    return GroupMemberItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
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

  Future<void> updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
    String? avatarPath,
  }) async {
    final group = _groups[groupId];
    String? permanentAvatar = avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty && !avatarPath.startsWith('http://') && !avatarPath.startsWith('https://')) {
      permanentAvatar = await DeviceMediaService.savePermanentAvatar(avatarPath);
    }

    if (group != null) {
      if (name != null && name.trim().isNotEmpty) {
        group.name = name.trim();
      }
      if (description != null) {
        group.description = description.trim();
      }
      if (permanentAvatar != null) {
        group.avatarPath = permanentAvatar.isEmpty ? null : permanentAvatar;
      }
      notifyListeners();
    }

    try {
      final cachedConv = await LocalDatabase.instance.getConversation(groupId);
      if (cachedConv != null) {
        final updated = cachedConv.copyWith(
          title: name?.trim().isNotEmpty == true ? name!.trim() : cachedConv.title,
          avatarUrl: permanentAvatar != null ? (permanentAvatar.isEmpty ? null : permanentAvatar) : cachedConv.avatarUrl,
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
      avatarUrl: permanentAvatar,
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
              final user = m['user'] as Map?;
              final uId = (m['userId'] ?? user?['id'] ?? '').toString();
              final isCurrentUser = uId == curUserId;
              final role = (m['role'] ?? 'MEMBER').toString();
              final isAdmin = role == 'OWNER' || role == 'ADMIN';

              groupMembers.add(GroupMemberItem(
                id: uId,
                name: isCurrentUser ? 'Anda' : (user?['username'] ?? 'User'),
                phone: (user?['phoneNumber'] ?? '').toString(),
                role: role == 'OWNER' ? 'Admin Grup • Owner' : (isAdmin ? 'Admin Grup' : 'Anggota'),
                isAdmin: isAdmin,
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
    if (avatarPath != null && avatarPath.isNotEmpty && !avatarPath.startsWith('http://') && !avatarPath.startsWith('https://')) {
      try {
        permanentAvatar = await DeviceMediaService.savePermanentAvatar(avatarPath);
      } catch (_) {}
    }

    try {
      backendConvId = await ConversationService.instance.createGroupConversation(
        title: name,
        participantUserIds: participantIds,
        description: description,
        wallpaperId: wallpaperId,
        killPin: killPin,
        authorizedWipeUserIds: authorizedWipeUserIds,
        avatarUrl: permanentAvatar,
      );
    } catch (e) {
      debugPrint('[GroupController] createGroupConversation error: $e');
    }

    final newId = backendConvId ?? 'grp-${DateTime.now().millisecondsSinceEpoch}';
    final group = createGroup(
      id: newId,
      name: name,
      description: description,
      avatarPath: permanentAvatar,
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
}

