import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/env_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

enum AppUpdateStatus {
  upToDate,
  optionalUpdate,
  forceUpdate,
  maintenance,
}

class AppSystemConfig {
  final String minAndroidVersion;
  final String latestAndroidVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? apkUrl;
  final String? apkFilename;
  final int? apkSize;
  final String? apkSha256;
  final String? releaseNotes;

  const AppSystemConfig({
    required this.minAndroidVersion,
    required this.latestAndroidVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.apkUrl,
    this.apkFilename,
    this.apkSize,
    this.apkSha256,
    this.releaseNotes,
  });

  factory AppSystemConfig.fromJson(Map<String, dynamic> json) {
    return AppSystemConfig(
      minAndroidVersion: json['minAndroidVersion'] as String? ?? '1.0.0',
      latestAndroidVersion: json['latestAndroidVersion'] as String? ?? '1.0.0',
      forceUpdate: json['forceUpdate'] == true,
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage'] as String?,
      apkUrl: json['apkUrl'] as String?,
      apkFilename: json['apkFilename'] as String?,
      apkSize: json['apkSize'] is int
          ? json['apkSize'] as int
          : (json['apkSize'] != null ? int.tryParse(json['apkSize'].toString()) : null),
      apkSha256: json['apkSha256'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }
}

typedef AppVersionController = AppUpdateController;

class AppUpdateController extends ChangeNotifier {
  AppUpdateController._();
  static final AppUpdateController instance = AppUpdateController._();

  static const MethodChannel _deviceChannel = MethodChannel('com.laju/device');

  String _currentVersion = '1.0.1';
  int _currentVersionCode = 2;
  AppSystemConfig? _serverConfig;
  AppUpdateStatus _status = AppUpdateStatus.upToDate;
  bool _isChecking = false;
  String? _dismissedOptionalVersion;

  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;
  AppSystemConfig? get serverConfig => _serverConfig;
  AppUpdateStatus get status => _status;
  bool get isChecking => _isChecking;
  bool get isOptionalDismissed => _dismissedOptionalVersion == _serverConfig?.latestAndroidVersion;

  bool get shouldShowGate {
    if (_status == AppUpdateStatus.maintenance) return true;
    if (_status == AppUpdateStatus.forceUpdate) return true;
    if (_status == AppUpdateStatus.optionalUpdate && !isOptionalDismissed) return true;
    return false;
  }

  /// Initialize controller: fetch native installed version and check backend config
  Future<void> init() async {
    await _loadInstalledVersion();
    await checkForUpdates();
  }

  /// Reads native package info (versionName, versionCode) from Android
  Future<void> _loadInstalledVersion() async {
    try {
      final res = await _deviceChannel.invokeMapMethod<String, dynamic>('getAppVersion');
      if (res != null) {
        final vName = res['versionName'] as String?;
        final vCode = res['versionCode'];
        if (vName != null && vName.isNotEmpty) {
          _currentVersion = vName;
        }
        if (vCode is int) {
          _currentVersionCode = vCode;
        } else if (vCode is num) {
          _currentVersionCode = vCode.toInt();
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateController] Could not read native app version: $e');
    }
  }

  /// Compare two semantic version strings (e.g. "1.0.0" vs "1.0.1")
  /// Returns:
  ///   -1 if v1 < v2
  ///    0 if v1 == v2
  ///    1 if v1 > v2
  static int compareSemver(String v1, String v2) {
    String clean(String v) =>
        v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[-+]'))[0];

    final parts1 = clean(v1).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean(v2).split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Queries /admin/app-config/public and evaluates update / maintenance status
  Future<void> checkForUpdates() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        ApiEndpoints.publicAppConfig,
        fromJson: (json) => json is Map<String, dynamic> ? json : <String, dynamic>{},
      );

      if (response.isSuccess && response.data != null) {
        final config = AppSystemConfig.fromJson(response.data!);
        _serverConfig = config;

        if (config.maintenanceMode) {
          _status = AppUpdateStatus.maintenance;
        } else {
          final cmpMin = compareSemver(_currentVersion, config.minAndroidVersion);
          final cmpLatest = compareSemver(_currentVersion, config.latestAndroidVersion);

          if (cmpMin < 0) {
            // Current version is strictly below minimum required version -> Force update
            _status = AppUpdateStatus.forceUpdate;
          } else if (cmpLatest < 0) {
            // Current version is below latest version
            if (config.forceUpdate) {
              _status = AppUpdateStatus.forceUpdate;
            } else {
              _status = AppUpdateStatus.optionalUpdate;
            }
          } else {
            _status = AppUpdateStatus.upToDate;
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateController] Error checking app updates: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Construct the complete direct APK download URL
  String resolveDownloadUrl() {
    final rawUrl = _serverConfig?.apkUrl;
    final path = (rawUrl != null && rawUrl.trim().isNotEmpty)
        ? rawUrl.trim()
        : ApiEndpoints.downloadApk;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final base = EnvConfig.instance.apiBaseUrl;
    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }

  /// Open external browser to trigger immediate APK download
  Future<bool> downloadAndInstallApk() async {
    try {
      final url = resolveDownloadUrl();
      debugPrint('[AppUpdateController] Launching download URL: $url');
      final result = await _deviceChannel.invokeMethod<bool>('openUrl', {'url': url});
      return result ?? false;
    } catch (e) {
      debugPrint('[AppUpdateController] Failed to open download URL: $e');
      return false;
    }
  }

  /// Dismiss optional update notification for the current session/version
  void dismissOptionalUpdate() {
    _dismissedOptionalVersion = _serverConfig?.latestAndroidVersion;
    notifyListeners();
  }
}
