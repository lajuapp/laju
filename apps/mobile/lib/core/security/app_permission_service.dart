import 'package:flutter/material.dart';
import '../services/device_media_service.dart';
import '../services/location_service.dart';
import '../services/voice_note_service.dart';

enum AppPermissionType {
  camera,
  storage,
  microphone,
  notification,
  contacts,
  location,
}

/// Service to handle app permissions using purely native Android / iOS system popups.
/// Eliminates custom modal sheets and delegates directly to operating system permission handlers.
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

  /// Directly requests native Android / iOS system permission popups without any custom UI dialogs.
  static Future<bool> requestPermission(
    BuildContext context, {
    required AppPermissionType type,
  }) async {
    switch (type) {
      case AppPermissionType.camera:
        final hasNative = await DeviceMediaService.hasCameraPermission();
        if (hasNative) {
          instance.setGranted(type, true);
          return true;
        }
        final nativeGranted = await DeviceMediaService.requestCameraPermission();
        instance.setGranted(type, nativeGranted);
        return nativeGranted;

      case AppPermissionType.microphone:
        final hasNative = await VoiceNoteService.instance.hasPermission();
        if (hasNative) {
          instance.setGranted(type, true);
          return true;
        }
        final nativeGranted = await VoiceNoteService.instance.requestPermission();
        instance.setGranted(type, nativeGranted);
        return nativeGranted;

      case AppPermissionType.location:
        final hasNative = await LocationService.instance.hasPermission();
        if (hasNative) {
          instance.setGranted(type, true);
          return true;
        }
        final nativeGranted = await LocationService.instance.requestPermission();
        instance.setGranted(type, nativeGranted);
        return nativeGranted;

      case AppPermissionType.storage:
        final hasNative = await DeviceMediaService.hasStoragePermission();
        if (hasNative) {
          instance.setGranted(type, true);
          return true;
        }
        final nativeGranted = await DeviceMediaService.requestStoragePermission();
        instance.setGranted(type, nativeGranted);
        return nativeGranted;

      case AppPermissionType.contacts:
      case AppPermissionType.notification:
        // Contacts and Notifications are handled natively via system intents (System Contact Picker / system push)
        instance.setGranted(type, true);
        return true;
    }
  }
}
