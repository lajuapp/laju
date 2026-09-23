import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../services/device_media_service.dart';

enum AppPermissionType {
  camera,
  storage,
  microphone,
  notification,
  contacts,
  location,
}

class AppPermissionService {
  AppPermissionService._();
  static final AppPermissionService instance = AppPermissionService._();

  final Map<AppPermissionType, bool> _granted = {
    AppPermissionType.camera: false,
    AppPermissionType.storage: false,
    AppPermissionType.microphone: false,
    AppPermissionType.notification: false,
    AppPermissionType.contacts: false,
    AppPermissionType.location: false,
  };

  bool isGranted(AppPermissionType type) => _granted[type] ?? false;

  void setGranted(AppPermissionType type, bool granted) {
    _granted[type] = granted;
  }

  static Future<bool> requestPermission(
    BuildContext context, {
    required AppPermissionType type,
  }) async {
    if (type == AppPermissionType.camera) {
      final hasNative = await DeviceMediaService.hasCameraPermission();
      if (hasNative && instance.isGranted(type)) {
        return true;
      }
    } else if (type == AppPermissionType.location) {
      final hasNative = await LocationService.instance.hasPermission();
      if (hasNative && instance.isGranted(type)) {
        return true;
      }
    } else if (instance.isGranted(type)) {
      return true;
    }

    String title;
    String desc;
    IconData icon;
    Color color;

    switch (type) {
      case AppPermissionType.camera:
        title = context.tr('cameraPermissionTitle');
        desc = context.tr('cameraPermissionDesc');
        icon = Icons.camera_alt_rounded;
        color = const Color(0xFFEC4899);
        break;
      case AppPermissionType.storage:
        title = context.tr('storagePermissionTitle');
        desc = context.tr('storagePermissionDesc');
        icon = Icons.folder_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case AppPermissionType.microphone:
        title = 'Akses Mikrofon';
        desc = 'Mikrofon diperlukan untuk panggilan suara, video terenkripsi, dan perekaman audio.';
        icon = Icons.mic_rounded;
        color = AppColors.primary;
        break;
      case AppPermissionType.notification:
        title = 'Izin Notifikasi';
        desc = 'Notifikasi diperlukan untuk memberitahukan panggilan masuk, panggilan latar belakang, dan pesan.';
        icon = Icons.notifications_active_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case AppPermissionType.contacts:
        title = 'Akses Kontak Perangkat';
        desc = 'Izin kontak diperlukan untuk memilih dan membagikan kontak dari buku telepon Anda.';
        icon = Icons.contacts_rounded;
        color = const Color(0xFF0284C7);
        break;
      case AppPermissionType.location:
        title = 'Akses Lokasi Perangkat';
        desc = 'Izin lokasi diperlukan untuk membagikan lokasi Anda (OpenStreetMap) kepada kontak secara aman.';
        icon = Icons.location_on_rounded;
        color = const Color(0xFF10B981);
        break;
    }

    final isDark = ThemeModeController.instance.isDarkMode(context);

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: isDark ? Colors.white24 : AppColors.surfaceBorder),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        ctx.tr('cancel'),
                        style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (type == AppPermissionType.camera) {
                          final nativeGranted = await DeviceMediaService.requestCameraPermission();
                          if (nativeGranted) {
                            instance.setGranted(type, true);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            instance.setGranted(type, false);
                            if (ctx.mounted) {
                              LajuToast.error(ctx, 'Izin kamera belum disetujui');
                              Navigator.pop(ctx, false);
                            }
                          }
                        } else if (type == AppPermissionType.location) {
                          final nativeGranted = await LocationService.instance.requestPermission();
                          if (nativeGranted) {
                            instance.setGranted(type, true);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            instance.setGranted(type, false);
                            if (ctx.mounted) {
                              LajuToast.error(ctx, 'Izin lokasi belum disetujui');
                              Navigator.pop(ctx, false);
                            }
                          }
                        } else {
                          instance.setGranted(type, true);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        }
                      },
                      child: Text(
                        ctx.tr('grantPermission'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      },
    );

    return result ?? false;
  }
}
