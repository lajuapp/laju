import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/auth_controller.dart';
import 'welcome_screen.dart';

class SuspendedAccountScreen extends StatelessWidget {
  final String? reason;

  const SuspendedAccountScreen({
    super.key,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final displayReason = (reason != null && reason!.trim().isNotEmpty)
        ? reason!.trim()
        : 'Pelanggaran ketentuan layanan sistem LAJU.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Icon Container
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.danger : Colors.red).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isDark ? AppColors.danger : Colors.red).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: isDark ? AppColors.danger : Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // Title
                Text(
                  'Akun Ditangguhkan',
                  style: AppTypography.headingLarge.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.sm),

                // Subtitle
                Text(
                  'Akses ke akun Anda telah dinonaktifkan sementara oleh LAJU.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.xl),

                // Reason Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(
                      color: isDark ? AppColors.darkSurfaceBorder : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: isDark ? AppColors.danger : Colors.red.shade700,
                          ),
                          const SizedBox(width: AppDimensions.xs),
                          Text(
                            'Alasan Penangguhan',
                            style: AppTypography.caption.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        displayReason,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.md),

                // Help Notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.blueGrey : Colors.grey).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                  ),
                  child: Text(
                    'Apabila Anda merasa penangguhan ini adalah sebuah kekeliruan atau ingin mengajukan banding, silakan hubungi tim dukungan resmi di support@laju.chat.',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // Action Buttons
                LajuButton(
                  label: 'Salin Email Dukungan',
                  variant: LajuButtonVariant.secondary,
                  icon: Icons.copy_rounded,
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'support@laju.chat'));
                    LajuToast.show(
                      context,
                      message: 'Alamat email support@laju.chat berhasil disalin',
                      type: LajuToastType.info,
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.sm),

                LajuButton(
                  label: 'Keluar & Ganti Akun',
                  variant: LajuButtonVariant.danger,
                  icon: Icons.logout_rounded,
                  onPressed: () {
                    AuthController.instance.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
