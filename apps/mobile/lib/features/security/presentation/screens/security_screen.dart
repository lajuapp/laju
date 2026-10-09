import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import 'key_verification_screen.dart';
import 'chat_lock_screen.dart';
import 'package:laju_mobile/features/messaging/presentation/screens/disappearing_messages_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/biometric_settings_screen.dart';
import 'device_migration_screen.dart';
import 'backup_identity_screen.dart';
import 'package:laju_mobile/features/settings/presentation/screens/passkeys_screen.dart';
import 'package:laju_mobile/features/settings/domain/account_controller.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _securityNotifications = true;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    final isAppLockActive = AppLockController.instance.isAppLockEnabled;
    final appLockSub = isAppLockActive
        ? (AppLockController.instance.isBiometricEnabled
            ? 'Biometrik & PIN aktif'
            : 'PIN aktif')
        : 'Nonaktif';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('security'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // 1. Hero Shield Glass Card
              LajuGlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                blurSigma: 18,
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.25),
                            AppColors.primary.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Percakapan Terenkripsi End-to-End',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pesan, panggilan suara/video, dokumen, dan status Anda dilindungi oleh Signal Protocol & Hardware Keystore. Tidak seorang pun di luar obrolan dapat membacanya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section 1 Header: Keamanan Akses
              _buildSectionHeader('KEAMANAN AKSES & PERCAKAPAN', textSecondary),
              const SizedBox(height: 8),

              // Group 1: Chat & Access Security Glass Card
              LajuGlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                blurSigma: 14,
                child: Column(
                  children: [
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.notifications_active_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      title: context.tr('securityNotifications'),
                      subtitle: context.tr('securityNotificationsSub'),
                      trailing: Switch.adaptive(
                        value: _securityNotifications,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() => _securityNotifications = val);
                          if (val) {
                            LajuToast.success(context, 'Notifikasi keamanan aktif');
                          } else {
                            LajuToast.info(context, 'Notifikasi keamanan dinonaktifkan');
                          }
                        },
                      ),
                      onTap: () {
                        setState(() => _securityNotifications = !_securityNotifications);
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.fingerprint_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'Kunci Aplikasi & Biometrik',
                      subtitle: appLockSub,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BiometricSettingsScreen(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.key_rounded,
                      iconColor: const Color(0xFF06B6D4),
                      title: 'Kunci Pas (Passkeys)',
                      subtitle: 'Masuk aman menggunakan biometrik perangkat',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasskeysScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Kunci Obrolan (Chat Lock)',
                      subtitle: 'Sembunyikan dan amankan obrolan sensitif',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatLockScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.timer_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Pesan Sementara',
                      subtitle: 'Pesan terhapus otomatis setelah batas waktu',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DisappearingMessagesScreen(initialTimer: 'Off'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section 2 Header: Kriptografi & Identitas
              _buildSectionHeader('IDENTITAS KRIPTOGRAFIS & PERANGKAT', textSecondary),
              const SizedBox(height: 8),

              // Group 2: Identity & Cryptography Glass Card
              LajuGlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                blurSigma: 14,
                child: Column(
                  children: [
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.verified_user_outlined,
                      iconColor: const Color(0xFF06B6D4),
                      title: 'Verifikasi Kunci Kontak',
                      subtitle: 'Bandingkan nomor keamanan atau pindai QR',
                      onTap: () => _showSelectContactSheet(context, isDark),
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.key_rounded,
                      iconColor: const Color(0xFFF97316),
                      title: context.tr('backupIdentityTitle'),
                      subtitle: 'Cadangkan kunci rahasia pemulihan identitas',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BackupIdentityScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.phonelink_setup_rounded,
                      iconColor: const Color(0xFF14B8A6),
                      title: context.tr('startMigrationTitle'),
                      subtitle: context.tr('deviceMigrationSub'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeviceMigrationScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInnerDivider(isDark),
                    _buildGlassSettingTile(
                      context,
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Spesifikasi Enkripsi',
                      subtitle: 'Arsitektur Signal Protocol & Chip Keystore',
                      onTap: () => _showSpecsDialog(context, isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGlassSettingTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: textSecondary,
                height: 1.3,
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
      onTap: onTap,
    );
  }

  Widget _buildInnerDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 62,
      endIndent: 12,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
    );
  }

  void _showSpecsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Spesifikasi Enkripsi',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSpecRow('Protokol Pertukaran', 'Signal X3DH (Triple Diffie-Hellman)', isDark),
            _buildSpecRow('Protokol Sesi', 'Double Ratchet (Forward Secrecy)', isDark),
            _buildSpecRow('Enkripsi Pesan & Media', 'AES-256-GCM authenticated', isDark),
            _buildSpecRow('Isolasi Kunci', 'Android Keystore / Secure Enclave TEE', isDark),
            _buildSpecRow('Penyimpanan Lokal', 'SQLite SQLCipher 256-bit CBC', isDark),
            _buildSpecRow('Integritas Kunci', 'Ed25519 & Curve25519 Signatures', isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectContactSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        String query = '';
        final savedContacts = AccountController.instance.savedContacts;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final users = query.isEmpty
                ? savedContacts
                : savedContacts.where((c) {
                    final q = query.toLowerCase();
                    return c.username.toLowerCase().contains(q) ||
                        (c.displayName != null && c.displayName!.toLowerCase().contains(q));
                  }).toList();

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF06B6D4),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Kontak untuk Verifikasi',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pilih kontak untuk mencocokkan nomor keamanan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: TextField(
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari username kontak...',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
                              fontSize: 13.5,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              query = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: users.isEmpty
                            ? Center(
                                child: Text(
                                  'Tidak ada kontak personal ditemukan',
                                  style: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: users.length,
                                separatorBuilder: (ctx, index) => Divider(
                                  height: 1,
                                  indent: 56,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFF1F5F9),
                                ),
                                itemBuilder: (context, i) {
                                  final u = users[i];
                                  final name = (u.displayName != null && u.displayName!.isNotEmpty) ? u.displayName! : u.username;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    leading: ModernAvatar(name: u.username, radius: 20, isVerified: true),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      (u.phoneNumber != null && u.phoneNumber!.isNotEmpty)
                                          ? u.phoneNumber!
                                          : '@${u.username}',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                        trailing: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.shield_outlined,
                                            color: AppColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(sheetCtx);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => KeyVerificationScreen(
                                                contactName: name,
                                                safetyNumber: SafetyNumberHelper.deriveSafetyNumber(
                                                  name,
                                                  ApiClient.instance.userId ?? 'me',
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
