import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../auth/domain/auth_controller.dart';
import '../../../auth/presentation/screens/welcome_screen.dart';

class DeviceMigrationScreen extends StatefulWidget {
  const DeviceMigrationScreen({super.key});

  @override
  State<DeviceMigrationScreen> createState() => _DeviceMigrationScreenState();
}

class _DeviceMigrationScreenState extends State<DeviceMigrationScreen> {
  bool _isLoading = true;
  String? _migrationId;
  String? _sasCode;
  String _migrationStatus = 'PREPARED';
  Timer? _pollTimer;
  int _secondsLeft = 300;
  Timer? _countdownTimer;

  bool _isBiometricAuthorized = false;

  @override
  void initState() {
    super.initState();
    _authorizeAndStartMigration();
  }

  Future<void> _authorizeAndStartMigration() async {
    setState(() => _isLoading = true);
    final authOk = await SecurityAuthHelper.authenticate(
      context,
      title: 'Otorisasi Migrasi Akun',
      subtitle: 'Pindai sidik jari atau masukkan PIN untuk otorisasi migrasi',
    );
    if (authOk) {
      if (mounted) {
        setState(() => _isBiometricAuthorized = true);
        _startMigrationSession();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBiometricAuthorized = false;
        });
        LajuToast.warning(context, 'Otorisasi keamanan diperlukan untuk migrasi akun');
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMigrationSession() async {
    setState(() => _isLoading = true);
    final res = await AuthController.instance.startMigrationSessionAsync();
    if (mounted) {
      setState(() {
        _migrationId = res?['migrationId'] ?? 'mig-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
        _migrationStatus = 'PREPARED';
        _isLoading = false;
        _secondsLeft = 300;
      });
      _startTimers();
    }
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _migrationStatus = 'EXPIRED');
      } else {
        setState(() => _secondsLeft--);
      }
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_migrationId == null || _migrationStatus == 'EXPIRED' || _migrationStatus == 'COMMITTED') {
        return;
      }
      final statusRes = await AuthController.instance.pollMigrationStatusAsync(_migrationId!);
      if (statusRes != null && mounted) {
        final newStatus = statusRes['status'] as String? ?? _migrationStatus;
        final sas = statusRes['sasCode'] as String?;
        if (sas != null && sas.isNotEmpty && _sasCode != sas) {
          setState(() {
            _sasCode = sas;
            _migrationStatus = newStatus;
          });
          HapticFeedback.mediumImpact();
        } else if (newStatus != _migrationStatus) {
          setState(() => _migrationStatus = newStatus);
        }

        if (newStatus == 'COMMITTED') {
          timer.cancel();
          _countdownTimer?.cancel();
          _handleMigrationCommitted();
        }
      }
    });
  }


  Future<void> _confirmSasMatch() async {
    if (_migrationId == null || _sasCode == null) return;
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final ok = await AuthController.instance.verifyMigrationHostAsync(_migrationId!, _sasCode!);
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        _handleMigrationCommitted();
      }
    }
  }

  void _handleMigrationCommitted() {
    final titleText = context.tr('migrationSuccess');
    final noticeText = context.tr('migrationCompleteLogoutNotice');
    final doneLabel = context.tr('done');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          noticeText,
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 150));
              AuthController.instance.logout();
              AppNavigation.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: Text(doneLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    final timerString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('startMigrationTitle'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Header Glass Card with QR Code
                LajuGlassCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(22),
                  blurSigma: 18,
                  child: Column(
                    children: [
                      Text(
                        context.tr('migrationHostDesc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // QR Code Container
                      if (_isLoading)
                        const SizedBox(
                          height: 220,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (!_isBiometricAuthorized)
                        Container(
                          height: 220,
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 48),
                              const SizedBox(height: 10),
                              Text(
                                'Otorisasi Biometrik Diperlukan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pindai sidik jari atau wajah Anda untuk menghasilkan kode QR migrasi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                                label: const Text('Otorisasi Biometrik'),
                                onPressed: _authorizeAndStartMigration,
                              ),
                            ],
                          ),
                        )
                      else if (_migrationStatus == 'EXPIRED')
                        Container(
                          height: 220,
                          width: 220,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_off_rounded, color: AppColors.danger, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('qrCodeExpired'),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _startMigrationSession,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text(context.tr('refreshQr')),
                              ),
                            ],
                          ),
                        )
                      else
                        LajuQrCodeView(
                          data: 'laju://migrate/${_migrationId ?? 'mig'}',
                          size: 216,
                        ),

                      const SizedBox(height: 16),

                      // Countdown Timer Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              timerString,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // SAS Code Section (When Target joins)
                if (_sasCode != null)
                  LajuGlassCard(
                    borderRadius: 22,
                    padding: const EdgeInsets.all(20),
                    blurSigma: 16,
                    borderColor: AppColors.primary,
                    borderWidth: 1.5,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('confirmMigrationOldPhone'),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('sasModalDesc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Large SAS Display Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black45 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _sasCode!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Confirm Transfer Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _confirmSasMatch,
                            child: Text(
                              context.tr('sasConfirmButton'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  LajuGlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(16),
                    blurSigma: 12,
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            context.tr('waitingForNewPhoneScan'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

