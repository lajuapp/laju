import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/group_controller.dart';
import '../../../conversations/domain/conversation_service.dart';
import 'active_group_call_screen.dart';

class GroupCallItem {
  final String id;
  final String name;
  final String membersInfo;
  final String description;
  final List<String> members;
  final List<String> memberIds;

  const GroupCallItem({
    required this.id,
    required this.name,
    required this.membersInfo,
    required this.description,
    this.members = const [],
    this.memberIds = const [],
  });
}

class GroupCallContactItem {
  final String id;
  final String name;
  final String phone;
  final String? avatarUrl;
  final bool isOnline;

  const GroupCallContactItem({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.isOnline = false,
  });
}

class GroupCallPickerScreen extends StatefulWidget {
  const GroupCallPickerScreen({super.key});

  @override
  State<GroupCallPickerScreen> createState() => _GroupCallPickerScreenState();
}

class _GroupCallPickerScreenState extends State<GroupCallPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Set<String> _selectedContactIds = {};
  List<GroupCallContactItem> _availableContacts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  void _loadInitialUsers() async {
    final results = await ConversationService.instance.searchUsers('');
    if (mounted) {
      setState(() {
        _availableContacts = results.map((u) => GroupCallContactItem(
          id: u.id,
          name: u.username,
          phone: '@${u.username}',
          avatarUrl: u.avatarUrl,
          isOnline: true,
        )).toList();
      });
    }
  }

  void _onSearchQueryChanged(String query) async {
    final results = await ConversationService.instance.searchUsers(query.trim());
    if (mounted) {
      setState(() {
        _availableContacts = results.map((u) => GroupCallContactItem(
          id: u.id,
          name: u.username,
          phone: '@${u.username}',
          avatarUrl: u.avatarUrl,
          isOnline: true,
        )).toList();
      });
    }
  }

  List<GroupCallItem> get _existingGroups {
    final curUserId = ApiClient.instance.userId;
    return GroupController.instance.allGroups.map((g) {
      final otherMembers = g.members
          .where((m) => m.id != 'm-you' && (curUserId == null || m.id != curUserId))
          .toList();
      return GroupCallItem(
        id: g.id,
        name: g.name,
        membersInfo: '${otherMembers.length} anggota',
        description: g.description,
        members: otherMembers.map((m) => m.name).toList(),
        memberIds: otherMembers.map((m) => m.id).toList(),
      );
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startGroupCall(
    String name,
    List<String> participants,
    bool isVideo, {
    String? conversationId,
    List<String>? participantIds,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveGroupCallScreen(
          groupName: name,
          initialParticipants: participants,
          initialParticipantIds: participantIds,
          isVideo: isVideo,
          conversationId: conversationId,
          returnToCallsScreen: true,
        ),
      ),
    );
  }

  void _startCustomGroupCall(bool isVideo) {
    final selectedContacts = _availableContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();
    final names = selectedContacts.map((c) => c.name).toList();
    final ids = selectedContacts.map((c) => c.id).toList();

    final groupName = names.length <= 2
        ? names.join(' & ')
        : '${names.first} + ${names.length - 1} lainnya';

    _startGroupCall(groupName, names, isVideo, participantIds: ids);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final searchQuery = _searchController.text;

    final filteredGroups = searchQuery.isEmpty
        ? _existingGroups
        : _existingGroups.where((g) => g.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    final query = searchQuery.toLowerCase();
    final filteredContacts = query.isEmpty
        ? _availableContacts
        : _availableContacts.where((c) => c.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white : const Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: context.tr('search'),
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF), fontSize: 15),
                ),
                onChanged: (val) {
                  setState(() {});
                  _onSearchQueryChanged(val);
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('newGroupCall'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    _selectedContactIds.isEmpty
                        ? context.tr('chooseFromGroups')
                        : '${_selectedContactIds.length} ${context.tr('contactsSelected')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedContactIds.isEmpty
                          ? (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280))
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      floatingActionButton: _selectedContactIds.isNotEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fab_custom_voice_call',
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  onPressed: () => _startCustomGroupCall(false),
                  icon: const Icon(Icons.call_rounded, color: Colors.black),
                  label: Text(
                    '${context.tr('voiceCall')} (${_selectedContactIds.length})',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'fab_custom_video_call',
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  onPressed: () => _startCustomGroupCall(true),
                  child: const Icon(Icons.videocam_rounded, color: Colors.black, size: 20),
                ),
              ],
            )
          : null,
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
          children: [
            // Section 1: Existing Groups
            if (filteredGroups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('chooseFromGroups'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              LajuGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 20,
                blurSigma: 16,
                child: Column(
                  children: List.generate(filteredGroups.length, (i) {
                    final grp = filteredGroups[i];
                    final isLast = i == filteredGroups.length - 1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: i == 0 ? const Radius.circular(20) : Radius.zero,
                                bottom: isLast ? const Radius.circular(20) : Radius.zero,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: const Center(
                                child: Icon(Icons.groups_rounded, color: AppColors.primary, size: 24),
                              ),
                            ),
                            title: Text(
                              grp.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              '${grp.membersInfo} • ${grp.description}',
                              style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
                                  tooltip: context.tr('voiceCall'),
                                  onPressed: () => _startGroupCall(grp.name, grp.members, false, conversationId: grp.id, participantIds: grp.memberIds),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 24),
                                  tooltip: context.tr('videoCall'),
                                  onPressed: () => _startGroupCall(grp.name, grp.members, true, conversationId: grp.id, participantIds: grp.memberIds),
                                ),
                              ],
                            ),
                            onTap: () => _startGroupCall(grp.name, grp.members, false, conversationId: grp.id, participantIds: grp.memberIds),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 68,
                            endIndent: 16,
                            color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Section 2: Create Custom Group Call by Contact Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.cyan),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('orSelectContacts'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            if (filteredContacts.isNotEmpty)
              LajuGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 20,
                blurSigma: 16,
                child: Column(
                  children: List.generate(filteredContacts.length, (i) {
                    final contact = filteredContacts[i];
                    final isSelected = _selectedContactIds.contains(contact.id);
                    final isLast = i == filteredContacts.length - 1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: i == 0 ? const Radius.circular(20) : Radius.zero,
                                bottom: isLast ? const Radius.circular(20) : Radius.zero,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            activeColor: AppColors.primary,
                            checkColor: Colors.black,
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedContactIds.add(contact.id);
                                } else {
                                  _selectedContactIds.remove(contact.id);
                                }
                              });
                            },
                            secondary: ModernAvatar(
                              name: contact.name,
                              imagePath: contact.avatarUrl,
                              radius: 20,
                              isOnline: contact.isOnline,
                              isVerified: true,
                            ),
                            title: Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              contact.phone,
                              style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 64,
                            endIndent: 16,
                            color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
