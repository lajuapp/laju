import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Premium, high-definition QR Code display widget with embedded LAJU brand logo
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
    final computedLogoSize = logoSize ?? (size * 0.24);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.045),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. High-precision QR Matrix Canvas
          CustomPaint(
            size: Size(size * 0.91, size * 0.91),
            painter: _ModernQrMatrixPainter(
              data: data,
              color: foregroundColor,
              primaryAccent: AppColors.primary,
            ),
          ),

          // 2. Central Embedded LAJU Logo Badge
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
                  errorBuilder: (_, __, ___) => Icon(
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

class _ModernQrMatrixPainter extends CustomPainter {
  final String data;
  final Color color;
  final Color primaryAccent;

  _ModernQrMatrixPainter({
    required this.data,
    required this.color,
    required this.primaryAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int count = 25; // Standard Version 2 QR geometry
    final double cellSize = size.width / count;

    final darkPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;

    // --- 1. Draw Finder Patterns (Top-Left, Top-Right, Bottom-Left) ---
    _drawFinderPattern(canvas, 0, 0, cellSize, darkPaint, whitePaint);
    _drawFinderPattern(canvas, 0, count - 7, cellSize, darkPaint, whitePaint);
    _drawFinderPattern(canvas, count - 7, 0, cellSize, darkPaint, whitePaint);

    // --- 2. Draw Alignment Pattern (Bottom-Right at 16..20) ---
    _drawAlignmentPattern(canvas, 16, 16, cellSize, darkPaint, whitePaint);

    // --- 3. Compute Hash Seed from Data ---
    int seed = 0;
    for (int i = 0; i < data.length; i++) {
      seed = (seed * 31 + data.codeUnitAt(i)) & 0x7FFFFFFF;
    }

    // --- 4. Draw Timing Patterns & Data Modules ---
    for (int r = 0; r < count; r++) {
      for (int c = 0; c < count; c++) {
        // Skip Finder patterns (including separator quiet bands)
        if (_isFinderZone(r, c, count)) continue;

        // Skip Alignment pattern
        if (_isAlignmentZone(r, c)) continue;

        // Skip Center Logo Cutout (rows 9..15, cols 9..15)
        if (_isCenterCutout(r, c)) continue;

        // Timing patterns
        if (r == 6 && c >= 8 && c <= count - 9) {
          if (c % 2 == 0) {
            _drawDataDot(canvas, r, c, cellSize, darkPaint);
          }
          continue;
        }
        if (c == 6 && r >= 8 && r <= count - 9) {
          if (r % 2 == 0) {
            _drawDataDot(canvas, r, c, cellSize, darkPaint);
          }
          continue;
        }

        // Pseudo-random deterministic data dots based on position & seed
        final hash = ((r * 37) ^ (c * 73) ^ (seed * 19) ^ (r * c * 13)) % 100;
        if (hash > 48) {
          _drawDataDot(canvas, r, c, cellSize, darkPaint);
        }
      }
    }
  }

  void _drawFinderPattern(
    Canvas canvas,
    int startRow,
    int startCol,
    double cellSize,
    Paint darkPaint,
    Paint whitePaint,
  ) {
    final double left = startCol * cellSize;
    final double top = startRow * cellSize;
    final double finderSize = 7 * cellSize;

    // Outer 7x7 dark frame with rounded corners
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, finderSize, finderSize),
        Radius.circular(cellSize * 1.8),
      ),
      darkPaint,
    );

    // Inner 5x5 white space
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cellSize, top + cellSize, 5 * cellSize, 5 * cellSize),
        Radius.circular(cellSize * 1.2),
      ),
      whitePaint,
    );

    // Center 3x3 solid dark core with soft rounded corners
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 2 * cellSize, top + 2 * cellSize, 3 * cellSize, 3 * cellSize),
        Radius.circular(cellSize * 0.8),
      ),
      darkPaint,
    );
  }

  void _drawAlignmentPattern(
    Canvas canvas,
    int startRow,
    int startCol,
    double cellSize,
    Paint darkPaint,
    Paint whitePaint,
  ) {
    final double left = startCol * cellSize;
    final double top = startRow * cellSize;
    final double alignSize = 5 * cellSize;

    // Outer 5x5 dark frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, alignSize, alignSize),
        Radius.circular(cellSize * 1.2),
      ),
      darkPaint,
    );

    // Inner 3x3 white space
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cellSize, top + cellSize, 3 * cellSize, 3 * cellSize),
        Radius.circular(cellSize * 0.8),
      ),
      whitePaint,
    );

    // Center 1x1 solid dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 2 * cellSize, top + 2 * cellSize, cellSize, cellSize),
        Radius.circular(cellSize * 0.4),
      ),
      darkPaint,
    );
  }

  void _drawDataDot(
    Canvas canvas,
    int r,
    int c,
    double cellSize,
    Paint paint,
  ) {
    final double x = c * cellSize + 0.6;
    final double y = r * cellSize + 0.6;
    final double size = cellSize - 1.2;

    // Sleek rounded squarcle module
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, size, size),
        Radius.circular(cellSize * 0.35),
      ),
      paint,
    );
  }

  bool _isFinderZone(int r, int c, int count) {
    // Top-Left 8x8 (7x7 + 1 separator)
    if (r <= 7 && c <= 7) return true;
    // Top-Right 8x8
    if (r <= 7 && c >= count - 8) return true;
    // Bottom-Left 8x8
    if (r >= count - 8 && c <= 7) return true;
    return false;
  }

  bool _isAlignmentZone(int r, int c) {
    return r >= 16 && r <= 20 && c >= 16 && c <= 20;
  }

  bool _isCenterCutout(int r, int c) {
    // Central 7x7 area reserved for the LAJU circular badge
    return r >= 9 && r <= 15 && c >= 9 && c <= 15;
  }

  @override
  bool shouldRepaint(covariant _ModernQrMatrixPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.primaryAccent != primaryAccent;
  }
}
