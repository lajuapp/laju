import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/auth_controller.dart';

class TransferApprovalBottomSheet extends StatefulWidget {
  final String requestId;
  final String targetDeviceName;
  final String targetPlatform;
  final DateTime? expiresAt;

  const TransferApprovalBottomSheet({
    super.key,
    required this.requestId,
    required this.targetDeviceName,
    required this.targetPlatform,
    this.expiresAt,
  });

  static bool _isOpen = false;
  static bool get isOpen => _isOpen;

  static Future<void> show(
    BuildContext context, {
    required String requestId,
    required String targetDeviceName,
    required String targetPlatform,
    DateTime? expiresAt,
  }) async {
    if (_isOpen) return;
    _isOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => TransferApprovalBottomSheet(
          requestId: requestId,
          targetDeviceName: targetDeviceName,
          targetPlatform: targetPlatform,
          expiresAt: expiresAt,
        ),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  State<TransferApprovalBottomSheet> createState() => _TransferApprovalBottomSheetState();
}

class _TransferApprovalBottomSheetState extends State<TransferApprovalBottomSheet> {
  bool _isProcessing = false;
  int _secondsLeft = 180;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      final diff = widget.expiresAt!.difference(DateTime.now()).inSeconds;
      _secondsLeft = diff > 0 ? diff : 0;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);
    try {
      await AuthController.instance.respondToTransferRequestAsync(
        requestId: widget.requestId,
        action: 'REJECT',
      );
      if (mounted) {
        Navigator.of(context).pop();
        LajuToast.warning(
          context,
          'Permintaan transfer ditolak. Jika bukan Anda yang mencoba, segera periksa PIN Keamanan Anda.',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleApprove() async {
    // Authenticate current user via biometric or PIN before approving transfer
    final isAuth = await SecurityAuthHelper.authenticate(
      context,
      title: 'Konfirmasi Pemindahan Akun',
      subtitle: 'Verifikasi identitas Anda untuk mengizinkan pemindahan akun ke perangkat baru',
    );

    if (!isAuth) {
      if (mounted) {
        LajuToast.error(context, 'Verifikasi identitas gagal');
      }
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final ok = await AuthController.instance.respondToTransferRequestAsync(
        requestId: widget.requestId,
        action: 'APPROVE',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (ok) {
        // Invalidate current device session and return to login screen
        AuthController.instance.handleDeviceReplaced();
      } else {
        if (mounted) {
          LajuToast.error(context, 'Gagal mengizinkan transfer. Silakan coba lagi.');
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isIos = widget.targetPlatform.toLowerCase() == 'ios';

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
            // Top Drag Handle
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

            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Otorisasi Perangkat Baru',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sisa waktu: ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              'Perangkat lain sedang mencoba memulihkan akun Anda menggunakan Kunci Pemulihan / Identity Secret.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Device Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isIos ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.targetDeviceName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Platform: ${widget.targetPlatform.toUpperCase()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Warning Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Jika Anda mengizinkan, perangkat ini akan otomatis dinonaktifkan (log out) dan seluruh sesi lokal akan dibersihkan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Tolak',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Izinkan & Pindah',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
