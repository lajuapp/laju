import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // LAJU Logo No Background
            Center(
              child: Image.asset(
                'assets/images/logo_no_bg.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'LAJU',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),

            Text(
              context.tr('welcomeTagline'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),

            const Spacer(flex: 3),

            // Tactical Mountain Silhouette Motif (custom painted)
            CustomPaint(
              size: const Size(double.infinity, 90),
              painter: MountainSilhouettePainter(isDark: isDark),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OnboardingScreen(),
                          ),
                        );
                      },
                      child: Text(
                        context.tr('getStarted'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        context.tr('alreadyHaveAccount'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class MountainSilhouettePainter extends CustomPainter {
  final bool isDark;
  MountainSilhouettePainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF1F2937)).withValues(alpha: isDark ? 0.05 : 0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.25, size.height * 0.4);
    path.lineTo(size.width * 0.45, size.height * 0.65);
    path.lineTo(size.width * 0.7, size.height * 0.3);
    path.lineTo(size.width * 0.85, size.height * 0.55);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final darkPaint = Paint()
      ..color = (isDark ? AppColors.primary : const Color(0xFF111827)).withValues(alpha: isDark ? 0.08 : 0.2)
      ..style = PaintingStyle.fill;

    final darkPath = Path();
    darkPath.moveTo(0, size.height);
    darkPath.lineTo(0, size.height * 0.85);
    darkPath.lineTo(size.width * 0.3, size.height * 0.6);
    darkPath.lineTo(size.width * 0.55, size.height * 0.8);
    darkPath.lineTo(size.width * 0.8, size.height * 0.5);
    darkPath.lineTo(size.width * 0.75, size.height * 0.75);
    darkPath.lineTo(size.width, size.height);
    darkPath.close();

    canvas.drawPath(darkPath, darkPaint);
  }

  @override
  bool shouldRepaint(covariant MountainSilhouettePainter oldDelegate) => oldDelegate.isDark != isDark;
}
