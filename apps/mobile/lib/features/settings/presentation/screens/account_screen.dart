import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/account_controller.dart';
import 'security_notifications_screen.dart';
import 'passkeys_screen.dart';
import 'package:laju_mobile/features/security/presentation/screens/backup_identity_screen.dart';
import 'package:laju_mobile/features/security/presentation/screens/device_migration_screen.dart';
import 'two_step_verification_screen.dart';
import 'request_account_info_screen.dart';
import 'delete_account_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('account'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListenableBuilder(
          listenable: AccountController.instance,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                LajuGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Column(
                    children: [
                      _buildAccountTile(
                        context,
                        icon: Icons.shield_outlined,
                        titleKey: 'securityNotifications',
                        subtitleKey: 'securityNotificationsSub',
                        isFirst: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SecurityNotificationsScreen()),
                          );
                        },
                      ),
                      _buildDivider(isDark),
                      _buildAccountTile(
                        context,
                        icon: Icons.vpn_key_outlined,
                        titleKey: 'passkeys',
                        subtitleKey: 'passkeysSub',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PasskeysScreen()),
                          );
                        },
                      ),
                      _buildDivider(isDark),
                      _buildAccountTile(
                        context,
                        icon: Icons.key_rounded,
                        titleKey: 'backupIdentityTitle',
                        subtitleKey: 'backupIdentitySub',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BackupIdentityScreen()),
                          );
                        },
                      ),
                      _buildDivider(isDark),
                      _buildAccountTile(
                        context,
                        icon: Icons.phonelink_setup_rounded,
                        titleKey: 'startMigrationTitle',
                        subtitleKey: 'startMigrationSub',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DeviceMigrationScreen()),
                          );
                        },
                      ),
                      _buildDivider(isDark),
                      _buildAccountTile(
                        context,
                        icon: Icons.dialpad_rounded,
                        titleKey: 'twoStepVerification',
                        subtitleKey: 'twoStepVerificationSub',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TwoStepVerificationScreen()),
                          );
                        },
                      ),
                  _buildDivider(isDark),
                  _buildAccountTile(
                    context,
                    icon: Icons.description_outlined,
                    titleKey: 'requestAccountInfo',
                    subtitleKey: 'requestAccountInfoSub',
                    isLast: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RequestAccountInfoScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Delete Account (Red Glass Card)
            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              borderColor: AppColors.danger.withValues(alpha: isDark ? 0.35 : 0.25),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                  ),
                  title: Text(
                    context.tr('deleteAccount'),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  subtitle: Text(
                    context.tr('deleteAccountSub'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DeleteAccountScreen()),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  ),
);
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      endIndent: 16,
      color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    String? subtitleKey,
    String? customSubtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final subtitleText = customSubtitle ?? (subtitleKey != null ? context.tr(subtitleKey) : '');
    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isDark ? AppColors.primary : const Color(0xFF2563EB), size: 20),
        ),
        title: Text(
          context.tr(titleKey),
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
        ),
        onTap: onTap,
      ),
    );
  }
}
