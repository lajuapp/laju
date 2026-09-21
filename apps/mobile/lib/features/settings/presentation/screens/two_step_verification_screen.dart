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
  void _confirmTurnOff(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          context.tr('turnOffConfirmTitle'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          context.tr('turnOffConfirmDesc'),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AccountController.instance.setTwoStepVerification(false);
              LajuToast.info(context, context.tr('twoStepStatusOff'));
            },
            child: Text(context.tr('turnOff'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showPinSetupSheet(BuildContext context, {required bool isChange}) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    String firstPin = '';
    String confirmPin = '';
    int step = 1; // 1 = enter pin, 2 = confirm pin

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
            final activePin = step == 1 ? firstPin : confirmPin;

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
                      step == 1
                          ? (isChange ? context.tr('changePin') : context.tr('enterNewPin'))
                          : context.tr('confirmNewPin'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step == 1
                          ? context.tr('pinHelperEnter')
                          : context.tr('pinHelperConfirm'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // PIN dots indicator (exact same design as Privacy App Lock)
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

                    // Numeric Dialpad Grid (exact same design as Privacy App Lock)
                    _buildMiniDialpad(
                      isDark: isDark,
                      onDigitTap: (digit) {
                        if (step == 1) {
                          if (firstPin.length < 6) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => firstPin += digit);
                            if (firstPin.length == 6) {
                              Future.delayed(const Duration(milliseconds: 250), () {
                                setSheetState(() {
                                  step = 2;
                                });
                              });
                            }
                          }
                        } else {
                          if (confirmPin.length < 6) {
                            HapticFeedback.lightImpact();
                            setSheetState(() => confirmPin += digit);
                            if (confirmPin.length == 6) {
                              if (confirmPin == firstPin) {
                                Future.delayed(const Duration(milliseconds: 250), () {
                                  AccountController.instance.setTwoStepVerification(
                                    true,
                                    pin: confirmPin,
                                  );
                                  if (mounted && sheetCtx.mounted && context.mounted) {
                                    Navigator.pop(sheetCtx);
                                    LajuToast.success(
                                      context,
                                      isChange
                                          ? context.tr('pinUpdated')
                                          : context.tr('twoStepActivated'),
                                    );
                                  }
                                });
                              } else {
                                HapticFeedback.heavyImpact();
                                LajuToast.error(context, context.tr('pinMismatch'));
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  setSheetState(() {
                                    confirmPin = '';
                                  });
                                });
                              }
                            }
                          }
                        }
                      },
                      onBackspaceTap: () {
                        HapticFeedback.lightImpact();
                        if (step == 1) {
                          if (firstPin.isNotEmpty) {
                            setSheetState(() => firstPin = firstPin.substring(0, firstPin.length - 1));
                          }
                        } else {
                          if (confirmPin.isNotEmpty) {
                            setSheetState(
                              () => confirmPin = confirmPin.substring(0, confirmPin.length - 1),
                            );
                          } else {
                            // Go back to step 1
                            setSheetState(() {
                              step = 1;
                              firstPin = '';
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

  void _showChangeRecoveryEmailSheet(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final emailController = TextEditingController(
      text: AccountController.instance.twoStepRecoveryEmail,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.email_outlined, color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('recoveryEmail'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('recoveryEmailSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'email@domain.com',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final email = emailController.text.trim();
                    if (email.isNotEmpty && (!email.contains('@') || !email.contains('.'))) {
                      LajuToast.error(context, 'Please enter a valid email address');
                      return;
                    }
                    Navigator.pop(ctx);
                    AccountController.instance.setTwoStepVerification(
                      true,
                      email: email,
                    );
                    LajuToast.success(context, context.tr('recoveryEmailUpdated'));
                  },
                  child: Text(
                    context.tr('saveEmail'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
              final isEnabled = AccountController.instance.twoStepVerificationEnabled;
              final recoveryEmail = AccountController.instance.twoStepRecoveryEmail;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Hero Status Glass Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: (isEnabled ? const Color(0xFF10B981) : Colors.grey)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isEnabled ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isEnabled ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                            color: isEnabled ? const Color(0xFF10B981) : Colors.grey,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isEnabled ? context.tr('twoStepStatusOn') : context.tr('twoStepStatusOff'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('twoStepDesc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (isEnabled) ...[
                    LajuGlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          // Turn Off Option
                          _buildActionTile(
                            context,
                            icon: Icons.cancel_outlined,
                            iconColor: const Color(0xFFDC2626),
                            title: context.tr('turnOff'),
                            subtitle: context.tr('turnOffSub'),
                            onTap: () => _confirmTurnOff(context),
                          ),
                          Divider(
                            height: 1,
                            indent: 64,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                          ),
                          // Change PIN Option
                          _buildActionTile(
                            context,
                            icon: Icons.pin_outlined,
                            iconColor: AppColors.primary,
                            title: context.tr('changePin'),
                            subtitle: context.tr('changePinSub'),
                            onTap: () => _showPinSetupSheet(context, isChange: true),
                          ),
                          Divider(
                            height: 1,
                            indent: 64,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                          ),
                          // Change Email Option
                          _buildActionTile(
                            context,
                            icon: Icons.alternate_email_rounded,
                            iconColor: AppColors.primary,
                            title: context.tr('changeEmail'),
                            subtitle: recoveryEmail.isNotEmpty ? recoveryEmail : context.tr('recoveryEmailSub'),
                            onTap: () => _showChangeRecoveryEmailSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shield_outlined, size: 20),
                        label: Text(
                          context.tr('turnOnTwoStep'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => _showPinSetupSheet(context, isChange: false),
                      ),
                    ),
                  ],
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
