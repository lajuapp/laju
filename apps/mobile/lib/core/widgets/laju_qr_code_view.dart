import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

/// Premium, high-definition QR Code display widget with embedded LAJU brand logo.
/// Generates 100% compliant ISO/IEC 18004 QR codes with Level H (30%) Reed-Solomon
/// error correction for instantaneous scanning across any camera.
class LajuQrCodeView extends StatelessWidget {
  final String data;
  final double size;
  final bool showLogo;
  final double? logoSize;
  final Color foregroundColor;
  final Color backgroundColor;
  final BorderRadius? borderRadius;

  const LajuQrCodeView({
    super.key,
    required this.data,
    this.size = 210,
    this.showLogo = true,
    this.logoSize,
    this.foregroundColor = const Color(0xFF0F172A),
    this.backgroundColor = Colors.white,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final computedLogoSize = logoSize ?? (size * 0.22);
    final qrSize = size * 0.90;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Fully-compliant standard QR Code Matrix
          QrImageView(
            data: data.trim(),
            version: QrVersions.auto,
            size: qrSize,
            padding: EdgeInsets.zero,
            errorCorrectionLevel: QrErrorCorrectLevel.H,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: foregroundColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: foregroundColor,
            ),
            gapless: true,
          ),

          // 2. Central Embedded LAJU Logo Badge (Safely within 30% Level-H margin)
          if (showLogo)
            Container(
              width: computedLogoSize,
              height: computedLogoSize,
              padding: EdgeInsets.all(computedLogoSize * 0.16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo_no_bg.png',
                  width: computedLogoSize * 0.68,
                  height: computedLogoSize * 0.68,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shield_rounded,
                    color: AppColors.primary,
                    size: computedLogoSize * 0.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
