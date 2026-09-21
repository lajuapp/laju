import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class LajuLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;

  const LajuLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = Image.asset(
      'assets/images/logo_no_bg.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // High-assurance fallback if image asset is not ready
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Center(
            child: Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: size * 0.6,
            ),
          ),
        );
      },
    );

    if (!showText) {
      return imageWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        imageWidget,
        const SizedBox(width: 10),
        Text(
          'LAJU',
          style: textStyle ??
              const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}
