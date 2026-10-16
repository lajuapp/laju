import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import 'contact_support_screen.dart';
import 'faq_screen.dart';
import 'network_diagnostic_screen.dart';
import 'system_status_screen.dart';
import 'terms_privacy_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
          context.tr('help'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            // Header Glass Hero Card
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                  );
                },
                child: LajuGlassCard(
                  padding: const EdgeInsets.all(18),
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                        child: const Icon(Icons.support_agent_rounded, color: Colors.black, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('supportDesk'),
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('supportDeskDesc'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                context.tr('helpAndAssistance'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  _buildHelpTile(
                    context,
                    icon: Icons.help_center_rounded,
                    accentColor: const Color(0xFF06B6D4),
                    title: context.tr('helpFaqTitle'),
                    subtitle: context.tr('helpFaqSub'),
                    isFirst: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FaqScreen()),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildHelpTile(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    accentColor: const Color(0xFF10B981),
                    title: context.tr('contactUs'),
                    subtitle: context.tr('contactUsSub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildHelpTile(
                    context,
                    icon: Icons.policy_rounded,
                    accentColor: const Color(0xFF6366F1),
                    title: context.tr('termsPrivacy'),
                    subtitle: context.tr('termsPrivacySub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TermsPrivacyScreen()),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildHelpTile(
                    context,
                    icon: Icons.network_check_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    title: context.tr('networkDiagnostic'),
                    subtitle: context.tr('networkDiagnosticSub'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NetworkDiagnosticScreen()),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildHelpTile(
                    context,
                    icon: Icons.security_update_good_rounded,
                    accentColor: AppColors.primary,
                    title: context.tr('systemStatus'),
                    subtitle: context.tr('systemStatusSub'),
                    isLast: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF15803D).withValues(alpha: 0.25) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '99.99%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SystemStatusScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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

  Widget _buildHelpTile(
    BuildContext context, {
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
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
          width: 38,
          height: 38,
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
              size: 20,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
          ),
        ),
        trailing: trailing ??
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
            ),
        onTap: onTap,
      ),
    );
  }
}
