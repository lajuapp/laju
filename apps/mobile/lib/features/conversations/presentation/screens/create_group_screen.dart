import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/group_controller.dart';
import '../../domain/conversation_service.dart';
import 'create_group_details_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedContactIds = {};
  String _searchQuery = '';
  List<GroupMemberItem> _availableContacts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  void _loadInitialUsers() async {
    final results = await ConversationService.instance.searchUsers('');
    if (mounted) {
      setState(() {
        _availableContacts = results.map((u) => GroupMemberItem(
          id: u.id,
          name: u.username,
          phone: (u.phoneNumber != null && u.phoneNumber!.isNotEmpty) ? u.phoneNumber! : '@${u.username}',
          role: u.status ?? 'Pengguna Terverifikasi LAJU',
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
        _availableContacts = results.map((u) => GroupMemberItem(
          id: u.id,
          name: u.username,
          phone: (u.phoneNumber != null && u.phoneNumber!.isNotEmpty) ? u.phoneNumber! : '@${u.username}',
          role: u.status ?? 'Pengguna Terverifikasi LAJU',
          avatarUrl: u.avatarUrl,
          isOnline: true,
        )).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleContact(String id) {
    setState(() {
      if (_selectedContactIds.contains(id)) {
        _selectedContactIds.remove(id);
      } else {
        _selectedContactIds.add(id);
      }
    });
  }

  void _proceedToDetails() {
    if (_selectedContactIds.isEmpty) {
      LajuToast.info(context, context.tr('selectAtLeastOneMember'));
      return;
    }

    final selected = _availableContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupDetailsScreen(selectedMembers: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? AppColors.darkBackground : Colors.white;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    final filteredContacts = _availableContacts.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    final selectedMembersList = _availableContacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('newGroup'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Text(
              _selectedContactIds.isEmpty
                  ? context.tr('addMembers')
                  : '${_selectedContactIds.length} ${context.tr('selected')}',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedContactIds.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'fab_create_group_next',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _proceedToDetails,
              child: const Icon(Icons.arrow_forward_rounded, size: 24),
            )
          : null,
      body: Column(
        children: [
          // Selected Members Horizontal Chip Bar
          if (selectedMembersList.isNotEmpty) ...[
            Container(
              height: 94,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: selectedMembersList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final member = selectedMembersList[index];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          ModernAvatar(
                            name: member.name,
                            imagePath: member.avatarUrl,
                            radius: 24,
                            isVerified: false,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _toggleContact(member.id),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : const Color(0xFF4B5563),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 58,
                        child: Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
          ],

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                  hintText: context.tr('searchContacts'),
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _onSearchQueryChanged(val);
                },
              ),
            ),
          ),

          // Contacts List
          Expanded(
            child: ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                final isSelected = _selectedContactIds.contains(contact.id);

                return ListTile(
                  onTap: () => _toggleContact(contact.id),
                  leading: ModernAvatar(
                    name: contact.name,
                    imagePath: contact.avatarUrl,
                    radius: 22,
                    isOnline: contact.isOnline,
                    isVerified: true,
                  ),
                  title: Text(
                    contact.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    contact.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                  trailing: Checkbox(
                    activeColor: AppColors.primary,
                    shape: const CircleBorder(),
                    value: isSelected,
                    onChanged: (_) => _toggleContact(contact.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
