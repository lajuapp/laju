import 'package:flutter/foundation.dart';
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
    await ConversationService.instance.updateGroup(
      conversationId: groupId,
      title: name,
      description: description,
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

        final model = GroupModel(
          id: groupId,
          name: details['title'] ?? 'Group Chat',
          description: details['description'] ?? '',
          creatorId: curUserId ?? '',
          createdAt: DateHelper.parseUtc(details['createdAt']),
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

    try {
      backendConvId = await ConversationService.instance.createGroupConversation(
        title: name,
        participantUserIds: participantIds,
        description: description,
      );
    } catch (e) {
      debugPrint('[GroupController] createGroupConversation error: $e');
    }

    final newId = backendConvId ?? 'grp-${DateTime.now().millisecondsSinceEpoch}';
    final group = createGroup(
      id: newId,
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

    return group;
  }
}

