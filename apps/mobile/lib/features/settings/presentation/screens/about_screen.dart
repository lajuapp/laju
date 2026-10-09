import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
          context.tr('aboutLaju'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            // App Logo & Branding Glass Card
            LajuGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              borderRadius: 22,
              blurSigma: 16,
              child: Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo_no_bg.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'LAJU',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('aboutVersion'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGlow,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('aboutBadge'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Open Source Project Info Card
            LajuGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.public_rounded, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('aboutOpenSourceTitle'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('aboutOpenSourceDesc'),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal Disclaimer & Limitation of Liability Card
            LajuGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.gavel_rounded, size: 20, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('aboutLegalDisclaimerTitle'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('aboutLegalDisclaimerDesc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('aboutDisclaimerBanner'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Cryptographic Protocol Specs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                context.tr('aboutCryptoSpecsTitle'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            LajuGlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  _buildSpecTile(
                    context,
                    'Key Exchange',
                    'PQ-X3DH (Kyber-1024 + Curve25519)',
                    Icons.lock_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildSpecTile(
                    context,
                    'Session Ratchet',
                    'Double Ratchet with HKDF-SHA256',
                    Icons.sync_lock_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildSpecTile(
                    context,
                    'Payload Cipher',
                    'AES-256-GCM authenticated encryption',
                    Icons.enhanced_encryption_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildSpecTile(
                    context,
                    'Voice & Video Signaling',
                    'WebRTC P2P with DTLS-SRTP',
                    Icons.phone_locked_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildSpecTile(
                    context,
                    'Key Storage',
                    'Android Keystore / StrongBox Hardware TEE',
                    Icons.memory_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Legal & Open Source
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                context.tr('aboutLegalAuditsTitle'),
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
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(Icons.menu_book_rounded, color: isDark ? AppColors.primaryLight : const Color(0xFF2563EB)),
                      title: Text(
                        context.tr('aboutLicenses'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF)),
                      onTap: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'LAJU',
                          applicationVersion: AppUpdateController.instance.currentVersion,
                        );
                      },
                    ),
                  ),
                  _buildDivider(isDark),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const Icon(Icons.verified_user_outlined, color: AppColors.cyan),
                      title: Text(
                        context.tr('aboutAuditReport'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF)),
                      onTap: () {
                        LajuToast.success(context, context.tr('aboutAuditPassed'));
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                context.tr('aboutCopyright'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 44,
      endIndent: 12,
      color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildSpecTile(BuildContext context, String label, String value, IconData icon) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
