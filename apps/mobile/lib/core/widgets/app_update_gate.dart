import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../localization/app_localization.dart';
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
      listenable: Listenable.merge([
        _updateCtrl,
        ThemeModeController.instance,
        LocaleController.instance,
      ]),
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

    // Theme adaptive colors
    final cardBg = isDark ? const Color(0xFF0E131F) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF475569);
    final subCardBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC);
    final subCardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1);
    final releaseNotesBg = isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9);
    final releaseNotesBorder = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0);
    final releaseNotesTextColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF334155);
    final progressTrackColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final manualLinkColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B);

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
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.78)
                      : const Color(0xFF0F172A).withValues(alpha: 0.5),
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
                      color: accentColor.withValues(alpha: isDark ? 0.35 : 0.28),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : const Color(0xFF0F172A).withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      color: cardBg,
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
                                  accentColor.withValues(alpha: isDark ? 0.28 : 0.2),
                                  accentColor.withValues(alpha: 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: isDark ? 0.4 : 0.35),
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
                              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withValues(alpha: isDark ? 0.3 : 0.25),
                              ),
                            ),
                            child: Text(
                              isMaintenance
                                  ? context.tr('updateTagMaintenance')
                                  : (isDownloadComplete
                                      ? context.tr('updateTagReady')
                                      : (isDownloading
                                          ? context.tr('updateTagDownloading')
                                          : (isOptional
                                              ? context.tr('updateTagAvailable')
                                              : context.tr('updateTagRequired')))),
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
                                ? context.tr('updateTitleMaintenance')
                                : (isDownloadComplete
                                    ? context.tr('updateTitleReady')
                                    : (isDownloading
                                        ? context.tr('updateTitleDownloading')
                                        : (isOptional
                                            ? context.tr('updateTitleAvailable')
                                            : context.tr('updateTitleRequired')))),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: titleColor,
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
                                    : context.tr('updateDescMaintenanceDefault'))
                                : (isDownloadComplete
                                    ? context.tr('updateDescReady')
                                    : (isDownloading
                                        ? context.tr('updateDescDownloading')
                                        : (isOptional
                                            ? context.tr('updateDescAvailable')
                                            : context.tr('updateDescRequired')))),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: bodyColor,
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
                                color: subCardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: subCardBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Current Version
                                  Column(
                                    children: [
                                      Text(
                                        context.tr('updateYourVersion'),
                                        style: TextStyle(
                                          color: labelColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'v${controller.currentVersion}',
                                        style: TextStyle(
                                          color: valueColor,
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
                                        context.tr('updateLatestVersion'),
                                        style: TextStyle(
                                          color: labelColor,
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
                                      color: dividerColor,
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          context.tr('updateApkSize'),
                                          style: TextStyle(
                                            color: labelColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          fileSizeText,
                                          style: TextStyle(
                                            color: valueColor,
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
                                  color: releaseNotesBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: releaseNotesBorder,
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
                                            context.tr('updateReleaseNotes'),
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
                                          color: releaseNotesTextColor,
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
                                color: subCardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        context.tr('updateDownloadingApk'),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.7)
                                              : const Color(0xFF334155),
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
                                      backgroundColor: progressTrackColor,
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
                                          color: labelColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        _formatFileSize(controller.totalBytes),
                                        style: TextStyle(
                                          color: labelColor,
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
                                color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      controller.downloadError!,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFFB91C1C),
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
                              label: context.tr('updateCheckServerStatus'),
                              icon: Icons.refresh_rounded,
                              variant: LajuButtonVariant.primary,
                              isLoading: controller.isChecking,
                              onPressed: () => controller.checkForUpdates(),
                            ),
                          ] else if (isDownloadComplete) ...[
                            // Ready to install
                            LajuButton(
                              label: context.tr('updateInstallNow'),
                              icon: Icons.install_mobile_rounded,
                              variant: LajuButtonVariant.primary,
                              onPressed: () => controller.installDownloadedApk(),
                            ),
                          ] else if (isDownloading) ...[
                            // Downloading indicator
                            LajuButton(
                              label: '${context.tr('updateDownloadingBtn')} (${(controller.downloadProgress * 100).toStringAsFixed(0)}%)...',
                              variant: LajuButtonVariant.secondary,
                              isLoading: true,
                              onPressed: null,
                            ),
                          ] else if (isOptional) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: LajuButton(
                                    label: context.tr('updateLater'),
                                    variant: LajuButtonVariant.secondary,
                                    onPressed: () => controller.dismissOptionalUpdate(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: LajuButton(
                                    label: context.tr('updateBtn'),
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
                              label: context.tr('updateNowBtn'),
                              icon: Icons.system_update_rounded,
                              variant: LajuButtonVariant.primary,
                              onPressed: () => controller.startInAppOtaUpdate(),
                            ),
                            const SizedBox(height: 12),
                            // Optional fallback to browser
                            GestureDetector(
                              onTap: () => controller.openExternalBrowserDownload(),
                              child: Text(
                                context.tr('updateDownloadManualWeb'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: manualLinkColor,
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
