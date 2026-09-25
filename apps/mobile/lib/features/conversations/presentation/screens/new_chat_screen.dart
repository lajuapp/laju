import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../domain/conversation_service.dart';
import 'create_group_screen.dart';
import '../../../settings/presentation/screens/my_qr_code_screen.dart';

class ContactItem {
  final String id;
  final String name;
  final String status;
  final String phone;
  final bool isVerified;
  final bool isOnline;
  final String? avatarUrl;

  const ContactItem({
    required this.id,
    required this.name,
    required this.status,
    required this.phone,
    this.isVerified = true,
    this.isOnline = false,
    this.avatarUrl,
  });
}

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<ContactItem> _contacts = [];

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
        _contacts = results.map((u) => ContactItem(
          id: u.id,
          name: u.username,
          status: u.status ?? 'Pengguna Terverifikasi LAJU',
          phone: '@${u.username}',
          isVerified: true,
          isOnline: true,
          avatarUrl: u.avatarUrl,
        )).toList();
        _isSearching = false;
      });
    }
  }

  List<ContactItem> get _filteredContacts {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.status.toLowerCase().contains(q) ||
            c.phone.contains(q))
        .toList();
  }

  void _onSearchQueryChanged(String query) async {
    final results = await ConversationService.instance.searchUsers(query.trim());
    if (mounted) {
      setState(() {
        _contacts = results.map((u) => ContactItem(
          id: u.id,
          name: u.username,
          status: u.status ?? 'Pengguna Terverifikasi LAJU',
          phone: '@${u.username}',
          isVerified: true,
          isOnline: true,
          avatarUrl: u.avatarUrl,
        )).toList();
      });
    }
  }

  void _openChatWith(ContactItem contact) async {
    String convId = 'conv-${contact.id}';
    try {
      final backendId = await ConversationService.instance.createPersonalConversation(contact.id);
      if (backendId != null) {
        convId = backendId;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: convId,
          title: contact.name,
          isGroup: false,
          avatarUrl: contact.avatarUrl,
          contactUserId: contact.id,
          contactPhone: contact.phone,
          contactAbout: contact.status,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0.5,
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
                  hintText: 'Search name or number...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF), fontSize: 15),
                ),
                onChanged: _onSearchQueryChanged,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select contact',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${_contacts.length} contacts',
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
          PopupMenuButton<String>(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF374151)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'invite', child: Text('Invite a friend')),
              PopupMenuItem(value: 'contacts', child: Text('Contacts')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'help', child: Text('Help')),
            ],
            onSelected: (val) {
              LajuToast.info(context, 'Option $val selected');
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          if (!_isSearching) ...[
            const SizedBox(height: 8),
            // Create Group
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: Text(
                'Create Group',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              subtitle: Text(
                'New encrypted group conversation',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                );
              },
            ),

            // Create Chat / New Contact
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              title: Text(
                'Create Chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              subtitle: Text(
                'Start secret direct conversation',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryDark, size: 22),
                tooltip: 'Scan QR to add',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyQrCodeScreen(initialTabIndex: 1),
                    ),
                  );
                },
              ),
              onTap: () {
                LajuToast.info(context, 'Select a contact below to start chat');
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
            ),

            // Section Header: Contacts on LAJU
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Contacts on LAJU',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],

          // Contacts List
          ...contacts.map((contact) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: ModernAvatar(
                name: contact.name,
                imagePath: contact.avatarUrl,
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
                contact.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                ),
              ),
              onTap: () => _openChatWith(contact),
            );
          }),

          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No contacts found',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
