import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/theme_controller.dart';

enum LajuButtonVariant {
  primary,
  secondary,
  outline,
  danger,
}

class LajuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LajuButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;

  const LajuButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = LajuButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = AppDimensions.buttonHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    Color bgColor;
    Color textColor;
    BorderSide border;

    switch (variant) {
      case LajuButtonVariant.primary:
        bgColor = AppColors.primary;
        textColor = Colors.black;
        border = BorderSide.none;
        break;
      case LajuButtonVariant.secondary:
        bgColor = isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated;
        textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
        border = BorderSide(
          color: isDark ? AppColors.darkSurfaceBorder : AppColors.surfaceBorder,
          width: 1,
        );
        break;
      case LajuButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = AppColors.primary;
        border = const BorderSide(color: AppColors.primary, width: 1.5);
        break;
      case LajuButtonVariant.danger:
        bgColor = AppColors.danger;
        textColor = Colors.white;
        border = BorderSide.none;
        break;
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.roundedLarge,
            side: border,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppDimensions.iconSmall, color: textColor),
                    const SizedBox(width: AppDimensions.sm),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
