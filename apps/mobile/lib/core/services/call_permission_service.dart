import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

enum CallPermissionResult {
  allGranted,
  audioOnlyGranted,
  denied,
}

class CallPermissionService {
  CallPermissionService._();
  static final CallPermissionService instance = CallPermissionService._();

  static const MethodChannel _cameraChannel = MethodChannel('com.laju/camera');
  static const MethodChannel _audioChannel = MethodChannel('com.laju/call_audio');

  Future<bool> hasRecordPermission() async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('hasRecordPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestRecordPermission() async {
    try {
      final res = await _audioChannel.invokeMethod<bool>('requestRecordPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasCameraPermission() async {
    try {
      final res = await _cameraChannel.invokeMethod<bool>('hasCameraPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final res = await _cameraChannel.invokeMethod<bool>('requestCameraPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _cameraChannel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// Checks and requests necessary permissions for voice or video call.
  /// If [isVideo] is true, checks both microphone and camera.
  /// If camera is denied but mic is granted, user can gracefully fallback to audio only.
  Future<CallPermissionResult> checkAndRequestPermissions({
    required bool isVideo,
    BuildContext? context,
  }) async {
    // 1. Microphone permission (required for all calls)
    var micGranted = await hasRecordPermission();
    if (!micGranted) {
      micGranted = await requestRecordPermission();
    }

    if (!micGranted) {
      if (context != null && context.mounted) {
        await _showPermissionDeniedDialog(
          context: context,
          title: 'Izin Mikrofon Diperlukan',
          message:
              'Laju membutuhkan akses mikrofon agar Anda dapat berkomunikasi dalam panggilan suara atau video.',
          canOpenSettings: true,
        );
      }
      return CallPermissionResult.denied;
    }

    // If audio call, mic is all we need
    if (!isVideo) {
      return CallPermissionResult.allGranted;
    }

    // 2. Camera permission (for video calls)
    var camGranted = await hasCameraPermission();
    if (!camGranted) {
      camGranted = await requestCameraPermission();
    }

    if (camGranted) {
      return CallPermissionResult.allGranted;
    }

    // Camera denied, but mic granted: offer audio-only fallback or settings
    if (context != null && context.mounted) {
      final proceedAudio = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = ThemeModeController.instance.isDarkMode(ctx);
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.videocam_off_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Izin Kamera Belum Aktif',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Text(
              'Laju tidak dapat mengakses kamera Anda. Ingin melanjutkan panggilan sebagai Panggilan Suara (Audio Saja)?',
              style: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  openAppSettings();
                },
                child: Text(
                  'Buka Pengaturan',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lanjut Suara Saja', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      );

      if (proceedAudio == true) {
        return CallPermissionResult.audioOnlyGranted;
      }
      return CallPermissionResult.denied;
    }

    // If no context, fallback gracefully to audio
    return CallPermissionResult.audioOnlyGranted;
  }

  Future<void> _showPermissionDeniedDialog({
    required BuildContext context,
    required String title,
    required String message,
    bool canOpenSettings = true,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = ThemeModeController.instance.isDarkMode(ctx);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.security_rounded, color: AppColors.danger, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Batal',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (canOpenSettings)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Buka Pengaturan', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        );
      },
    );
  }
}
