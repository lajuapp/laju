import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../lock/presentation/screens/app_lock_screen.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final AppLockController _lockCtrl = AppLockController.instance;

  void _showTimeoutDialog(BuildContext context, bool isDark) {
    final timeouts = [
      {'id': 'immediately', 'label': 'Segera (Immediately)'},
      {'id': '1_min', 'label': 'Setelah 1 menit (After 1 min)'},
      {'id': '15_min', 'label': 'Setelah 15 menit (After 15 mins)'},
      {'id': '1_hour', 'label': 'Setelah 1 jam (After 1 hour)'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Kunci Otomatis',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: timeouts.map((t) {
            final isSelected = _lockCtrl.autoLockTimeout == t['id'];
            return RadioListTile<String>(
              value: t['id']!,
              groupValue: _lockCtrl.autoLockTimeout,
              activeColor: AppColors.primary,
              title: Text(
                t['label']!,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              onChanged: (val) {
                if (val != null) {
                  _lockCtrl.setAutoLockTimeout(val);
                  Navigator.pop(ctx);
                  LajuToast.info(context, 'Waktu kunci otomatis diperbarui');
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _handleUbahPin(BuildContext context) async {
    // If PIN is already set, require authentication first
    if (_lockCtrl.hasSetPin) {
      bool authOk = false;

      // Try Biometric if active
      if (_lockCtrl.isBiometricEnabled) {
        final canBio = await BiometricService.instance.canAuthenticate();
        if (canBio) {
          authOk = await BiometricService.instance.authenticate(
            title: 'Verifikasi Biometrik',
            subtitle: 'Pindai sidik jari Anda untuk mengubah PIN',
          );
        }
      }

      // If biometric was inactive, failed, or cancelled, prompt for current PIN
      if (!authOk) {
        if (!context.mounted) return;
        authOk = await SecurityAuthHelper.promptVerifyPin(
          context,
          title: 'Masukkan PIN Saat Ini',
          subtitle: 'Masukkan 6-digit PIN lama Anda untuk melanjutkan',
        );
      }

      if (!authOk) {
        return;
      }
    }

    if (!context.mounted) return;

    // After successful verification, enter and confirm new PIN
    final newPin = await SecurityAuthHelper.promptSetupPin(
      context,
      title: 'Atur PIN Baru (6-digit)',
    );

    if (newPin != null && newPin.length == 6) {
      await _lockCtrl.setPinCode(newPin);
      if (context.mounted) {
        LajuToast.success(context, 'PIN berhasil diperbarui!');
      }
    }
  }

  String _formatTimeoutLabel(String id) {
    switch (id) {
      case '1_min':
        return 'Setelah 1 menit';
      case '15_min':
        return 'Setelah 15 menit';
      case '1_hour':
        return 'Setelah 1 jam';
      case 'immediately':
      default:
        return 'Segera';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kunci Aplikasi & Biometrik',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _lockCtrl,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Header Security Badge Glass Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Perlindungan Kunci LAJU',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kunci aplikasi untuk mengamankan obrolan dan data rahasia dari akses yang tidak berwenang pada perangkat ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Master Switch Card: Kunci Aplikasi
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 22),
                        ),
                        title: Text(
                          'Kunci Aplikasi',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _lockCtrl.isAppLockEnabled
                              ? 'Kunci aktif. Autentikasi diperlukan saat membuka LAJU.'
                              : 'Kunci dinonaktifkan. Aplikasi dapat langsung dibuka.',
                          style: TextStyle(fontSize: 12.5, color: textSecondary),
                        ),
                        value: _lockCtrl.isAppLockEnabled,
                        onChanged: (val) async {
                          if (val) {
                            // 1. If PIN is not set yet, require setting PIN first!
                            if (!_lockCtrl.hasSetPin) {
                              final newPin = await SecurityAuthHelper.promptSetupPin(
                                context,
                                title: 'Buat PIN Kunci Aplikasi',
                              );
                              if (newPin == null || newPin.length != 6) {
                                if (context.mounted) {
                                  LajuToast.warning(context, 'Pembuatan PIN dibatalkan. Kunci aplikasi belum aktif.');
                                }
                                return;
                              }
                              await _lockCtrl.setPinCode(newPin);
                            }

                            // 2. Check if device supports Biometrics. If so, verify biometric first!
                            final canBio = await BiometricService.instance.canAuthenticate();
                            if (canBio) {
                              final bioOk = await BiometricService.instance.authenticate(
                                title: 'Verifikasi Biometrik',
                                subtitle: 'Pindai sidik jari atau wajah Anda untuk mengaktifkan kunci aplikasi',
                              );
                              if (bioOk) {
                                await _lockCtrl.setBiometricEnabled(true);
                              } else {
                                await _lockCtrl.setBiometricEnabled(false);
                                if (context.mounted) {
                                  LajuToast.info(context, 'Biometrik belum aktif. Kunci aplikasi menggunakan PIN.');
                                }
                              }
                            } else {
                              await _lockCtrl.setBiometricEnabled(false);
                            }

                            // 3. Enable App Lock
                            await _lockCtrl.setAppLockEnabled(true);
                            if (context.mounted) {
                              LajuToast.success(context, 'Kunci aplikasi berhasil diaktifkan');
                            }
                          } else {
                            // Require authentication before disabling App Lock
                            final authOk = await SecurityAuthHelper.authenticate(
                              context,
                              title: 'Nonaktifkan Kunci Aplikasi',
                              subtitle: 'Konfirmasi identitas Anda untuk menonaktifkan kunci aplikasi',
                            );
                            if (authOk) {
                              await _lockCtrl.setAppLockEnabled(false);
                              if (context.mounted) {
                                LajuToast.info(context, 'Kunci aplikasi dinonaktifkan');
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),

                  // Options when App Lock is Enabled
                  if (_lockCtrl.isAppLockEnabled) ...[
                    const SizedBox(height: 16),
                    LajuGlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          children: [
                            // Biometric Unlock Switch (ON/OFF)
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _lockCtrl.isBiometricEnabled
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.fingerprint_rounded,
                                  color: _lockCtrl.isBiometricEnabled ? AppColors.primary : Colors.grey,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                'Buka dengan Sidik Jari (Biometrik)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                _lockCtrl.isBiometricEnabled
                                    ? 'Sidik jari aktif untuk membuka kunci cepat (bisa dialihkan ke PIN).'
                                    : 'Biometrik nonaktif. Default membuka langsung menggunakan PIN.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _lockCtrl.isBiometricEnabled ? textSecondary : AppColors.primaryDark,
                                  fontWeight: _lockCtrl.isBiometricEnabled ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                              value: _lockCtrl.isBiometricEnabled,
                              onChanged: (val) async {
                                if (val) {
                                  final canAuth = await BiometricService.instance.canAuthenticate();
                                  if (!canAuth) {
                                    if (context.mounted) {
                                      LajuToast.error(
                                        context,
                                        'Perangkat tidak mendukung biometrik atau belum ada sidik jari terdaftar.',
                                      );
                                    }
                                    return;
                                  }
                                  final authOk = await BiometricService.instance.authenticate(
                                    title: 'Verifikasi Sidik Jari',
                                    subtitle: 'Pindai sidik jari Anda untuk mengaktifkan',
                                  );
                                  if (!authOk) {
                                    if (context.mounted) {
                                      LajuToast.error(context, 'Verifikasi biometrik dibatalkan atau gagal');
                                    }
                                    return;
                                  }
                                  await _lockCtrl.setBiometricEnabled(true);
                                  if (context.mounted) {
                                    LajuToast.info(context, 'Sidik jari diaktifkan');
                                  }
                                } else {
                                  // Require authentication before disabling biometric
                                  final authOk = await SecurityAuthHelper.authenticate(
                                    context,
                                    title: 'Nonaktifkan Biometrik',
                                    subtitle: 'Konfirmasi identitas Anda untuk menonaktifkan biometrik',
                                  );
                                  if (authOk) {
                                    await _lockCtrl.setBiometricEnabled(false);
                                    if (context.mounted) {
                                      LajuToast.info(
                                        context,
                                        'Biometrik dinonaktifkan. Pembuka kunci sekarang menggunakan PIN.',
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 64,
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                            ),

                            // Change PIN Tile
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.pin_rounded, color: AppColors.cyan, size: 22),
                              ),
                              title: Text(
                                'Ubah PIN Kunci',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              subtitle: Text(
                                _lockCtrl.hasSetPin
                                    ? 'PIN 6-digit aktif (Otorisasi diperlukan untuk mengubah)'
                                    : 'PIN belum diatur (Ketuk untuk membuat)',
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                              ),
                              onTap: () => _handleUbahPin(context),
                            ),
                            Divider(
                              height: 1,
                              indent: 64,
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                            ),

                            // Auto-Lock Timeout Tile
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.timer_outlined, color: Colors.amber, size: 22),
                              ),
                              title: Text(
                                'Kunci Otomatis',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              subtitle: Text(
                                _formatTimeoutLabel(_lockCtrl.autoLockTimeout),
                                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                              ),
                              onTap: () => _showTimeoutDialog(context, isDark),
                            ),
                            Divider(
                              height: 1,
                              indent: 64,
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                            ),

                            // Notification Preview Switch
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.visibility_off_outlined, color: Colors.purpleAccent, size: 22),
                              ),
                              title: Text(
                                'Tampilkan Isi di Notifikasi',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              subtitle: Text(
                                'Tampilkan pratinjau pesan dan pengirim saat aplikasi terkunci',
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                              value: _lockCtrl.showNotificationPreview,
                              onChanged: (val) {
                                _lockCtrl.setShowNotificationPreview(val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Test App Lock Screen Button
                    LajuGlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 24),
                          ),
                          title: Text(
                            'Uji Layar Kunci Sekarang',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _lockCtrl.isBiometricEnabled
                                ? 'Membuka layar kunci (Mode Sidik Jari + Dialpad)'
                                : 'Membuka layar kunci (Mode Default Dialpad PIN)',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AppLockScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
