import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import 'active_call_screen.dart';
import 'group_call_picker_screen.dart';

class CallContactItem {
  final String id;
  final String name;
  final String status;
  final String phone;
  final bool isOnline;
  final bool isVerified;

  const CallContactItem({
    required this.id,
    required this.name,
    required this.status,
    required this.phone,
    this.isOnline = false,
    this.isVerified = true,
  });
}

class NewCallContactPickerScreen extends StatefulWidget {
  const NewCallContactPickerScreen({super.key});

  @override
  State<NewCallContactPickerScreen> createState() => _NewCallContactPickerScreenState();
}

class _NewCallContactPickerScreenState extends State<NewCallContactPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<CallContactItem> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialUsers();
  }

  void _loadInitialUsers() async {
    setState(() => _isSearching = true);
    final results = await ConversationService.instance.searchUsers('');
    if (mounted) {
      setState(() {
        _contacts = results.map((u) => CallContactItem(
          id: u.id,
          name: u.username,
          status: u.status ?? 'LAJU Verified User 🔒',
          phone: '@${u.username}',
          isOnline: true,
          isVerified: true,
        )).toList();
        _isSearching = false;
      });
    }
  }

  void _onSearchQueryChanged(String query) async {
    final results = await ConversationService.instance.searchUsers(query.trim());
    if (mounted) {
      setState(() {
        _contacts = results.map((u) => CallContactItem(
          id: u.id,
          name: u.username,
          status: u.status ?? 'LAJU Verified User 🔒',
          phone: '@${u.username}',
          isOnline: true,
          isVerified: true,
        )).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CallContactItem> get _filteredContacts {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.phone.contains(q) ||
            c.status.toLowerCase().contains(q))
        .toList();
  }

  void _startCall(CallContactItem contact, bool isVideo) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveCallScreen(
          contactName: contact.name,
          calleeUserId: contact.id,
          contactPhone: contact.phone,
          isVideo: isVideo,
          returnToCallsScreen: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final isDark = ThemeModeController.instance.isDarkMode(context);

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
                  hintText: 'Cari nama atau username kontak...',
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
                    context.tr('selectContactCall'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${_contacts.length} ${context.tr('contactsAvailable')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
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
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
          children: [
            if (!_isSearching) ...[
              // Panggilan Grup Baru (New Group Call)
              LajuGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 18,
                blurSigma: 16,
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.group_add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      context.tr('newGroupCall'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    subtitle: Text(
                      context.tr('newGroupCallSub'),
                      style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GroupCallPickerScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  context.tr('contactsInLaju'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],

            // Contacts card grouping
            if (contacts.isNotEmpty)
              LajuGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 20,
                blurSigma: 16,
                child: Column(
                  children: List.generate(contacts.length, (i) {
                    final contact = contacts[i];
                    final isLast = i == contacts.length - 1;

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
                            leading: ModernAvatar(
                              name: contact.name,
                              radius: 22,
                              isOnline: contact.isOnline,
                              isVerified: contact.isVerified,
                            ),
                            title: Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              '@${contact.name} • ${contact.status}',
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
                                  onPressed: () => _startCall(contact, false),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 24),
                                  tooltip: context.tr('videoCall'),
                                  onPressed: () => _startCall(contact, true),
                                ),
                              ],
                            ),
                            onTap: () => _startCall(contact, false),
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
