import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const AppLockScreen({super.key, this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final AppLockController _lockCtrl = AppLockController.instance;
  late bool _showPinMode;
  String _enteredPin = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Default to PIN mode if biometric is disabled
    _showPinMode = !_lockCtrl.isBiometricEnabled;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_showPinMode && mounted) {
        _triggerBiometricAuth();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    final authenticated = await BiometricService.instance.authenticate(
      title: LocaleController.instance.value.languageCode == 'id'
          ? 'Buka Kunci LAJU'
          : 'Unlock LAJU',
      subtitle: LocaleController.instance.value.languageCode == 'id'
          ? 'Sentuh sensor sidik jari atau gunakan PIN perangkat'
          : 'Touch the fingerprint sensor or use device credentials',
    );
    if (authenticated && mounted) {
      _triggerUnlock();
    }
  }

  void _triggerUnlock() {
    HapticFeedback.mediumImpact();
    AppLockController.instance.unlockApp();
    LajuToast.success(
      context,
      LocaleController.instance.value.languageCode == 'id'
          ? 'Kunci terbuka'
          : 'Unlocked',
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        } else {
          Navigator.pop(context);
        }
      }
    });
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
    // Compare against saved PIN
    final correctPin = _lockCtrl.pinCode;
    if (_enteredPin == correctPin) {
      _triggerUnlock();
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isError = true;
      });
      LajuToast.error(
        context,
        LocaleController.instance.value.languageCode == 'id'
            ? 'PIN salah. Coba lagi.'
            : 'Incorrect PIN. Try again.',
      );
      Future.delayed(const Duration(milliseconds: 550), () {
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _isError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final langCode = LocaleController.instance.value.languageCode;

    final bgColor = isDark ? const Color(0xFF0A1016) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Close / Exit button if pushed from navigation
            if (Navigator.canPop(context))
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),

            // Main View (Biometric or PIN Dialpad)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showPinMode
                  ? _buildPinDialpadView(isDark, langCode, textColor, subtitleColor)
                  : _buildBiometricView(isDark, langCode, textColor, subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Biometric View (Active when isBiometricEnabled is true)
  Widget _buildBiometricView(bool isDark, String langCode, Color textColor, Color subtitleColor) {
    final scannerBg = isDark ? const Color(0xFF131D26) : Colors.white;
    final scannerBorder = isDark ? AppColors.primary.withValues(alpha: 0.8) : AppColors.primary;
    final pinLinkColor = isDark ? Colors.white : AppColors.primaryDark;

    return Padding(
      key: const ValueKey('biometric_view'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // LAJU Logo
          const Center(child: LajuLogo(size: 60)),
          const SizedBox(height: 12),
          Text(
            'LAJU',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            langCode == 'id' ? 'Terkunci' : 'Locked',
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(flex: 3),

          // Neon Glowing Fingerprint Scanner Circle
          GestureDetector(
            onTap: _triggerBiometricAuth,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glowScale = 1.0 + (_pulseController.value * 0.12);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120 * glowScale,
                      height: 120 * glowScale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.12),
                      ),
                    ),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scannerBg,
                        border: Border.all(color: scannerBorder, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.20),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primary,
                          size: 52,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Text(
            langCode == 'id'
                ? 'Gunakan sidik jari untuk membuka'
                : 'Use fingerprint to unlock',
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(flex: 3),

          // Switch to PIN mode link
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showPinMode = true;
                _enteredPin = '';
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pin_rounded, size: 18, color: pinLinkColor),
                  const SizedBox(width: 6),
                  Text(
                    langCode == 'id' ? 'Gunakan PIN' : 'Use PIN',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: pinLinkColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 2. PIN Dialpad View (Interactive tactile keypad)
  Widget _buildPinDialpadView(bool isDark, String langCode, Color textColor, Color subtitleColor) {
    return Column(
      key: const ValueKey('pin_dialpad_view'),
      children: [
        const SizedBox(height: 24),

        // Header
        Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          langCode == 'id' ? 'Masukkan PIN' : 'Enter PIN',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          langCode == 'id' ? 'Ketik 6 digit PIN keamanan LAJU' : 'Enter 6-digit security PIN',
          style: TextStyle(fontSize: 13, color: subtitleColor),
        ),
        const SizedBox(height: 24),

        // 6-digit PIN Indicator Dots with shake animation
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = sin(_shakeAnimation.value * pi * 4) * 10;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < _enteredPin.length;
              final dotColor = _isError
                  ? AppColors.danger
                  : (isFilled ? AppColors.primary : Colors.transparent);
              final borderColor = _isError
                  ? AppColors.danger
                  : (isFilled
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : const Color(0xFFCBD5E1)));

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: isFilled
                      ? [
                          BoxShadow(
                            color: (_isError ? AppColors.danger : AppColors.primary)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),

        const Spacer(),

        // The Dialpad Keypad Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            children: [
              _buildDialpadRow(['1', '2', '3'], ['', 'ABC', 'DEF'], isDark, textColor, subtitleColor),
              const SizedBox(height: 14),
              _buildDialpadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO'], isDark, textColor, subtitleColor),
              const SizedBox(height: 14),
              _buildDialpadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ'], isDark, textColor, subtitleColor),
              const SizedBox(height: 14),
              _buildDialpadBottomRow(isDark, textColor, subtitleColor),
            ],
          ),
        ),

        const Spacer(),

        // Bottom link / back to biometric if enabled
        if (_lockCtrl.isBiometricEnabled) ...[
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _showPinMode = false;
                _enteredPin = '';
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    langCode == 'id' ? 'Gunakan Sidik Jari' : 'Use Fingerprint',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'LAJU Vault',
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDialpadRow(
    List<String> digits,
    List<String> subtexts,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (i) {
        return _buildDialpadButton(
          digit: digits[i],
          subtext: subtexts[i],
          isDark: isDark,
          textColor: textColor,
          subtitleColor: subtitleColor,
          onTap: () => _onDigitPressed(digits[i]),
        );
      }),
    );
  }

  Widget _buildDialpadBottomRow(bool isDark, Color textColor, Color subtitleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Left Action: Biometric icon (if biometric enabled) or empty
        SizedBox(
          width: 74,
          height: 74,
          child: _lockCtrl.isBiometricEnabled
              ? InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showPinMode = false;
                    });
                    _triggerBiometricAuth();
                  },
                  borderRadius: BorderRadius.circular(37),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                )
              : const SizedBox(),
        ),

        // Center Action: '0' Key
        _buildDialpadButton(
          digit: '0',
          subtext: '+',
          isDark: isDark,
          textColor: textColor,
          subtitleColor: subtitleColor,
          onTap: () => _onDigitPressed('0'),
        ),

        // Right Action: Backspace Key
        SizedBox(
          width: 74,
          height: 74,
          child: InkWell(
            onTap: _onBackspacePressed,
            borderRadius: BorderRadius.circular(37),
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialpadButton({
    required String digit,
    required String subtext,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    final btnBg = isDark ? const Color(0xFF16222F) : Colors.white;
    final btnBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(37),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: btnBg,
          shape: BoxShape.circle,
          border: Border.all(color: btnBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.1,
              ),
            ),
            if (subtext.isNotEmpty)
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: subtitleColor,
                ),
              )
            else
              const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
