import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
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
  final String minIosVersion;
  final String latestIosVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String? releaseNotes;

  const AppSystemConfig({
    required this.minAndroidVersion,
    required this.latestAndroidVersion,
    required this.minIosVersion,
    required this.latestIosVersion,
    required this.forceUpdate,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.playStoreUrl,
    this.appStoreUrl,
    this.releaseNotes,
  });

  factory AppSystemConfig.fromJson(Map<String, dynamic> json) {
    final minAndroid = json['minAndroidVersion'] as String? ?? '1.0.0';
    final latestAndroid = json['latestAndroidVersion'] as String? ?? '1.0.0';
    return AppSystemConfig(
      minAndroidVersion: minAndroid,
      latestAndroidVersion: latestAndroid,
      minIosVersion: json['minIosVersion'] as String? ?? minAndroid,
      latestIosVersion: json['latestIosVersion'] as String? ?? latestAndroid,
      forceUpdate: json['forceUpdate'] == true,
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage'] as String?,
      playStoreUrl: json['playStoreUrl'] as String?,
      appStoreUrl: json['appStoreUrl'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }
}

typedef AppVersionController = AppUpdateController;

class AppUpdateController extends ChangeNotifier {
  AppUpdateController._();
  static final AppUpdateController instance = AppUpdateController._();

  static const MethodChannel _deviceChannel = MethodChannel('com.laju/device');
  static const String defaultAndroidPackageName = 'com.laju.laju_mobile';

  String _currentVersion = AppConstants.appVersion;
  int _currentVersionCode = AppConstants.appBuildNumber;
  AppSystemConfig? _serverConfig;
  AppUpdateStatus _status = AppUpdateStatus.upToDate;
  bool _isChecking = false;
  String? _dismissedOptionalVersion;
  bool _isOpeningStore = false;
  String? _storeError;

  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;
  AppSystemConfig? get serverConfig => _serverConfig;
  AppUpdateStatus get status => _status;
  bool get isChecking => _isChecking;
  bool get isOpeningStore => _isOpeningStore;
  String? get storeError => _storeError;

  String get targetVersion {
    if (_serverConfig == null) return _currentVersion;
    if (kIsWeb) return _serverConfig!.latestAndroidVersion;
    if (Platform.isIOS) {
      return _serverConfig!.latestIosVersion;
    }
    return _serverConfig!.latestAndroidVersion;
  }

  String get minRequiredVersion {
    if (_serverConfig == null) return '1.0.0';
    if (kIsWeb) return _serverConfig!.minAndroidVersion;
    if (Platform.isIOS) {
      return _serverConfig!.minIosVersion;
    }
    return _serverConfig!.minAndroidVersion;
  }

  bool get isOptionalDismissed => _dismissedOptionalVersion == targetVersion;

  bool get shouldShowGate {
    if (_status == AppUpdateStatus.maintenance) return true;
    if (_status == AppUpdateStatus.forceUpdate) return true;
    if (_status == AppUpdateStatus.optionalUpdate && !isOptionalDismissed) return true;
    return false;
  }

  /// Initialize controller: fetch native installed version and trigger backend config check in background
  Future<void> init() async {
    await _loadInstalledVersion();
    // Non-blocking: check for updates asynchronously so app startup is instant
    checkForUpdates().catchError((e) {
      debugPrint('[AppUpdateController] Background check error: $e');
    });
  }

  /// Reads native package info (versionName, versionCode) from host OS
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
          final isIos = !kIsWeb && Platform.isIOS;
          final minVersion = isIos ? config.minIosVersion : config.minAndroidVersion;
          final latestVersion = isIos ? config.latestIosVersion : config.latestAndroidVersion;

          final cmpMin = compareSemver(_currentVersion, minVersion);
          final cmpLatest = compareSemver(_currentVersion, latestVersion);

          if (cmpMin < 0) {
            _status = AppUpdateStatus.forceUpdate;
          } else if (cmpLatest < 0) {
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

  /// Resolves the store URL based on operating system and optional backend configuration
  String resolveStoreUrl() {
    if (!kIsWeb && Platform.isIOS) {
      final configured = _serverConfig?.appStoreUrl?.trim();
      if (configured != null && configured.isNotEmpty) {
        return configured;
      }
      return 'https://apps.apple.com/app/laju/id6740000000';
    }

    // Android:
    final configured = _serverConfig?.playStoreUrl?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return 'market://details?id=$defaultAndroidPackageName';
  }

  /// Resolves standard HTTPS web link for browser fallback
  String resolveWebStoreUrl() {
    if (!kIsWeb && Platform.isIOS) {
      return resolveStoreUrl();
    }
    return 'https://play.google.com/store/apps/details?id=$defaultAndroidPackageName';
  }

  /// Redirect user to official app store
  Future<bool> openStore({bool forceWebFallback = false}) async {
    if (_isOpeningStore) return false;
    _isOpeningStore = true;
    _storeError = null;
    notifyListeners();

    try {
      final targetUrl = forceWebFallback ? resolveWebStoreUrl() : resolveStoreUrl();
      debugPrint('[AppUpdateController] Redirecting user to store: $targetUrl');

      final success = await _deviceChannel.invokeMethod<bool>('openUrl', {'url': targetUrl});

      if (success != true && !forceWebFallback && (!kIsWeb && Platform.isAndroid)) {
        // Fallback to web link if market:// failed
        final webUrl = resolveWebStoreUrl();
        final webSuccess = await _deviceChannel.invokeMethod<bool>('openUrl', {'url': webUrl});
        return webSuccess ?? false;
      }

      return success ?? false;
    } catch (e) {
      debugPrint('[AppUpdateController] Failed to redirect to store: $e');
      _storeError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isOpeningStore = false;
      notifyListeners();
    }
  }

  /// Dismiss optional update notification for the current session/version
  void dismissOptionalUpdate() {
    _dismissedOptionalVersion = targetVersion;
    notifyListeners();
  }
}
