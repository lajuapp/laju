import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import 'active_call_screen.dart';
import 'group_call_picker_screen.dart';
import '../../../settings/domain/account_controller.dart';
import '../../../settings/presentation/screens/my_qr_code_screen.dart';

class CallContactItem {
  final String id;
  final String name;
  final String status;
  final String phone;
  final String? avatarUrl;
  final bool isOnline;
  final bool isVerified;

  const CallContactItem({
    required this.id,
    required this.name,
    required this.status,
    required this.phone,
    this.avatarUrl,
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
    AccountController.instance.addListener(_loadSavedContacts);
    _loadSavedContacts();
  }

  void _loadSavedContacts() {
    final saved = AccountController.instance.savedContacts;
    if (mounted) {
      setState(() {
        _contacts = saved.map((c) => CallContactItem(
          id: c.id,
          name: (c.displayName != null && c.displayName!.isNotEmpty) ? c.displayName! : c.username,
          status: (c.about != null && c.about!.isNotEmpty) ? c.about! : 'Kontak Personal Terverifikasi',
          phone: '@${c.username}',
          avatarUrl: c.avatarUrl,
          isOnline: false,
          isVerified: c.isVerified,
        )).toList();
      });
    }
  }

  void _onSearchQueryChanged(String query) {
    setState(() {});
  }

  @override
  void dispose() {
    AccountController.instance.removeListener(_loadSavedContacts);
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
          avatarUrl: contact.avatarUrl,
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
                              '${contact.phone} • ${contact.status}',
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
              )
            else if (_contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: LajuGlassCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 20,
                  blurSigma: 16,
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
                        'Panggilan hanya dapat dilakukan ke kontak personal yang telah Anda scan demi privasi Zero-Knowledge.',
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
                    ],
                  ),
                ),
              )
            else
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
