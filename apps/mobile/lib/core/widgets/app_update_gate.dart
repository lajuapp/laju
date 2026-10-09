import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/app_update_controller.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import 'laju_button.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> with WidgetsBindingObserver {
  final AppUpdateController _updateCtrl = AppUpdateController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateCtrl.checkForUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _updateCtrl,
      builder: (context, _) {
        final shouldShow = _updateCtrl.shouldShowGate;
        final status = _updateCtrl.status;
        final isOptional = status == AppUpdateStatus.optionalUpdate;

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (shouldShow)
              Positioned.fill(
                child: PopScope(
                  canPop: isOptional && !_updateCtrl.isDownloading,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && isOptional && !_updateCtrl.isDownloading) {
                      _updateCtrl.dismissOptionalUpdate();
                    }
                  },
                  child: _AppUpdateOverlay(
                    controller: _updateCtrl,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppUpdateOverlay extends StatelessWidget {
  final AppUpdateController controller;

  const _AppUpdateOverlay({
    required this.controller,
  });

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)} MB';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final status = controller.status;
    final config = controller.serverConfig;
    final isOptional = status == AppUpdateStatus.optionalUpdate;
    final isMaintenance = status == AppUpdateStatus.maintenance;
    final isDownloading = controller.isDownloading;
    final isDownloadComplete = controller.isDownloadComplete;

    final accentColor = isMaintenance
        ? const Color(0xFFF59E0B) // Amber
        : (status == AppUpdateStatus.forceUpdate
            ? AppColors.primary
            : const Color(0xFF06B6D4)); // Cyan

    final fileSizeText = _formatFileSize(config?.apkSize);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Frosted Backdrop Blur
          Positioned.fill(
            child: GestureDetector(
              onTap: (isOptional && !isDownloading) ? controller.dismissOptionalUpdate : null,
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.78 : 0.65),
                ),
              ),
            ),
          ),

          // Modal Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      color: isDark ? const Color(0xFF0E131F) : const Color(0xFF1E293B),
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glow Header Icon
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.28),
                                  accentColor.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isMaintenance
                                  ? Icons.engineering_rounded
                                  : (isDownloadComplete
                                      ? Icons.check_circle_outline_rounded
                                      : (isDownloading
                                          ? Icons.downloading_rounded
                                          : (isOptional
                                              ? Icons.new_releases_rounded
                                              : Icons.system_update_rounded))),
                              color: isDownloadComplete ? AppColors.primary : accentColor,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Header Tag / Category
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              isMaintenance
                                  ? 'PEMELIHARAAN SISTEM'
                                  : (isDownloadComplete
                                      ? 'SIAP DIPASANG'
                                      : (isDownloading
                                          ? 'MENGUNDUH PEMBARUAN'
                                          : (isOptional
                                              ? 'PEMBARUAN TERSEDIA'
                                              : 'PEMBARUAN WAJIB'))),
                              style: TextStyle(
                                color: isDownloadComplete ? AppColors.primary : accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            isMaintenance
                                ? 'Sistem Sedang Ditingkatkan'
                                : (isDownloadComplete
                                    ? 'Berkas Siap Dipasang'
                                    : (isDownloading
                                        ? 'Mengunduh Pembaruan OTA'
                                        : (isOptional
                                            ? 'Versi Baru Tersedia'
                                            : 'Aplikasi Perlu Diperbarui'))),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Message / Explanation
                          Text(
                            isMaintenance
                                ? (config?.maintenanceMessage?.isNotEmpty == true
                                    ? config!.maintenanceMessage!
                                    : 'Sistem LAJU sedang dalam pemeliharaan berkala demi stabilitas dan keamanan. Silakan coba kembali beberapa saat lagi.')
                                : (isDownloadComplete
                                    ? 'Pembaruan LAJU telah berhasil diunduh secara langsung. Ketuk tombol di bawah untuk memasang ke perangkat Anda.'
                                    : (isDownloading
                                        ? 'Sedang mengunduh berkas APK langsung dari server. Jangan tutup aplikasi hingga unduhan selesai.'
                                        : (isOptional
                                            ? 'Versi terbaru LAJU hadir dengan peningkatan performa, perbaikan keamanan, dan fitur komunikasi terkini.'
                                            : 'Versi aplikasi Anda sudah tidak didukung oleh server. Harap perbarui sekarang untuk melanjutkan penggunaan LAJU.'))),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Version & Size Info Card (For Updates)
                          if (!isMaintenance && !isDownloading) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Current Version
                                  Column(
                                    children: [
                                      Text(
                                        'Versi Anda',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'v${controller.currentVersion}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Directional Arrow
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: accentColor.withValues(alpha: 0.8),
                                    size: 18,
                                  ),

                                  // Latest Version
                                  Column(
                                    children: [
                                      Text(
                                        'Versi Terbaru',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'v${config?.latestAndroidVersion ?? "-"}',
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // APK Size
                                  if (fileSizeText.isNotEmpty) ...[
                                    Container(
                                      width: 1,
                                      height: 26,
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          'Ukuran APK',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          fileSizeText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Release Notes (if present)
                            if (config?.releaseNotes != null &&
                                config!.releaseNotes!.trim().isNotEmpty &&
                                !isDownloadComplete) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxHeight: 110),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.format_list_bulleted_rounded,
                                            size: 14,
                                            color: accentColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Catatan Pembaruan:',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        config.releaseNotes!.trim(),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],

                          // Progress Bar Card (During in-app OTA download)
                          if (isDownloading) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Mengunduh APK...',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${(controller.downloadProgress * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: controller.downloadProgress > 0
                                          ? controller.downloadProgress
                                          : null,
                                      minHeight: 8,
                                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatFileSize(controller.downloadedBytes),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        _formatFileSize(controller.totalBytes),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Error Display (if download fails)
                          if (controller.downloadError != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      controller.downloadError!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Action Buttons
                          if (isMaintenance) ...[
                            LajuButton(
                              label: 'Periksa Status Server',
                              icon: Icons.refresh_rounded,
                              variant: LajuButtonVariant.primary,
                              isLoading: controller.isChecking,
                              onPressed: () => controller.checkForUpdates(),
                            ),
                          ] else if (isDownloadComplete) ...[
                            // Ready to install
                            LajuButton(
                              label: 'Pasang Sekarang',
                              icon: Icons.install_mobile_rounded,
                              variant: LajuButtonVariant.primary,
                              onPressed: () => controller.installDownloadedApk(),
                            ),
                          ] else if (isDownloading) ...[
                            // Downloading indicator
                            LajuButton(
                              label: 'Mengunduh (${(controller.downloadProgress * 100).toStringAsFixed(0)}%)...',
                              variant: LajuButtonVariant.secondary,
                              isLoading: true,
                              onPressed: null,
                            ),
                          ] else if (isOptional) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: LajuButton(
                                    label: 'Nanti Saja',
                                    variant: LajuButtonVariant.secondary,
                                    onPressed: () => controller.dismissOptionalUpdate(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LajuButton(
                                    label: 'Perbarui',
                                    icon: Icons.system_update_rounded,
                                    variant: LajuButtonVariant.primary,
                                    onPressed: () => controller.startInAppOtaUpdate(),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Force Update
                            LajuButton(
                              label: 'Perbarui Sekarang',
                              icon: Icons.system_update_rounded,
                              variant: LajuButtonVariant.primary,
                              onPressed: () => controller.startInAppOtaUpdate(),
                            ),
                            const SizedBox(height: 12),
                            // Optional fallback to browser
                            GestureDetector(
                              onTap: () => controller.openExternalBrowserDownload(),
                              child: Text(
                                'Atau unduh manual melalui peramban web',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11.5,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
