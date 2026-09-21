import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/theme_controller.dart';

class LajuCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final BorderSide? border;
  final VoidCallback? onTap;

  const LajuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.lg),
    this.margin,
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final defaultBg = isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated;
    final defaultBorder = isDark ? AppColors.darkSurfaceBorder : AppColors.surfaceBorder;

    final cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: AppDimensions.roundedLarge,
        border: Border.all(
          color: border?.color ?? defaultBorder,
          width: border?.width ?? 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppDimensions.roundedLarge,
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
