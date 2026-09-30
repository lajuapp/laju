import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/account_controller.dart';

class TwoStepVerificationScreen extends StatefulWidget {
  const TwoStepVerificationScreen({super.key});

  @override
  State<TwoStepVerificationScreen> createState() => _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState extends State<TwoStepVerificationScreen> {
  void _showChangePinSheet(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final currentExpectedPin = AccountController.instance.twoStepPin.isNotEmpty
        ? AccountController.instance.twoStepPin
        : (AppLockController.instance.hasSetPin ? AppLockController.instance.pinCode : '');

    // If an existing PIN is present, require verification first (step 0); otherwise directly step 1.
    int step = currentExpectedPin.isNotEmpty ? 0 : 1; // 0 = verify old, 1 = enter new, 2 = confirm new
    String oldPinInput = '';
    String newPinInput = '';
    String confirmPinInput = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0A1016) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activePin = step == 0
                ? oldPinInput
                : (step == 1 ? newPinInput : confirmPinInput);

            String title;
            String subtitle;
            if (step == 0) {
              title = 'Masukkan PIN Saat Ini';
              subtitle = 'Masukkan PIN 6-digit keamanan Anda saat ini untuk verifikasi.';
            } else if (step == 1) {
              title = context.tr('enterNewPin');
              subtitle = context.tr('pinHelperEnter');
            } else {
              title = context.tr('confirmNewPin');
              subtitle = context.tr('pinHelperConfirm');
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),

                    // Biometric Shortcut Option on Step 0 if available
                    if (step == 0) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        icon: const Icon(Icons.fingerprint_rounded, size: 20),
                        label: const Text(
                          'Verifikasi dengan Biometrik',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: () async {
                          final authenticated = await BiometricService.instance.authenticate(
                            title: 'Verifikasi Keamanan',
                            subtitle: 'Gunakan biometrik untuk melanjutkan perubahan PIN',
                          );
                          if (authenticated) {
                            HapticFeedback.mediumImpact();
                            setSheetState(() {
                              step = 1;
                              oldPinInput = '';
                            });
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // PIN dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < activePin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: filled
                                  ? AppColors.primary
                                  : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Numeric Dialpad Grid
                    _buildMiniDialpad(
                      isDark: isDark,
                      onDigitTap: (digit) {
                        if (step == 0) {
                          if (oldPinInput.length < 6) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => oldPinInput += digit);
                            if (oldPinInput.length == 6) {
                              if (oldPinInput == currentExpectedPin) {
                                HapticFeedback.mediumImpact();
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  setSheetState(() {
                                    step = 1;
                                  });
                                });
                              } else {
                                HapticFeedback.heavyImpact();
                                LajuToast.error(context, context.tr('incorrectPin'));
                                Future.delayed(const Duration(milliseconds: 350), () {
                                  setSheetState(() {
                                    oldPinInput = '';
                                  });
                                });
                              }
                            }
                          }
                        } else if (step == 1) {
                          if (newPinInput.length < 6) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => newPinInput += digit);
                            if (newPinInput.length == 6) {
                              Future.delayed(const Duration(milliseconds: 200), () {
                                setSheetState(() {
                                  step = 2;
                                });
                              });
                            }
                          }
                        } else {
                          if (confirmPinInput.length < 6) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => confirmPinInput += digit);
                            if (confirmPinInput.length == 6) {
                              if (confirmPinInput == newPinInput) {
                                Future.delayed(const Duration(milliseconds: 200), () async {
                                  await AccountController.instance.setTwoStepVerification(
                                    true,
                                    pin: confirmPinInput,
                                  );
                                  await AppLockController.instance.setPinCode(confirmPinInput);
                                  if (mounted && sheetCtx.mounted && context.mounted) {
                                    Navigator.pop(sheetCtx);
                                    LajuToast.success(context, context.tr('pinUpdated'));
                                  }
                                });
                              } else {
                                HapticFeedback.heavyImpact();
                                LajuToast.error(context, context.tr('pinMismatch'));
                                Future.delayed(const Duration(milliseconds: 350), () {
                                  setSheetState(() {
                                    confirmPinInput = '';
                                  });
                                });
                              }
                            }
                          }
                        }
                      },
                      onBackspaceTap: () {
                        HapticFeedback.lightImpact();
                        if (step == 0) {
                          if (oldPinInput.isNotEmpty) {
                            setSheetState(() => oldPinInput = oldPinInput.substring(0, oldPinInput.length - 1));
                          }
                        } else if (step == 1) {
                          if (newPinInput.isNotEmpty) {
                            setSheetState(() => newPinInput = newPinInput.substring(0, newPinInput.length - 1));
                          } else if (currentExpectedPin.isNotEmpty) {
                            setSheetState(() {
                              step = 0;
                              oldPinInput = '';
                            });
                          }
                        } else {
                          if (confirmPinInput.isNotEmpty) {
                            setSheetState(() => confirmPinInput = confirmPinInput.substring(0, confirmPinInput.length - 1));
                          } else {
                            setSheetState(() {
                              step = 1;
                              newPinInput = '';
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMiniDialpad({
    required bool isDark,
    required ValueChanged<String> onDigitTap,
    required VoidCallback onBackspaceTap,
  }) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((k) {
              if (k.isEmpty) {
                return const SizedBox(width: 64, height: 50);
              }
              if (k == 'backspace') {
                return InkWell(
                  onTap: onBackspaceTap,
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
                onTap: () => onDigitTap(k),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 64,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    k,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
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

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('twoStepVerification'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: AccountController.instance,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Hero Status Glass Card (Always Active)
                  LajuGlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Color(0xFF10B981),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr('twoStepStatusOn'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Akun LAJU Anda dilindungi secara kriptografis dengan PIN Keamanan 6-digit. PIN ini wajib digunakan saat login di perangkat baru, otorisasi transfer akun, dan pemulihan cadangan data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Menu: Only Change PIN
                  LajuGlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildActionTile(
                      context,
                      icon: Icons.pin_outlined,
                      iconColor: AppColors.primary,
                      title: context.tr('changePin'),
                      subtitle: 'Perbarui 6-digit PIN keamanan akun Anda',
                      onTap: () => _showChangePinSheet(context),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Privacy Information Notice
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Perlindungan Bebas Email: LAJU tidak memerlukan atau menyimpan email pemulihan demi privasi absolut. Pastikan Anda selalu mengingat PIN Keamanan 6-digit Anda.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
        ),
        onTap: onTap,
      ),
    );
  }
}
