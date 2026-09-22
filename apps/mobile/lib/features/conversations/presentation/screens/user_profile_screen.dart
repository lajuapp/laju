import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../../security/presentation/screens/key_verification_screen.dart';
import '../../../messaging/presentation/screens/disappearing_messages_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String contactName;
  final String phone;
  final String status;
  final bool isOnline;
  final bool isVerified;
  final String safetyNumber;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.contactName,
    this.phone = '+62 812-5551-0101',
    this.status = 'Available • Verified Device 🔒',
    this.isOnline = true,
    this.isVerified = true,
    this.safetyNumber = '19402 48190 28471 00293 84729 48190',
    this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isMuted = false;

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThemeModeController.instance.isDarkMode(context)
            ? const Color(0xFF1E293B)
            : Colors.white,
        title: Text(
          'Blokir ${widget.contactName}?',
          style: TextStyle(
            color: ThemeModeController.instance.isDarkMode(context)
                ? Colors.white
                : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Kontak yang diblokir tidak akan dapat memanggil Anda atau mengirim pesan kepada Anda.',
          style: TextStyle(
            color: ThemeModeController.instance.isDarkMode(context)
                ? Colors.white70
                : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dialogCtx);
              LajuToast.info(context, '${widget.contactName} telah diblokir');
            },
            child: const Text('Blokir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmReport() {
    showReportUserSheet(
      context,
      reportedUserId: 'u-${widget.contactName.toLowerCase().replaceAll(' ', '_')}',
      reportedUserName: widget.contactName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Info Kontak',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: textPrimary),
            tooltip: 'Bagikan Kontak',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${widget.contactName} (${widget.phone})'));
              LajuToast.info(context, 'Detail kontak disalin ke clipboard');
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            color: cardColor,
            onSelected: (val) {
              if (val == 'verify') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KeyVerificationScreen(
                      contactName: widget.contactName,
                      safetyNumber: widget.safetyNumber,
                    ),
                  ),
                );
              } else if (val == 'block') {
                _confirmBlock();
              } else if (val == 'report') {
                _confirmReport();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'verify',
                child: Text('Verifikasi Kunci Keamanan', style: TextStyle(color: textPrimary)),
              ),
              PopupMenuItem(
                value: 'block',
                child: const Text('Blokir Kontak', style: TextStyle(color: AppColors.danger)),
              ),
              PopupMenuItem(
                value: 'report',
                child: const Text('Laporkan Akun', style: TextStyle(color: Color(0xFFEF4444))),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header Profile Card
            Container(
              width: double.infinity,
              color: cardColor,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  ModernAvatar(
                    name: widget.contactName,
                    imagePath: widget.avatarUrl,
                    radius: 46,
                    isOnline: widget.isOnline,
                    isVerified: widget.isVerified,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.contactName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      if (widget.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 20, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Trust Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 5),
                        Text(
                          '${context.tr('reportTrustScore')}: 100/100 • ${context.tr('reportAccountClean')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickAction(
                        icon: Icons.call_rounded,
                        label: 'Audio',
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveCallScreen(
                                contactName: widget.contactName,
                                isVideo: false,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.videocam_rounded,
                        label: 'Video',
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveCallScreen(
                                contactName: widget.contactName,
                                isVideo: true,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
                        label: _isMuted ? 'Muted' : 'Mute',
                        isDark: isDark,
                        isActive: _isMuted,
                        onTap: () {
                          setState(() => _isMuted = !_isMuted);
                          LajuToast.info(
                            context,
                            _isMuted
                                ? 'Notifikasi dari ${widget.contactName} dibisukan'
                                : 'Notifikasi dari ${widget.contactName} diaktifkan',
                          );
                        },
                      ),
                      _buildQuickAction(
                        icon: Icons.search_rounded,
                        label: 'Cari',
                        isDark: isDark,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bio / Status Card
            Container(
              width: double.infinity,
              color: cardColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Info & Nomor Telepon',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.status,
                    style: TextStyle(fontSize: 15, color: textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status bio profil',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  const Divider(height: 24),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.phone));
                      LajuToast.info(context, 'Nomor disalin ke clipboard');
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.phone,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text('Ponsel • Ketuk untuk salin', style: TextStyle(fontSize: 12, color: textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Security & Encryption Card
            Container(
              width: double.infinity,
              color: cardColor,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Enkripsi & Keamanan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      'Enkripsi End-to-End',
                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                    ),
                    subtitle: Text(
                      'Pesan dan panggilan dienkripsi secara end-to-end. Ketuk untuk verifikasi nomor keamanan.',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KeyVerificationScreen(
                            contactName: widget.contactName,
                            safetyNumber: widget.safetyNumber,
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 64, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 20),
                    ),
                    title: Text(
                      'Pesan Sementara',
                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                    ),
                    subtitle: Text(
                      'Mati • Pesan baru otomatis dihapus sesuai waktu',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DisappearingMessagesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Media, Links & Docs Card
            Container(
              width: double.infinity,
              color: cardColor,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.perm_media_rounded, color: Colors.purpleAccent, size: 20),
                ),
                title: Text(
                  'Media, Tautan, dan Dokumen',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                ),
                subtitle: Text('14 Foto, 4 Dokumen, 2 Tautan', style: TextStyle(color: textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('20', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
                onTap: () {
                  LajuToast.info(context, 'Membuka galeri media terenkripsi');
                },
              ),
            ),
            const SizedBox(height: 12),

            // Notification Settings Card
            Container(
              width: double.infinity,
              color: cardColor,
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 20),
                ),
                title: Text(
                  'Bisukan Notifikasi',
                  style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                ),
                subtitle: Text(
                  _isMuted ? 'Notifikasi saat ini dibisukan' : 'Notifikasi aktif normal',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                value: _isMuted,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _isMuted = val);
                  LajuToast.info(
                    context,
                    val
                        ? 'Notifikasi dari ${widget.contactName} dibisukan'
                        : 'Notifikasi dari ${widget.contactName} diaktifkan',
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Danger Zone Card (Block / Report)
            Container(
              width: double.infinity,
              color: cardColor,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: AppColors.danger),
                    title: Text(
                      'Blokir ${widget.contactName}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                    ),
                    onTap: _confirmBlock,
                  ),
                  Divider(height: 1, indent: 56, color: isDark ? Colors.white10 : Colors.black12),
                  ListTile(
                    leading: const Icon(Icons.thumb_down_alt_rounded, color: AppColors.danger),
                    title: Text(
                      'Laporkan ${widget.contactName}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                    ),
                    onTap: _confirmReport,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppColors.danger
                      : isDark
                          ? Colors.white12
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.danger : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.danger
                    : isDark
                        ? Colors.white70
                        : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
