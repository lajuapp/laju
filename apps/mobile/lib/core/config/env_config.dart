import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class EnvConfig {
  EnvConfig._();
  static final EnvConfig instance = EnvConfig._();

  // Compile-time environment overrides via --dart-define
  static const String _defineBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _defineTimeout = String.fromEnvironment('API_TIMEOUT_MS');
  static const String _defineMockFallback = String.fromEnvironment('ENABLE_MOCK_FALLBACK');

  final Map<String, String> _env = {};
  String? _runtimeBaseUrlOverride;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Loads configuration from .env asset or falls back to compile-time defines / platform defaults
  Future<void> init() async {
    if (_initialized) return;

    try {
      final content = await rootBundle.loadString('.env');
      _parseEnv(content);
    } catch (_) {
      // .env file might not exist in test runner or minimal builds, which is completely fine
    }

    _initialized = true;
  }

  /// Parses KEY=VALUE format content
  void _parseEnv(String content) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final eqIdx = line.indexOf('=');
      if (eqIdx > 0) {
        final key = line.substring(0, eqIdx).trim();
        var val = line.substring(eqIdx + 1).trim();
        // Remove quotes if present
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        _env[key] = val;
      }
    }
  }

  /// Resolve API base URL with multi-layer priority:
  /// 1. Runtime override (set via QA / in-app settings)
  /// 2. Compile-time define (--dart-define=API_BASE_URL=...)
  /// 3. .env file asset (API_BASE_URL=...)
  /// 4. Platform smart default (10.0.2.2:3000 on Android emulator, localhost:3000 otherwise)
  String get apiBaseUrl {
    if (_runtimeBaseUrlOverride != null && _runtimeBaseUrlOverride!.isNotEmpty) {
      return _runtimeBaseUrlOverride!;
    }

    if (_defineBaseUrl.isNotEmpty) {
      return _defineBaseUrl;
    }

    if (_env.containsKey('API_BASE_URL') && _env['API_BASE_URL']!.isNotEmpty) {
      return _env['API_BASE_URL']!;
    }

    return defaultPlatformBaseUrl;
  }

  /// Default API URL pointing to the live server
  static String get defaultPlatformBaseUrl {
    return 'https://api-laju.rogatekno.my.id';
  }

  /// HTTP request timeout duration
  Duration get apiTimeout {
    if (_defineTimeout.isNotEmpty) {
      final ms = int.tryParse(_defineTimeout);
      if (ms != null) return Duration(milliseconds: ms);
    }
    if (_env.containsKey('API_TIMEOUT_MS')) {
      final ms = int.tryParse(_env['API_TIMEOUT_MS']!);
      if (ms != null) return Duration(milliseconds: ms);
    }
    return const Duration(seconds: 15);
  }

  /// Mock fallback is permanently disabled for production
  bool get enableMockFallback => false;

  /// WebSocket URL for real-time events
  String get websocketUrl {
    final base = apiBaseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    return base.replaceFirst('http://', 'ws://');
  }

  /// Dynamically switch base URL at runtime (useful for E2E tests, QA environments)
  void setApiBaseUrl(String url) {
    _runtimeBaseUrlOverride = url.trim();
  }

  /// Reset any runtime override
  void resetOverride() {
    _runtimeBaseUrlOverride = null;
  }
}
