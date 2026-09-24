import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../auth/domain/auth_controller.dart';
import '../../../auth/presentation/screens/welcome_screen.dart';
import '../../../devices/presentation/screens/linked_devices_screen.dart';
import 'package:laju_mobile/features/security/presentation/screens/security_screen.dart';
import '../../domain/account_controller.dart';
import 'account_screen.dart';
import 'contacts_screen.dart';
import 'privacy_screen.dart';
import 'notifications_settings_screen.dart';
import 'data_storage_screen.dart';
import 'appearance_settings_screen.dart';
import 'language_settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'my_profile_screen.dart';
import 'my_qr_code_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        ThemeModeController.instance,
        AccountController.instance,
      ]),
      builder: (context, _) {
        final langCode = LocaleController.instance.value.languageCode;
        final currentLangName = switch (langCode) {
          'id' => 'Bahasa Indonesia',
          'ru' => 'Русский',
          'zh' => '中文 (简体)',
          'ja' => '日本語',
          _ => 'English',
        };

        final isDark = ThemeModeController.instance.isDarkMode(context);
        final userCtrl = AccountController.instance;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
          appBar: LajuGlassAppBar(
            title: Text(
              context.tr('settings'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          body: LajuGlassBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // 1. User Profile Glass Hero Card
                LajuGlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 22,
                  blurSigma: 16,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      ModernAvatar(
                        name: userCtrl.userName,
                        radius: 28,
                        isVerified: true,
                        imagePath: userCtrl.avatarUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userCtrl.userName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '@${userCtrl.userName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MyQrCodeScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
                            ),
                          ),
                          child: Icon(
                            Icons.qr_code_rounded,
                            color: isDark ? const Color(0xFF38BDF8) : AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Group 1: Security & Identity
                LajuGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: 20,
                  blurSigma: 14,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        context,
                        Icons.person_rounded,
                        const Color(0xFF3B82F6),
                        context.tr('account'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AccountScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.people_alt_rounded,
                        const Color(0xFF10B981),
                        context.tr('contacts'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ContactsScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.lock_rounded,
                        const Color(0xFFF59E0B),
                        context.tr('privacy'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PrivacyScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.shield_rounded,
                        const Color(0xFF10B981),
                        context.tr('security'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SecurityScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.devices_rounded,
                        const Color(0xFF06B6D4),
                        'Perangkat Tertaut',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LinkedDevicesScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Group 2: Communications & Storage
                LajuGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: 20,
                  blurSigma: 14,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        context,
                        Icons.notifications_rounded,
                        const Color(0xFFF43F5E),
                        context.tr('notifications'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.pie_chart_rounded,
                        const Color(0xFF14B8A6),
                        context.tr('dataAndStorage'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DataStorageScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Group 3: Preferences
                LajuGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: 20,
                  blurSigma: 14,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        context,
                        Icons.palette_rounded,
                        const Color(0xFF8B5CF6),
                        context.tr('appearance'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AppearanceSettingsScreen()),
                          );
                        },
                        trailingText: ThemeModeController.instance.value == ThemeMode.dark
                            ? context.tr('darkTheme')
                            : ThemeModeController.instance.value == ThemeMode.system
                                ? context.tr('systemDefault')
                                : context.tr('lightTheme'),
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.translate_rounded,
                        const Color(0xFF06B6D4),
                        context.tr('language'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LanguageSettingsScreen()),
                          );
                        },
                        trailingText: currentLangName,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 5. Group 4: Support & About
                LajuGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: 20,
                  blurSigma: 14,
                  child: Column(
                    children: [
                      _buildSettingTile(
                        context,
                        Icons.help_rounded,
                        const Color(0xFFFB923C),
                        context.tr('help'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HelpScreen()),
                          );
                        },
                      ),
                      _buildInnerDivider(isDark),
                      _buildSettingTile(
                        context,
                        Icons.info_rounded,
                        const Color(0xFF6366F1),
                        context.tr('aboutLaju'),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 6. Logout Card
                LajuGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  borderRadius: 20,
                  blurSigma: 14,
                  child: _buildSettingTile(
                    context,
                    Icons.logout_rounded,
                    const Color(0xFFEF4444),
                    context.tr('logout') == 'logout' ? 'Keluar dari Akun' : context.tr('logout'),
                    () => _showLogoutConfirmation(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cancelLabel = context.tr('cancel');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari Akun?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sesi Anda akan diakhiri pada perangkat ini. Anda harus masuk kembali untuk mengakses pesan.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              cancelLabel,
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await Future.delayed(const Duration(milliseconds: 150));
              AuthController.instance.logout();
              AppNavigation.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInnerDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 12),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    Color accentColor,
    String title,
    VoidCallback onTap, {
    String? trailingText,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: accentColor,
            size: 19,
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                trailingText,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF94A3B8),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
