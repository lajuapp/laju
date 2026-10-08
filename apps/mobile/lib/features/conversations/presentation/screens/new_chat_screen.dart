import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../domain/conversation_service.dart';
import 'create_group_screen.dart';
import '../../../settings/presentation/screens/my_qr_code_screen.dart';
import '../../../settings/domain/account_controller.dart';

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
    AccountController.instance.addListener(_loadSavedContacts);
    _loadSavedContacts();
  }

  void _loadSavedContacts() {
    final saved = AccountController.instance.savedContacts;
    if (mounted) {
      setState(() {
        _contacts = saved.map((c) => ContactItem(
          id: c.id,
          name: (c.displayName != null && c.displayName!.isNotEmpty) ? c.displayName! : c.username,
          status: (c.about != null && c.about!.isNotEmpty) ? c.about! : 'Kontak Personal Terverifikasi',
          phone: '@${c.username}',
          isVerified: c.isVerified,
          isOnline: false,
          avatarUrl: c.avatarUrl,
        )).toList();
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
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  void _onSearchQueryChanged(String query) {
    setState(() {});
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
    AccountController.instance.removeListener(_loadSavedContacts);
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
                  hintText: 'Cari nama atau username kontak...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF), fontSize: 15),
                ),
                onChanged: _onSearchQueryChanged,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesan Baru',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  Text(
                    '${_contacts.length} kontak personal',
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 23),
            tooltip: 'Pindai Kode QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyQrCodeScreen(initialTabIndex: 1),
                ),
              );
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
                'Grup Baru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              subtitle: Text(
                'Buat percakapan grup terenkripsi',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                );
              },
            ),

            // Scan QR / Tambah Kontak
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              title: Text(
                'Pindai Kode QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              subtitle: Text(
                'Scan QR teman untuk menambah kontak personal',
                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyQrCodeScreen(initialTabIndex: 1),
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
            ),

            // Section Header: Kontak Personal
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text(
                    'Kontak Personal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.lock_outline_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    'Zero-Knowledge',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
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

          // Empty state when no contacts saved
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum Ada Kontak Personal',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Untuk melindungi privasi Zero-Knowledge, LAJU tidak mengekspos direktori member secara publik. Pindai kode QR teman Anda untuk memulai obrolan terenkripsi.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text(
                        'Pindai Kode QR Teman',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyQrCodeScreen(initialTabIndex: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF374151),
                        side: BorderSide(
                          color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                        ),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_rounded, size: 20),
                      label: const Text(
                        'Bagikan Kode QR Saya',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyQrCodeScreen(initialTabIndex: 0),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          else if (contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 44,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kontak tidak ditemukan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hanya kontak personal yang telah di-scan yang dapat dicari di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
