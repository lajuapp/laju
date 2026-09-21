import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricAvailability {
  final bool isAvailable;
  final String status;
  final bool hasFingerprint;
  final bool hasFace;
  final bool hasIris;
  final List<String> biometricTypes;
  final String deviceModel;
  final String biometricLabel;

  const BiometricAvailability({
    required this.isAvailable,
    required this.status,
    this.hasFingerprint = false,
    this.hasFace = false,
    this.hasIris = false,
    this.biometricTypes = const [],
    this.deviceModel = '',
    this.biometricLabel = 'Biometrik / Kunci Layar',
  });
}

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static const MethodChannel _channel = MethodChannel('com.laju/biometric');

  /// Check if hardware biometrics or device credentials are functional on this device
  Future<BiometricAvailability> checkAvailability() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('canAuthenticate');
      if (result != null) {
        final types = (result['biometricTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        return BiometricAvailability(
          isAvailable: result['canAuthenticate'] == true,
          status: result['status']?.toString() ?? 'UNKNOWN',
          hasFingerprint: result['hasFingerprint'] == true,
          hasFace: result['hasFace'] == true,
          hasIris: result['hasIris'] == true,
          biometricTypes: types,
          deviceModel: result['deviceModel']?.toString() ?? '',
          biometricLabel: result['biometricLabel']?.toString() ?? 'Biometrik',
        );
      }
      return const BiometricAvailability(isAvailable: false, status: 'UNAVAILABLE');
    } catch (e) {
      debugPrint('[BiometricService] checkAvailability error: $e');
      return const BiometricAvailability(isAvailable: false, status: 'ERROR');
    }
  }

  /// Simple check whether biometric or screen lock is available
  Future<bool> canAuthenticate() async {
    final availability = await checkAvailability();
    return availability.isAvailable;
  }

  /// Triggers the native Android BiometricPrompt with fingerprint/face sensor
  Future<bool> authenticate({
    String title = 'Autentikasi Biometrik',
    String? subtitle,
    String? description,
    bool allowDeviceCredential = true,
    String negativeButtonText = 'Batal',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('authenticate', {
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (description != null) 'description': description,
        'allowDeviceCredential': allowDeviceCredential,
        'negativeButtonText': negativeButtonText,
      });

      if (result != null && result['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }
}
