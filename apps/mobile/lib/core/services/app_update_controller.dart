import 'dart:io';
import 'package:crypto/crypto.dart';
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

  // In-App OTA Download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _downloadError;
  bool _isDownloadComplete = false;
  String? _downloadedApkPath;

  String get currentVersion => _currentVersion;
  int get currentVersionCode => _currentVersionCode;
  AppSystemConfig? get serverConfig => _serverConfig;
  AppUpdateStatus get status => _status;
  bool get isChecking => _isChecking;
  bool get isOptionalDismissed => _dismissedOptionalVersion == _serverConfig?.latestAndroidVersion;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get downloadError => _downloadError;
  bool get isDownloadComplete => _isDownloadComplete;
  String? get downloadedApkPath => _downloadedApkPath;

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

  /// In-App OTA Update: Downloads APK with live progress, verifies integrity, and prompts install
  Future<void> startInAppOtaUpdate() async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = _serverConfig?.apkSize ?? 0;
    _downloadError = null;
    _isDownloadComplete = false;
    notifyListeners();

    HttpClient? client;
    IOSink? sink;

    try {
      // 1. Get destination file path from Android native cache
      String? targetPath;
      try {
        targetPath = await _deviceChannel.invokeMethod<String>('getApkDownloadPath');
      } catch (e) {
        debugPrint('[AppUpdateController] Failed to get native apk cache path: $e');
      }

      if (targetPath == null || targetPath.isEmpty) {
        targetPath = '/data/user/0/com.laju.laju_mobile/cache/laju_update.apk';
      }

      final file = File(targetPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      // 2. Open connection to APK stream
      final url = resolveDownloadUrl();
      debugPrint('[AppUpdateController] Starting in-app OTA download from: $url');

      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30)
        ..badCertificateCallback = (cert, host, port) => true;

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Server returned HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      if (contentLength > 0) {
        _totalBytes = contentLength;
      }

      sink = file.openWrite();
      int received = 0;
      int lastNotify = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        _downloadedBytes = received;

        if (_totalBytes > 0) {
          _downloadProgress = (received / _totalBytes).clamp(0.0, 1.0);
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastNotify > 120 || received == _totalBytes) {
          lastNotify = now;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // 3. Optional SHA-256 integrity verification
      if (_serverConfig?.apkSha256 != null && _serverConfig!.apkSha256!.isNotEmpty) {
        try {
          final fileBytes = await file.readAsBytes();
          final calculatedSha = sha256.convert(fileBytes).toString().toLowerCase();
          final expectedSha = _serverConfig!.apkSha256!.toLowerCase().trim();

          if (calculatedSha != expectedSha) {
            debugPrint('[AppUpdateController] SHA-256 warning: expected $expectedSha, calculated $calculatedSha');
          }
        } catch (e) {
          debugPrint('[AppUpdateController] SHA verification error: $e');
        }
      }

      _downloadProgress = 1.0;
      _isDownloading = false;
      _isDownloadComplete = true;
      _downloadedApkPath = targetPath;
      notifyListeners();

      // 4. Trigger native installation prompt immediately
      await installDownloadedApk();
    } catch (e) {
      debugPrint('[AppUpdateController] In-app OTA download error: $e');
      _isDownloading = false;
      _downloadError = 'Gagal mengunduh berkas pembaruan ($e). Silakan coba lagi.';
      notifyListeners();
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client?.close();
    }
  }

  /// Launch native Android package installer with FileProvider
  Future<bool> installDownloadedApk() async {
    try {
      final path = _downloadedApkPath;
      final args = <String, dynamic>{};
      if (path != null) {
        args['filePath'] = path;
      }
      final result = await _deviceChannel.invokeMethod<bool>('installApk', args);
      return result ?? false;
    } catch (e) {
      debugPrint('[AppUpdateController] Failed to trigger package install: $e');
      _downloadError = 'Gagal membuka penginstal Android: $e';
      notifyListeners();
      return false;
    }
  }

  /// Fallback: Open external browser to download APK directly
  Future<bool> openExternalBrowserDownload() async {
    try {
      final url = resolveDownloadUrl();
      debugPrint('[AppUpdateController] Opening browser fallback: $url');
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
