import 'package:flutter/foundation.dart';
import 'conversation_service.dart';

class GroupMemberItem {
  final String id;
  final String name;
  final String phone;
  final String role;
  final bool isAdmin;
  final bool isOnline;

  const GroupMemberItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.isAdmin = false,
    this.isOnline = false,
  });

  GroupMemberItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    bool? isAdmin,
    bool? isOnline,
  }) {
    return GroupMemberItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      isOnline: isOnline ?? this.isOnline,
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
    this.canEditGroupInfo = true,
    this.canSendMessages = true,
    this.canAddMembers = true,
    this.requireApprovalToJoin = false,
    required List<GroupMemberItem> members,
  }) : members = List.from(members);
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
    final user = group.members.firstWhere(
      (m) => m.id == 'm-you',
      orElse: () => const GroupMemberItem(id: '', name: '', phone: '', role: ''),
    );
    return user.isAdmin;
  }

  GroupModel createGroup({
    required String name,
    required String description,
    String? avatarPath,
    required List<GroupMemberItem> members,
    int? disappearingSeconds,
    bool canEditGroupInfo = true,
    bool canSendMessages = true,
    bool canAddMembers = true,
    bool requireApprovalToJoin = false,
  }) {
    final newId = 'grp-${DateTime.now().millisecondsSinceEpoch}';

    // Current user is always owner & admin of created groups
    final initialMembers = <GroupMemberItem>[
      const GroupMemberItem(
        id: 'm-you',
        name: 'Anda',
        phone: '+62 812-0000-1111',
        role: 'Admin Grup • Owner',
        isAdmin: true,
        isOnline: true,
      ),
    ];

    for (final m in members) {
      if (m.id != 'm-you') {
        initialMembers.add(m);
      }
    }

    final newGroup = GroupModel(
      id: newId,
      name: name.trim().isEmpty ? 'New Group' : name.trim(),
      description: description.trim(),
      avatarPath: avatarPath,
      creatorId: 'm-you',
      createdAt: DateTime.now(),
      disappearingSeconds: disappearingSeconds,
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

  void updateGroupInfo(
    String groupId, {
    String? name,
    String? description,
    String? avatarPath,
  }) {
    final group = _groups[groupId];
    if (group != null) {
      if (name != null && name.trim().isNotEmpty) {
        group.name = name.trim();
      }
      if (description != null) {
        group.description = description.trim();
      }
      if (avatarPath != null) {
        group.avatarPath = avatarPath;
      }
      notifyListeners();
    }
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

  void toggleAdmin(String groupId, String memberId) {
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
      }
    }
  }

  void removeMember(String groupId, String memberId) {
    final group = _groups[groupId];
    if (group != null) {
      group.members.removeWhere((m) => m.id == memberId);
      notifyListeners();
    }
  }

  void addMembers(String groupId, List<GroupMemberItem> newMembers) {
    final group = _groups[groupId];
    if (group != null) {
      for (final m in newMembers) {
        if (!group.members.any((existing) => existing.id == m.id)) {
          group.members.add(m);
        }
      }
      notifyListeners();
    }
  }

  Future<GroupModel> createGroupAsync({
    required String name,
    required String description,
    String? avatarPath,
    required List<GroupMemberItem> members,
    int? disappearingSeconds,
    bool canEditGroupInfo = true,
    bool canSendMessages = true,
    bool canAddMembers = true,
    bool requireApprovalToJoin = false,
  }) async {
    final group = createGroup(
      name: name,
      description: description,
      avatarPath: avatarPath,
      members: members,
      disappearingSeconds: disappearingSeconds,
      canEditGroupInfo: canEditGroupInfo,
      canSendMessages: canSendMessages,
      canAddMembers: canAddMembers,
      requireApprovalToJoin: requireApprovalToJoin,
    );

    try {
      final participantIds = members
          .map((m) => m.id)
          .where((id) => id != 'm-you' && !id.startsWith('m-'))
          .toList();
      if (participantIds.isNotEmpty) {
        await ConversationService.instance.createGroupConversation(
          title: name,
          participantUserIds: participantIds,
          description: description,
        );
      }
    } catch (_) {
      // Graceful fallback
    }

    return group;
  }
}

