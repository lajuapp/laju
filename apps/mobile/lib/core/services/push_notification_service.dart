import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../../features/auth/domain/auth_controller.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const MethodChannel _systemNotifChannel = MethodChannel('com.laju/system_notifications');

  static const String _kPushToken = 'laju_push_token';
  static const String _kPushEndpoint = 'laju_push_endpoint'; // 'gotify' or 'fcm'
  static const String _kGotifyServerUrl = 'laju_gotify_server_url';
  static const String _kGotifyAppToken = 'laju_gotify_app_token';
  static const String _kPushEnabled = 'laju_push_enabled';

  String _pushToken = '';
  String _pushEndpoint = 'gotify';
  String _gotifyServerUrl = '';
  String _gotifyAppToken = '';
  bool _isPushEnabled = true;

  String get pushToken => _pushToken;
  String get pushEndpoint => _pushEndpoint;
  String get gotifyServerUrl => _gotifyServerUrl.isNotEmpty ? _gotifyServerUrl : EnvConfig.instance.apiBaseUrl;
  String get gotifyAppToken => _gotifyAppToken;
  bool get isPushEnabled => _isPushEnabled;

  static Future<void> showMessageNotification({
    required String conversationId,
    required String title,
    required String message,
  }) async {
    try {
      await _systemNotifChannel.invokeMethod('showMessageNotification', {
        'conversationId': conversationId,
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pushToken = prefs.getString(_kPushToken) ?? '';
      _pushEndpoint = prefs.getString(_kPushEndpoint) ?? 'gotify';
      _gotifyServerUrl = prefs.getString(_kGotifyServerUrl) ?? EnvConfig.instance.apiBaseUrl;
      _gotifyAppToken = prefs.getString(_kGotifyAppToken) ?? '';
      _isPushEnabled = prefs.getBool(_kPushEnabled) ?? true;

      if (_pushToken.isEmpty) {
        final deviceUuid = await AuthController.instance.getOrCreateLocalDeviceUuid();
        _pushToken = 'gotify_device_${deviceUuid.replaceAll('-', '').substring(0, 12)}';
        await prefs.setString(_kPushToken, _pushToken);
      }

      // Sync with backend if authenticated
      if (ApiClient.instance.authToken != null) {
        await syncPushTokenToBackend();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] init error: $e');
    }
  }

  Future<bool> syncPushTokenToBackend() async {
    try {
      final deviceUuid = await AuthController.instance.getOrCreateLocalDeviceUuid();
      final tokenToRegister = _gotifyAppToken.isNotEmpty ? _gotifyAppToken : _pushToken;

      // Start Android native background push service
      final authToken = ApiClient.instance.authToken;
      if (authToken != null) {
        _systemNotifChannel.invokeMethod('startBackgroundService', {
          'baseUrl': EnvConfig.instance.apiBaseUrl,
          'token': authToken,
        }).catchError((_) {});
      }

      final resp = await ApiClient.instance.post(
        ApiEndpoints.devicePushToken,
        body: {
          'deviceUuid': deviceUuid,
          'pushToken': tokenToRegister,
          'endpoint': _pushEndpoint,
        },
      );

      return resp.isSuccess;
    } catch (e) {
      debugPrint('[PushNotificationService] syncPushTokenToBackend error: $e');
      return false;
    }
  }

  Future<void> stopBackgroundService() async {
    try {
      await _systemNotifChannel.invokeMethod('stopBackgroundService');
    } catch (_) {}
  }

  Future<void> updatePushSettings({
    bool? enabled,
    String? token,
    String? serverUrl,
    String? appToken,
    String? endpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled != null) {
      _isPushEnabled = enabled;
      await prefs.setBool(_kPushEnabled, enabled);
    }
    if (token != null) {
      _pushToken = token;
      await prefs.setString(_kPushToken, token);
    }
    if (serverUrl != null) {
      _gotifyServerUrl = serverUrl;
      await prefs.setString(_kGotifyServerUrl, serverUrl);
    }
    if (appToken != null) {
      _gotifyAppToken = appToken;
      await prefs.setString(_kGotifyAppToken, appToken);
    }
    if (endpoint != null) {
      _pushEndpoint = endpoint;
      await prefs.setString(_kPushEndpoint, endpoint);
    }

    await syncPushTokenToBackend();
  }

  Future<Map<String, dynamic>> testPushNotification() async {
    try {
      if (ApiClient.instance.authToken == null) {
        return {'success': false, 'message': 'Belum login ke server.'};
      }

      // Make sure current token is synced first
      await syncPushTokenToBackend();

      final resp = await ApiClient.instance.post(ApiEndpoints.deviceTestPush);
      if (resp.isSuccess && resp.rawJson is Map) {
        return Map<String, dynamic>.from(resp.rawJson);
      }
      return {
        'success': false,
        'message': resp.errorMessage ?? 'Gagal menghubungi server notifikasi.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _systemNotifChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _systemNotifChannel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
