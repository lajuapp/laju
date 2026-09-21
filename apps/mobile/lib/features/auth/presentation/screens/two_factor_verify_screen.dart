import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/auth_controller.dart';

class TwoFactorVerifyScreen extends StatefulWidget {
  const TwoFactorVerifyScreen({super.key});

  @override
  State<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends State<TwoFactorVerifyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _enteredPin = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
        _isError = false;
      });

      if (_enteredPin.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  void _verifyPin() {
    final isValid = AuthController.instance.verifyTwoFactorPin(_enteredPin);
    if (isValid) {
      HapticFeedback.mediumImpact();
      LajuToast.success(context, context.tr('otpVerified'));
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isError = true;
        _enteredPin = '';
      });
      LajuToast.error(context, context.tr('incorrectPin'));
    }
  }

  Future<void> _triggerBiometric() async {
    HapticFeedback.mediumImpact();
    final authenticated = await BiometricService.instance.authenticate(
      title: context.tr('twoFactorAuth'),
      subtitle: context.tr('passkeysHeroDesc'),
    );
    if (authenticated && mounted) {
      final success = AuthController.instance.verifyTwoFactorBiometric();
      if (success) {
        LajuToast.success(context, context.tr('otpVerified'));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                // Shield / Lock Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  context.tr('twoFactorRequired'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.tr('twoFactorPrompt'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),

                // PIN Dots Indicator (Animated Shake)
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final offset = sin(_shakeAnimation.value * pi * 4) * 8;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_isError ? AppColors.danger : AppColors.primary)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isError
                                ? AppColors.danger
                                : (isFilled ? AppColors.primary : (isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB))),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 28),

                // Keypad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildKeypadRow(['1', '2', '3'], isDark, textPrimary),
                      const SizedBox(height: 14),
                      _buildKeypadRow(['4', '5', '6'], isDark, textPrimary),
                      const SizedBox(height: 14),
                      _buildKeypadRow(['7', '8', '9'], isDark, textPrimary),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Biometric button
                          _buildActionButton(
                            icon: Icons.fingerprint_rounded,
                            color: AppColors.primary,
                            onTap: _triggerBiometric,
                            isDark: isDark,
                          ),
                          // 0 Digit
                          _buildDigitButton('0', isDark, textPrimary),
                          // Backspace button
                          _buildActionButton(
                            icon: Icons.backspace_outlined,
                            color: textSecondary,
                            onTap: _onBackspacePressed,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildDigitButton(d, isDark, textColor)).toList(),
    );
  }

  Widget _buildDigitButton(String digit, bool isDark, Color textColor) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5) : const Color(0xFFF9FAFB),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
