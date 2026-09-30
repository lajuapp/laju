import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/auth_controller.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _recoveryKeyController = TextEditingController();
  bool _isLoading = false;
  String? _activeMigrationId;
  BiometricAvailability? _biometricInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      setState(() {});
    });
    _recoveryKeyController.addListener(() => setState(() {}));
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final info = await BiometricService.instance.checkAvailability();
      if (mounted) {
        setState(() => _biometricInfo = info);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        _recoveryKeyController.text = data.text!.trim();
        HapticFeedback.lightImpact();
        if (mounted) {
          LajuToast.info(context, 'Kunci berhasil ditempel dari papan klip');
        }
      } else {
        if (mounted) {
          LajuToast.warning(context, 'Papan klip kosong');
        }
      }
    } catch (_) {}
  }

  /// Flow 1: Device Cryptographic Authentication (Biometrics or 6-digit PIN)
  Future<void> _handleDeviceKeystoreAuth() async {
    HapticFeedback.lightImpact();

    final availability =
        _biometricInfo ?? await BiometricService.instance.checkAvailability();
    bool authenticated = false;

    // Only prompt pre-biometric/PIN if device is already configured with local PIN/session
    if (AppLockController.instance.hasSetPin) {
      if (availability.isAvailable) {
        final bioLabel = availability.biometricLabel.isNotEmpty
            ? availability.biometricLabel
            : 'Sidik Jari / Wajah';

        authenticated = await BiometricService.instance.authenticate(
          title: 'Verifikasi Pemilik Perangkat',
          subtitle: 'Pindai $bioLabel atau kunci layar HP ini',
          description:
              'Autentikasi biometrik diperlukan untuk memastikan Anda adalah pemilik sah HP ini sebelum masuk.',
          allowDeviceCredential: true,
          negativeButtonText: 'Batal',
        );

        if (!authenticated) {
          if (mounted) {
            LajuToast.error(
              context,
              'Autentikasi biometrik tidak berhasil atau dibatalkan. Akses masuk ditolak.',
            );
          }
          return;
        }
      } else {
        authenticated = await SecurityAuthHelper.promptVerifyPin(
          context,
          title: 'Verifikasi PIN Keamanan',
          subtitle:
              'HP tidak mendukung biometrik. Masukkan 6-digit PIN Anda untuk masuk',
        );

        if (!authenticated) {
          if (mounted) {
            LajuToast.error(
              context,
              'Autentikasi PIN tidak berhasil. Akses login perangkat ditolak.',
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final success =
          await AuthController.instance.authenticateDeviceKeystoreAsync();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        LajuToast.success(context, context.tr('deviceAuthSuccess'));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else if (AuthController.instance.needsPinReattest) {
        // Hardware Device is registered on server! Prompt user for their 6-digit PIN
        final username = AuthController.instance.reattestUsername ?? 'Anda';
        final pin = await SecurityAuthHelper.promptEnterPin(
          context,
          title: 'Verifikasi PIN Keamanan',
          subtitle: 'Perangkat ini terdaftar atas akun "$username". Masukkan 6-digit PIN Anda untuk masuk',
        );

        if (pin != null && pin.length == 6) {
          if (!mounted) return;
          setState(() => _isLoading = true);

          final pinSuccess = await AuthController.instance.authenticateDeviceWithPinAsync(pin: pin);

          if (!mounted) return;
          setState(() => _isLoading = false);

          if (pinSuccess) {
            await AppLockController.instance.setPinCode(pin);
            await AppLockController.instance.setAppLockEnabled(true);
            if (availability.isAvailable) {
              await AppLockController.instance.setBiometricEnabled(true);
            }

            LajuToast.success(context, context.tr('deviceAuthSuccess'));
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            final errorMsg = AuthController.instance.lastAuthError;
            LajuToast.error(context, errorMsg ?? 'PIN Keamanan salah');
          }
        }
      } else {
        LajuToast.warning(
          context,
          'Perangkat ini belum terdaftar di sistem. Silakan masuk menggunakan Kunci Pemulihan pada tab "Kunci Rahasia" atau Daftar baru.',
        );
        _tabController.animateTo(2);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LajuToast.error(context, '${context.tr('authFailed')}: $e');
      }
    }
  }

  /// Flow 2: QR Migration Handshake (Move from Old Phone)
  Future<void> _startMigrationHandshake() async {
    HapticFeedback.lightImpact();

    final scannedPayload = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const LajuQrScannerScreen(
          title: 'Pindai Kode QR Migrasi',
          promptText: 'Arahkan kamera ke kode QR pada HP lama Anda',
        ),
      ),
    );
    if (scannedPayload == null) return;

    setState(() => _isLoading = true);

    String migrationId = '';
    if (scannedPayload.startsWith('laju://migrate/')) {
      migrationId = scannedPayload
          .replaceFirst('laju://migrate/', '')
          .split('?')
          .first
          .trim();
    } else if (scannedPayload.contains('mig-')) {
      final match = RegExp(r'mig-[a-zA-Z0-9_-]+').firstMatch(scannedPayload);
      if (match != null) migrationId = match.group(0)!;
    } else if (scannedPayload.startsWith('laju://')) {
      setState(() => _isLoading = false);
      final contactUser =
          scannedPayload.replaceFirst('laju://', '').split('?').first;
      LajuToast.error(
        context,
        'Ini kode QR kontak (@$contactUser), bukan QR Migrasi Akun. Untuk migrasi, buka menu Pengaturan > Keamanan > Migrasi Perangkat di HP lama Anda.',
      );
      return;
    } else {
      migrationId = scannedPayload.trim();
    }
    _activeMigrationId = migrationId;

    final joinRes = await AuthController.instance.joinMigrationAsync(
      migrationId: migrationId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (joinRes == null || joinRes['sasCode'] == null) {
      LajuToast.error(context, context.tr('migrationCommitFailed'));
      return;
    }

    final sasCode = joinRes['sasCode'].toString();
    _showSasVerificationBottomSheet(sasCode, migrationId);
  }

  void _showSasVerificationBottomSheet(String sasCode, String migrationId) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                14,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
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
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    context.tr('sasModalTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    context.tr('sasModalDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        sasCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);

                        final success = await AuthController.instance
                            .commitMigrationAsync(
                          migrationId: migrationId,
                          sasCode: sasCode,
                        );

                        if (!mounted) return;
                        setState(() => _isLoading = false);

                        if (success) {
                          if (!AppLockController.instance.hasSetPin) {
                            final newPin =
                                await SecurityAuthHelper.promptSetupPin(
                              context,
                              title: 'Atur PIN Keamanan (6-Digit)',
                            );
                            if (newPin != null && newPin.length == 6) {
                              await AppLockController.instance
                                  .setPinCode(newPin);
                              await AppLockController.instance
                                  .setAppLockEnabled(true);
                            }
                          }
                          if (mounted) {
                            LajuToast.success(
                              context,
                              context.tr('migrationSuccess'),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                              (route) => false,
                            );
                          }
                        } else {
                          LajuToast.error(
                              context, context.tr('migrationCommitFailed'));
                        }
                      },
                      child: Text(
                        context.tr('sasConfirmButton'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Flow 3: Restore with Identity Secret / Seed Phrase
  Future<void> _handleRestoreSecret() async {
    HapticFeedback.lightImpact();
    final secret = _recoveryKeyController.text.trim();
    if (secret.isEmpty) {
      LajuToast.error(context, context.tr('fillAllRequired'));
      return;
    }

    // Prompt user to enter their existing 6-digit security PIN
    final pin = await SecurityAuthHelper.promptEnterPin(
      context,
      title: 'Masukkan PIN Keamanan (6-Digit)',
      subtitle: 'Masukkan 6-digit PIN yang telah Anda buat saat pendaftaran akun',
    );
    if (pin == null || pin.length != 6) {
      if (mounted) {
        LajuToast.warning(context, 'PIN Keamanan 6-digit wajib dimasukkan untuk verifikasi');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthController.instance
          .restoreWithIdentitySecretAsync(secret, pin: pin);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        await _onRestoreSuccess(pin);
      } else if (result.requiresApproval && result.requestId != null) {
        _showWaitingForApprovalSheet(
          requestId: result.requestId!,
          activeDeviceName: result.activeDeviceName ?? 'Perangkat Utama',
          expiresAt: result.expiresAt,
          secret: secret,
          pin: pin,
        );
      } else {
        final errorMsg = result.errorMessage ?? AuthController.instance.lastAuthError;
        LajuToast.error(
          context,
          (errorMsg != null && errorMsg.isNotEmpty)
              ? errorMsg
              : context.tr('authFailed'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LajuToast.error(context, '${context.tr('authFailed')}: $e');
      }
    }
  }

  Future<void> _onRestoreSuccess(String pin) async {
    await AppLockController.instance.setPinCode(pin);
    await AppLockController.instance.setAppLockEnabled(true);

    final bioAvailability = await BiometricService.instance.checkAvailability();
    if (bioAvailability.isAvailable) {
      await AppLockController.instance.setBiometricEnabled(true);
    }

    if (mounted) {
      LajuToast.success(context, context.tr('deviceAuthSuccess'));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showWaitingForApprovalSheet({
    required String requestId,
    required String activeDeviceName,
    DateTime? expiresAt,
    required String secret,
    required String pin,
  }) async {
    Timer? pollTimer;
    Timer? countdownTimer;
    int secondsLeft = 180;
    if (expiresAt != null) {
      final diff = expiresAt.difference(DateTime.now()).inSeconds;
      secondsLeft = diff > 0 ? diff : 0;
    }

    bool isDone = false;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (countdownTimer == null) {
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (secondsLeft <= 1) {
                  t.cancel();
                  pollTimer?.cancel();
                  if (!isDone && mounted) {
                    Navigator.of(sheetContext).pop();
                    LajuToast.warning(
                      sheetContext,
                      'Waktu otorisasi telah habis. Silakan coba lagi atau gunakan pemulihan darurat.',
                    );
                  }
                } else {
                  setSheetState(() => secondsLeft--);
                }
              });

              pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
                if (isDone) return;
                final statusRes =
                    await AuthController.instance.checkTransferStatusAsync(requestId);
                if (statusRes != null && mounted) {
                  final status = statusRes['status'];
                  if (status == 'APPROVED') {
                    isDone = true;
                    t.cancel();
                    countdownTimer?.cancel();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                    await _onRestoreSuccess(pin);
                  } else if (status == 'REJECTED') {
                    isDone = true;
                    t.cancel();
                    countdownTimer?.cancel();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                      LajuToast.error(
                        context,
                        'Permintaan transfer ditolak oleh perangkat utama Anda demi keamanan akun.',
                      );
                    }
                  } else if (status == 'EXPIRED') {
                    isDone = true;
                    t.cancel();
                    countdownTimer?.cancel();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                      LajuToast.warning(
                        context,
                        'Waktu otorisasi telah berakhir.',
                      );
                    }
                  }
                }
              });
            }

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              backgroundColor: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          const Icon(
                            Icons.phonelink_ring_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Menunggu Otorisasi Perangkat',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Permintaan transfer telah dikirim ke perangkat utama Anda ($activeDeviceName).\nSilakan buka aplikasi LAJU di HP tersebut dan ketuk "Izinkan & Pindah".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Text(
                            'Sisa waktu: ${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: sheetContext,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('HP Lama Tidak Dapat Diakses?'),
                            content: const Text(
                              'Gunakan opsi darurat ini jika HP lama Anda hilang, rusak, atau tidak bisa diakses.\n\nAkun akan segera dipindahkan ke perangkat ini menggunakan PIN Keamanan Anda, dan sesi di HP lama akan langsung dinonaktifkan.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Aktifkan Darurat'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted && sheetContext.mounted) {
                          isDone = true;
                          countdownTimer?.cancel();
                          pollTimer?.cancel();
                          Navigator.of(sheetContext).pop();
                          _handleEmergencyOverride(secret: secret, pin: pin);
                        }
                      },
                      icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                      label: const Text('HP lama hilang atau tidak dapat diakses?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        isDone = true;
                        countdownTimer?.cancel();
                        pollTimer?.cancel();
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Batalkan'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    isDone = true;
    countdownTimer?.cancel();
    pollTimer?.cancel();
  }

  Future<void> _handleEmergencyOverride({
    required String secret,
    required String pin,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthController.instance.restoreWithIdentitySecretAsync(
        secret,
        pin: pin,
        emergencyOverride: true,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        await _onRestoreSuccess(pin);
      } else {
        final errorMsg = AuthController.instance.lastAuthError;
        LajuToast.error(
          context,
          (errorMsg != null && errorMsg.isNotEmpty)
              ? errorMsg
              : 'Gagal memulihkan akun secara darurat',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LajuToast.error(context, 'Terjadi kesalahan: $e');
      }
    }
  }

  VoidCallback? _getBottomButtonAction() {
    switch (_tabController.index) {
      case 0:
        return _handleDeviceKeystoreAuth;
      case 1:
        return _startMigrationHandshake;
      case 2:
        return _handleRestoreSecret;
      default:
        return _handleDeviceKeystoreAuth;
    }
  }

  String _getBottomButtonLabel(bool isBioAvailable, String bioLabel) {
    if (_isLoading) {
      switch (_tabController.index) {
        case 0:
          return 'Memverifikasi Perangkat...';
        case 1:
          return 'Menghubungkan Perangkat...';
        case 2:
          return 'Memulihkan Akun...';
        default:
          return 'Memproses...';
      }
    }

    switch (_tabController.index) {
      case 0:
        return isBioAvailable ? 'Masuk dengan $bioLabel' : 'Masuk dengan PIN';
      case 1:
        return 'Pindai Kode QR HP Lama';
      case 2:
        return 'Pulihkan Akun';
      default:
        return 'Lanjutkan';
    }
  }

  IconData _getBottomButtonIcon(bool isBioAvailable, bool hasFace) {
    switch (_tabController.index) {
      case 0:
        return isBioAvailable
            ? (hasFace ? Icons.face_rounded : Icons.fingerprint_rounded)
            : Icons.lock_outline_rounded;
      case 1:
        return Icons.camera_alt_outlined;
      case 2:
        return Icons.restore_page_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    final isBioAvailable = _biometricInfo?.isAvailable == true;
    final hasFace = _biometricInfo?.hasFace == true &&
        _biometricInfo?.hasFingerprint != true;
    final bioLabel = isBioAvailable
        ? (_biometricInfo?.biometricLabel.isNotEmpty == true
            ? _biometricInfo!.biometricLabel
            : (hasFace ? 'Pengenalan Wajah' : 'Sidik Jari'))
        : 'PIN Keamanan';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Masuk',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13.5,
          ),
          tabs: [
            Tab(text: context.tr('deviceAuthTab')),
            Tab(text: context.tr('qrMigrationTab')),
            Tab(text: context.tr('recoverySecretTab')),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Device Replaced Banner ─────────────────────────────────────
            ListenableBuilder(
              listenable: AuthController.instance,
              builder: (context, _) {
                if (!AuthController.instance.isDeviceReplaced) {
                  return const SizedBox.shrink();
                }
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFFFF3CD),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, color: Color(0xFF856404), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Akun kamu baru saja masuk di perangkat lain. Masuk kembali untuk melanjutkan.',
                          style: const TextStyle(
                            color: Color(0xFF856404),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // ──────────────────────────────────────────────────────────────

            // Tab Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDeviceKeystoreTab(isDark, cardColor, textPrimary, textSecondary, isBioAvailable, bioLabel, hasFace),
                  _buildQrMigrationTab(isDark, cardColor, textPrimary, textSecondary),
                  _buildRecoverySecretTab(isDark, cardColor, textPrimary, textSecondary),
                ],
              ),
            ),

            // Fixed Bottom Action Area (Consistent across all tabs)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _getBottomButtonAction(),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(_getBottomButtonIcon(isBioAvailable, hasFace), size: 20),
                      label: Text(
                        _getBottomButtonLabel(isBioAvailable, bioLabel),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('dontHaveAccount'),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          // Route through Get Started / Onboarding to review TnC and concepts
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingScreen(),
                            ),
                          );
                        },
                        child: Text(
                          context.tr('register'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tab 0: Perangkat Ini (Biometric / PIN)
  Widget _buildDeviceKeystoreTab(
      bool isDark,
      Color cardColor,
      Color textPrimary,
      Color textSecondary,
      bool isBioAvailable,
      String bioLabel,
      bool hasFace) {
    final mainIcon = isBioAvailable
        ? (hasFace ? Icons.face_rounded : Icons.fingerprint_rounded)
        : Icons.lock_outline_rounded;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  mainIcon,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isBioAvailable ? 'Masuk dengan $bioLabel' : 'Masuk dengan PIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            isBioAvailable
                ? 'Verifikasi biometrik pemilik untuk membuka kunci akun kriptografis yang tersimpan di HP ini.'
                : 'Masukkan 6-digit PIN keamanan layar Anda untuk membuka akun di perangkat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hardware Enclave Terlindungi',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kunci privat terikat di Android Keystore / Secure Enclave',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 22,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        mainIcon,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBioAvailable ? 'Sensor $bioLabel Siap' : 'PIN Keamanan Aktif',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBioAvailable
                                ? 'Ketuk tombol di bawah untuk memindai'
                                : 'Verifikasi PIN 6-digit untuk membuka sesi',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              'Ingin transfer akun dari HP lain? Pilih tab "Pindah via QR"',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Pindah via QR (QR Migration)
  Widget _buildQrMigrationTab(
      bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Pindah Akun dari HP Lama',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Transfer akun secara instan dan terenkripsi peer-to-peer tanpa melalui server penyimpanan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildGuideItem(
                  number: '1',
                  title: 'Buka HP Lama',
                  subtitle: 'Buka aplikasi LAJU yang aktif di HP lama Anda.',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                Divider(
                  height: 22,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
                _buildGuideItem(
                  number: '2',
                  title: 'Tampilkan QR Migrasi',
                  subtitle: 'Masuk ke Pengaturan > Keamanan > Pindah Perangkat.',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                Divider(
                  height: 22,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
                _buildGuideItem(
                  number: '3',
                  title: 'Pindai Kode QR',
                  subtitle: 'Ketuk tombol di bawah dan arahkan kamera ke HP lama.',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_clock_outlined,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Dilindungi verifikasi angka SAS (Short Authentication String)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem({
    required String number,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tab 2: Kunci Cadangan (Recovery Secret)
  Widget _buildRecoverySecretTab(
      bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final hasText = _recoveryKeyController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: Color(0xFFF59E0B),
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Pulihkan Kunci Cadangan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Gunakan 32-byte secret atau recovery seed jika HP lama hilang atau rusak total.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KUNCI IDENTITAS RAHASIA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: _pasteFromClipboard,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.content_paste_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tempel',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recoveryKeyController,
                  maxLines: 3,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('recoveryKeyInputHint'),
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                          : const Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBackground
                        : const Color(0xFFF9FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _recoveryKeyController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Kunci dihitung secara lokal dan tidak dikirim ke server',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
