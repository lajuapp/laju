import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LajuSecurityBadge extends StatelessWidget {
  final String label;
  final bool isVerified;
  final VoidCallback? onTap;

  const LajuSecurityBadge({
    super.key,
    this.label = 'E2EE AKTIF',
    this.isVerified = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isVerified ? AppColors.primaryGlow : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVerified ? AppColors.primary.withValues(alpha: 0.5) : AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVerified ? Icons.shield_rounded : Icons.shield_outlined,
              size: 13,
              color: isVerified ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isVerified ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
