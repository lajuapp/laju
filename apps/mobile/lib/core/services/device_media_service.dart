import 'dart:io';
import 'package:flutter/services.dart';
import '../security/app_lock_controller.dart';

class DeviceDocumentResult {
  final String path;
  final String name;
  final int sizeBytes;

  const DeviceDocumentResult({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DeviceContactResult {
  final String name;
  final String phoneNumber;

  const DeviceContactResult({
    required this.name,
    required this.phoneNumber,
  });
}

class DeviceMediaService {
  static const MethodChannel _channel = MethodChannel('com.laju/camera');

  /// Opens the phone's native Gallery / Photo Picker to choose a photo.
  /// Returns the absolute file path of the chosen photo, or null if cancelled.
  static Future<String?> openGallery() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final String? path = await _channel.invokeMethod<String>('openGallery');
      if (path != null && File(path).existsSync()) {
        return path;
      }
      return path;
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Opens the device camera to record a video (enforcing max 60 seconds limit).
  /// Returns a map with 'path', 'durationMs', 'fileSize', 'thumbnailPath',
  /// or 'error' == 'DURATION_EXCEEDED' if video exceeds 60s.
  static Future<Map<String, dynamic>?> openVideoCamera() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final res = await _channel.invokeMapMethod<String, dynamic>('openVideoCamera');
      return res;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Opens the device gallery to pick a video file (enforcing max 60 seconds limit).
  /// Returns a map with 'path', 'durationMs', 'fileSize', 'thumbnailPath',
  /// or 'error' == 'DURATION_EXCEEDED' if video exceeds 60s.
  static Future<Map<String, dynamic>?> openVideoGallery() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final res = await _channel.invokeMapMethod<String, dynamic>('openVideoGallery');
      return res;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Copies an image file into the application's permanent internal storage directory.
  /// This ensures profile pictures survive app restart and cache cleanups.
  static Future<String> savePermanentAvatar(String sourcePath) async {
    try {
      final String? permanentPath = await _channel.invokeMethod<String>(
        'savePermanentAvatar',
        {'path': sourcePath},
      );
      if (permanentPath != null && permanentPath.isNotEmpty && File(permanentPath).existsSync()) {
        return permanentPath;
      }
    } catch (_) {}
    return sourcePath;
  }

  /// Compresses and downsamples an image file to standard messaging resolution.
  static Future<String> compressImage(String path, {int maxDimension = 1280, int quality = 82}) async {
    try {
      final String? compressed = await _channel.invokeMethod<String>(
        'compressImage',
        {
          'path': path,
          'maxDimension': maxDimension,
          'quality': quality,
        },
      );
      if (compressed != null && File(compressed).existsSync()) {
        return compressed;
      }
    } catch (_) {}
    return path;
  }

  /// Checks whether native camera hardware permission is granted.
  static Future<bool> hasCameraPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('hasCameraPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests native camera hardware permission from the OS.
  static Future<bool> requestCameraPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>('requestCameraPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the device's native Camera app to capture a photo in high resolution.
  /// Returns the absolute file path of the captured photo, or null if cancelled.
  static Future<String?> openCamera() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final String? path = await _channel.invokeMethod<String>('openSystemCamera');
      if (path != null && File(path).existsSync()) {
        return path;
      }
      return path;
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Opens device Storage Access Framework to pick any real file/document.
  static Future<DeviceDocumentResult?> openDocument() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final map = await _channel.invokeMapMethod<String, dynamic>('openDocument');
      if (map != null && map['path'] != null) {
        final path = map['path'].toString();
        final name = map['name']?.toString() ?? path.split('/').last;
        final size = (map['size'] as num?)?.toInt() ?? (File(path).existsSync() ? File(path).lengthSync() : 0);
        return DeviceDocumentResult(path: path, name: name, sizeBytes: size);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Opens device audio picker to choose any real audio file from storage.
  static Future<DeviceDocumentResult?> openAudio() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final map = await _channel.invokeMapMethod<String, dynamic>('openAudio');
      if (map != null && map['path'] != null) {
        final path = map['path'].toString();
        final name = map['name']?.toString() ?? path.split('/').last;
        final size = (map['size'] as num?)?.toInt() ?? (File(path).existsSync() ? File(path).lengthSync() : 0);
        return DeviceDocumentResult(path: path, name: name, sizeBytes: size);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Opens native phone contacts picker to choose real contact.
  static Future<DeviceContactResult?> openContact() async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final map = await _channel.invokeMapMethod<String, dynamic>('openContact');
      if (map != null && map['name'] != null) {
        return DeviceContactResult(
          name: map['name'].toString(),
          phoneNumber: map['phone']?.toString() ?? '',
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }

  /// Shares text and optionally an image file via native OS share sheet (WhatsApp, Telegram, etc.)
  static Future<bool> shareContent({
    required String text,
    String? filePath,
    String? title,
  }) async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      final bool? res = await _channel.invokeMethod<bool>('shareContent', {
        'text': text,
        'filePath': filePath,
        'title': title ?? 'Bagikan Kode QR LAJU',
      });
      return res ?? true;
    } on PlatformException catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }
}
