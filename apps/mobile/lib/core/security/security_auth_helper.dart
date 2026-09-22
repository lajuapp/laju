import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core.dart';

class SecurityAuthHelper {
  SecurityAuthHelper._();

  /// Performs full security verification:
  /// 1. Prompts biometric scan if enabled and supported on the device.
  /// 2. If biometric fails, is cancelled, or disabled, falls back to 6-digit PIN verification.
  /// Returns `true` if authentication succeeds, `false` otherwise.
  static Future<bool> authenticate(
    BuildContext context, {
    String title = 'Verifikasi Keamanan',
    String subtitle = 'Konfirmasi identitas Anda untuk melanjutkan',
    bool forcePin = false,
  }) async {
    final lockCtrl = AppLockController.instance;

    // Try Biometric authentication if available and enabled (strictly prioritized)
    if (!forcePin && lockCtrl.isBiometricEnabled) {
      final canBio = await BiometricService.instance.canAuthenticate();
      if (canBio) {
        final bioSuccess = await BiometricService.instance.authenticate(
          title: title,
          subtitle: subtitle,
        );
        // If biometric is active, its result is definitive (no unwanted PIN sheet if cancelled)
        return bioSuccess;
      }
    }

    // Only fallback to PIN verification if biometric is not enabled or not supported by hardware
    if (lockCtrl.hasSetPin) {
      if (!context.mounted) return false;
      return await promptVerifyPin(
        context,
        title: title,
        subtitle: subtitle,
      );
    }

    // If neither biometric nor PIN is configured, allow operation
    return true;
  }

  /// Prompts the user to enter their current 6-digit PIN.
  static Future<bool> promptVerifyPin(
    BuildContext context, {
    String title = 'Verifikasi PIN',
    String subtitle = 'Masukkan 6-digit PIN Anda',
    String? expectedPin,
  }) async {
    final targetPin = expectedPin ?? AppLockController.instance.pinCode;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _VerifyPinSheet(
        title: title,
        subtitle: subtitle,
        expectedPin: targetPin,
        isDark: isDark,
      ),
    );

    return result ?? false;
  }

  /// Prompts the user to setup a new 6-digit PIN with a confirmation step.
  /// Returns the validated 6-digit PIN if completed successfully, or `null` if cancelled.
  static Future<String?> promptSetupPin(
    BuildContext context, {
    String title = 'Atur PIN Baru (6-digit)',
  }) async {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _SetupPinSheet(
        title: title,
        isDark: isDark,
      ),
    );

    return result;
  }
}

class _VerifyPinSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String expectedPin;
  final bool isDark;

  const _VerifyPinSheet({
    required this.title,
    required this.subtitle,
    required this.expectedPin,
    required this.isDark,
  });

  @override
  State<_VerifyPinSheet> createState() => _VerifyPinSheetState();
}

class _VerifyPinSheetState extends State<_VerifyPinSheet> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _isError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_enteredPin.length < 6) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
        _isError = false;
      });

      if (_enteredPin.length == 6) {
        if (_enteredPin == widget.expectedPin) {
          HapticFeedback.mediumImpact();
          Navigator.pop(context, true);
        } else {
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
          setState(() {
            _isError = true;
          });
          LajuToast.error(context, 'PIN salah. Silakan coba lagi.');
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              setState(() {
                _enteredPin = '';
                _isError = false;
              });
            }
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // PIN Dots Indicator with Shake Animation
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset = sin(_shakeController.value * pi * 4) * 10;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final filled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? Colors.redAccent
                          : (filled ? AppColors.primary : Colors.transparent),
                      border: Border.all(
                        color: _isError
                            ? Colors.redAccent
                            : (filled ? AppColors.primary : (widget.isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Dialpad
            _DialpadWidget(
              isDark: widget.isDark,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupPinSheet extends StatefulWidget {
  final String title;
  final bool isDark;

  const _SetupPinSheet({
    required this.title,
    required this.isDark,
  });

  @override
  State<_SetupPinSheet> createState() => _SetupPinSheetState();
}

class _SetupPinSheetState extends State<_SetupPinSheet> with SingleTickerProviderStateMixin {
  int _step = 1; // 1: Enter New PIN, 2: Confirm New PIN
  String _pin = '';
  String _confirmPin = '';
  bool _isError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_step == 1) {
      if (_pin.length < 6) {
        HapticFeedback.lightImpact();
        setState(() => _pin += digit);
        if (_pin.length == 6) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() {
                _step = 2;
              });
            }
          });
        }
      }
    } else {
      if (_confirmPin.length < 6) {
        HapticFeedback.lightImpact();
        setState(() {
          _confirmPin += digit;
          _isError = false;
        });
        if (_confirmPin.length == 6) {
          if (_confirmPin == _pin) {
            HapticFeedback.heavyImpact();
            Navigator.pop(context, _pin);
          } else {
            HapticFeedback.heavyImpact();
            _shakeController.forward(from: 0.0);
            setState(() => _isError = true);
            LajuToast.error(context, 'PIN konfirmasi tidak cocok. Silakan coba lagi.');
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) {
                setState(() {
                  _confirmPin = '';
                  _isError = false;
                });
              }
            });
          }
        }
      }
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_step == 1) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() => _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      } else {
        // Go back to step 1
        setState(() {
          _step = 1;
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final currentCode = _step == 1 ? _pin : _confirmPin;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              child: Icon(
                _step == 1 ? Icons.pin_rounded : Icons.check_circle_outline_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _step == 1 ? widget.title : 'Konfirmasi PIN Baru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _step == 1
                  ? 'Masukkan 6-digit angka PIN untuk mengunci aplikasi LAJU'
                  : 'Masukkan ulang 6-digit PIN untuk memastikan kecocokan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Indicator Dots
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset = sin(_shakeController.value * pi * 4) * 10;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final filled = index < currentCode.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? Colors.redAccent
                          : (filled ? AppColors.primary : Colors.transparent),
                      border: Border.all(
                        color: _isError
                            ? Colors.redAccent
                            : (filled ? AppColors.primary : (widget.isDark ? Colors.white38 : const Color(0xFF94A3B8))),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Dialpad
            _DialpadWidget(
              isDark: widget.isDark,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialpadWidget extends StatelessWidget {
  final bool isDark;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _DialpadWidget({
    required this.isDark,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((k) {
              if (k.isEmpty) {
                return const SizedBox(width: 64, height: 50);
              }
              if (k == 'backspace') {
                return InkWell(
                  onTap: onBackspace,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 64,
                    height: 50,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.backspace_outlined,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      size: 22,
                    ),
                  ),
                );
              }
              return InkWell(
                onTap: () => onDigit(k),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 64,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    k,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
