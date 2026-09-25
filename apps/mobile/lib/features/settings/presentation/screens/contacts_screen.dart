import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../conversations/domain/models/conversation_model.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../domain/account_controller.dart';
import 'my_qr_code_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_UnifiedContact> _getUnifiedContacts(
    List<LajuContactItem> saved,
    List<ConversationModel> conversations,
  ) {
    final Map<String, _UnifiedContact> map = {};

    // 1. From explicitly saved contacts
    for (final s in saved) {
      final key = s.username.toLowerCase();
      map[key] = _UnifiedContact(
        id: s.id,
        username: s.username,
        displayName: s.displayName ?? s.username,
        avatarUrl: s.avatarUrl,
        about: s.about ?? 'Pengguna Terverifikasi LAJU',
        phoneNumber: s.phoneNumber,
        trustScore: s.trustScore,
        isVerified: s.isVerified,
        isExplicitlySaved: true,
      );
    }

    // 2. From personal conversations
    for (final c in conversations) {
      if (c.isGroup) continue;
      final key = c.title.toLowerCase();
      if (map.containsKey(key)) {
        // Enrich existing
        final existing = map[key]!;
        map[key] = existing.copyWith(
          conversationId: c.id,
          avatarUrl: existing.avatarUrl ?? c.avatarUrl,
          isOnline: c.isOnline,
          trustScore: c.participantTrustScore ?? existing.trustScore,
          about: c.participantAbout ?? existing.about,
          phoneNumber: c.participantPhone ?? existing.phoneNumber,
        );
      } else {
        final contactId = (c.participantUserId != null && c.participantUserId!.isNotEmpty && !c.participantUserId!.startsWith('conv-'))
            ? c.participantUserId!
            : (c.title.isNotEmpty ? c.title : c.id);
        map[key] = _UnifiedContact(
          id: contactId,
          username: c.title,
          displayName: c.title,
          avatarUrl: c.avatarUrl,
          about: c.participantAbout ?? 'Pengguna LAJU',
          phoneNumber: c.participantPhone,
          trustScore: c.participantTrustScore ?? 100,
          isVerified: c.isKeyVerified,
          isOnline: c.isOnline,
          conversationId: c.id,
          isExplicitlySaved: false,
        );
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    if (_searchQuery.isEmpty) return list;

    return list.where((c) {
      return c.displayName.toLowerCase().contains(_searchQuery) ||
          c.username.toLowerCase().contains(_searchQuery) ||
          (c.phoneNumber != null && c.phoneNumber!.contains(_searchQuery)) ||
          c.about.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _openChatWith(_UnifiedContact contact) async {
    String convId = contact.conversationId ?? 'conv-${contact.id}';
    if (contact.conversationId != null && !contact.conversationId!.startsWith('conv-')) {
      convId = contact.conversationId!;
    } else if (!contact.id.startsWith('conv-') && !contact.id.startsWith('grp-')) {
      try {
        final backendId = await ConversationService.instance.createPersonalConversation(contact.id);
        if (backendId != null) {
          convId = backendId;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: convId,
          title: contact.displayName,
          isGroup: false,
          avatarUrl: contact.avatarUrl,
          contactUserId: contact.id.startsWith('conv-') ? null : contact.id,
          contactPhone: contact.phoneNumber ?? '@${contact.username}',
          contactAbout: contact.about,
          contactTrustScore: contact.trustScore,
        ),
      ),
    );
  }

  void _startCall(_UnifiedContact contact, bool isVideo) {
    final calleeId = (!contact.id.startsWith('conv-') && !contact.id.startsWith('grp-'))
        ? contact.id
        : (contact.username.isNotEmpty ? contact.username : null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveCallScreen(
          contactName: contact.displayName,
          calleeUserId: calleeId,
          contactPhone: contact.phoneNumber ?? '@${contact.username}',
          avatarUrl: contact.avatarUrl,
          isVideo: isVideo,
          returnToCallsScreen: true,
        ),
      ),
    );
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LajuQrScannerScreen(
          title: 'Pindai QR Kontak',
          promptText: 'Arahkan kamera ke kode QR profil LAJU teman Anda',
        ),
      ),
    );
  }


  void _showContactDetailModal(_UnifiedContact contact) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Large Avatar
              ModernAvatar(
                name: contact.displayName,
                radius: 40,
                isVerified: contact.isVerified,
                imagePath: contact.avatarUrl,
              ),
              const SizedBox(height: 12),

              Text(
                contact.displayName,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${contact.username}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                contact.about,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // Trust & Security Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'Skor Kepercayaan: ${contact.trustScore}/100',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'E2EE Aktif',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Action Buttons Row (Chat, Audio, Video)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModalActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Kirim Pesan',
                    color: AppColors.primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openChatWith(contact);
                    },
                  ),
                  _buildModalActionButton(
                    icon: Icons.call_outlined,
                    label: 'Panggilan',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startCall(contact, false);
                    },
                  ),
                  _buildModalActionButton(
                    icon: Icons.videocam_outlined,
                    label: 'Panggilan Video',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startCall(contact, true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Remove from saved contacts or Block options
              if (contact.isExplicitlySaved)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger, size: 22),
                  title: const Text(
                    'Hapus dari Kontak Tersimpan',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await AccountController.instance.removeSavedContact(contact.id);
                    if (mounted) {
                      LajuToast.info(context, 'Kontak @${contact.username} dihapus dari daftar.');
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari kontak LAJU...',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                context.tr('contacts'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            tooltip: 'Pindai QR',
            onPressed: _openQrScanner,
          ),
        ],
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AccountController.instance,
            ConversationService.instance.conversationsNotifier,
          ]),
          builder: (context, _) {
            final saved = AccountController.instance.savedContacts;
            final conversations = ConversationService.instance.conversationsNotifier.value;
            final contacts = _getUnifiedContacts(saved, conversations);

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 60),
              children: [
                // Privacy Guarantee Banner
                LajuGlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  blurSigma: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kontak Mandiri & Terenkripsi',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'LAJU tidak mengakses kontak telepon Anda demi privasi maksimal. Kontak hanya dapat ditambahkan dengan memindai kode QR profil teman Anda.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Action Cards (Scan QR & My QR)
                Row(
                  children: [
                    Expanded(
                      child: LajuGlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderRadius: 16,
                        blurSigma: 10,
                        onTap: _openQrScanner,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Pindai QR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LajuGlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderRadius: 16,
                        blurSigma: 10,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MyQrCodeScreen()),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.qr_code_2_rounded,
                                color: Color(0xFF8B5CF6),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'QR Saya',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section Title & Counter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DAFTAR KONTAK (${contacts.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                      if (contacts.isNotEmpty)
                        Text(
                          'Ketuk untuk opsi',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Contact List / Empty State
                if (contacts.isEmpty)
                  LajuGlassCard(
                    padding: const EdgeInsets.all(28),
                    borderRadius: 20,
                    blurSigma: 12,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.qr_code_scanner_rounded,
                            size: 40,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _searchQuery.isNotEmpty ? 'Kontak Tidak Ditemukan' : 'Belum Ada Kontak LAJU',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ada kontak yang cocok dengan "$_searchQuery".'
                              : 'Kontak hanya dapat ditambahkan secara aman dengan memindai kode QR profil teman Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                label: const Text('Pindai Kode QR', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: _openQrScanner,
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                label: const Text('QR Saya', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const MyQrCodeScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 20,
                    blurSigma: 14,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: contacts.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 68,
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return _buildContactTile(contact, isDark);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactTile(_UnifiedContact contact, bool isDark) {
    return InkWell(
      onTap: () => _showContactDetailModal(contact),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            ModernAvatar(
              name: contact.displayName,
              radius: 23,
              isVerified: contact.isVerified,
              imagePath: contact.avatarUrl,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (contact.isOnline) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${contact.username} • ${contact.about}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Chat Button
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              color: AppColors.primary,
              tooltip: 'Chat',
              onPressed: () => _openChatWith(contact),
            ),
            // Quick Call Button
            IconButton(
              icon: const Icon(Icons.call_outlined, size: 20),
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              tooltip: 'Panggilan',
              onPressed: () => _startCall(contact, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedContact {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String about;
  final String? phoneNumber;
  final int trustScore;
  final bool isVerified;
  final bool isOnline;
  final String? conversationId;
  final bool isExplicitlySaved;

  const _UnifiedContact({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.about,
    this.phoneNumber,
    this.trustScore = 100,
    this.isVerified = true,
    this.isOnline = false,
    this.conversationId,
    this.isExplicitlySaved = false,
  });

  _UnifiedContact copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? about,
    String? phoneNumber,
    int? trustScore,
    bool? isVerified,
    bool? isOnline,
    String? conversationId,
    bool? isExplicitlySaved,
  }) {
    return _UnifiedContact(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      about: about ?? this.about,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      trustScore: trustScore ?? this.trustScore,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      conversationId: conversationId ?? this.conversationId,
      isExplicitlySaved: isExplicitlySaved ?? this.isExplicitlySaved,
    );
  }
}
