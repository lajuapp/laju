import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../network/api_client.dart';
import '../network/media_url_resolver.dart';

/// High-Performance Media Cache Manager for LAJU Mobile.
///
/// Provides:
/// - Persistent local disk caching for images, stickers, wallpapers, avatars, and media previews.
/// - In-flight download request deduplication (prevents redundant concurrent HTTP requests).
/// - Atomic file writing (.tmp -> rename) to guard against partial/corrupt downloads.
/// - Fire-and-forget preloading for next story items and upcoming media.
class LajuMediaCacheManager {
  LajuMediaCacheManager._();
  static final LajuMediaCacheManager instance = LajuMediaCacheManager._();

  Directory? _cacheDir;
  final Map<String, Future<File?>> _inFlightDownloads = {};
  final Set<String> _cachedFileKeys = {};
  bool _isInitialized = false;

  /// Initializes the cache directory and populates the in-memory cache index
  Future<void> init() async {
    await getCacheDirectory();
  }

  Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null && _cacheDir!.existsSync()) {
      return _cacheDir!;
    }

    Directory targetDir;
    try {
      final dbPath = await getDatabasesPath();
      final appDir = Directory(dbPath).parent;
      targetDir = Directory(p.join(appDir.path, 'cache', 'media_cache'));
    } catch (_) {
      targetDir = Directory(p.join(Directory.systemTemp.path, 'laju_media_cache'));
    }

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    _cacheDir = targetDir;

    if (!_isInitialized) {
      _indexExistingFiles(targetDir);
      _isInitialized = true;
    }

    return targetDir;
  }

  void _indexExistingFiles(Directory dir) {
    try {
      final list = dir.listSync();
      for (final entity in list) {
        if (entity is File && !entity.path.endsWith('.tmp')) {
          final filename = p.basenameWithoutExtension(entity.path);
          _cachedFileKeys.add(filename);
        }
      }
    } catch (_) {}
  }

  /// Computes a deterministic MD5 cache key from a URL or media path
  String getCacheKey(String urlOrPath) {
    final clean = resolveMediaUrl(urlOrPath).trim();
    return md5.convert(utf8.encode(clean)).toString();
  }

  /// Extracts file extension or defaults to .img
  String _extractExtension(String urlOrPath) {
    final uri = Uri.tryParse(urlOrPath);
    final path = uri != null ? uri.path : urlOrPath;
    final ext = p.extension(path).toLowerCase();
    if (ext.isNotEmpty && ext.length <= 5 && !ext.contains('?')) {
      return ext;
    }
    return '.img';
  }

  /// Synchronous check whether a media file is already cached locally
  bool isFileCachedSync(String urlOrPath) {
    final key = getCacheKey(urlOrPath);
    return _cachedFileKeys.contains(key);
  }

  /// Synchronous retrieval of cached File if available
  File? getCachedFileIfPresentSync(String urlOrPath) {
    if (_cacheDir == null) return null;
    final key = getCacheKey(urlOrPath);
    if (!_cachedFileKeys.contains(key)) return null;
    final ext = _extractExtension(urlOrPath);
    final file = File(p.join(_cacheDir!.path, '$key$ext'));
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    return null;
  }

  /// Directly associates an existing local file with a URL cache key, copying it into cache
  Future<File?> putFile(String urlOrPath, File sourceFile) async {
    try {
      if (!sourceFile.existsSync() || sourceFile.lengthSync() == 0) return null;
      final clean = resolveMediaUrl(urlOrPath).trim();
      final key = getCacheKey(clean);
      var ext = _extractExtension(clean);
      if (ext == '.img') {
        final srcExt = p.extension(sourceFile.path).toLowerCase();
        if (srcExt.isNotEmpty) ext = srcExt;
      }
      final dir = await getCacheDirectory();
      final cacheFile = File(p.join(dir.path, '$key$ext'));
      if (cacheFile.path != sourceFile.path) {
        await sourceFile.copy(cacheFile.path);
      }
      _cachedFileKeys.add(key);
      return cacheFile;
    } catch (e) {
      debugPrint('[LajuMediaCacheManager] putFile error: $e');
      return null;
    }
  }

  /// Saves raw bytes directly into disk cache under a URL key
  Future<File?> putBytes(String urlOrKey, Uint8List bytes, {String ext = '.mp4'}) async {
    try {
      if (bytes.isEmpty) return null;
      final key = (urlOrKey.length == 32 && !urlOrKey.contains('/') && !urlOrKey.contains(':'))
          ? urlOrKey
          : getCacheKey(urlOrKey);
      final dir = await getCacheDirectory();
      final cacheFile = File(p.join(dir.path, '$key$ext'));
      await cacheFile.writeAsBytes(bytes, flush: true);
      _cachedFileKeys.add(key);
      return cacheFile;
    } catch (e) {
      debugPrint('[LajuMediaCacheManager] putBytes error: $e');
      return null;
    }
  }

  /// Gets the local cached File if it already exists, or null
  Future<File?> getCachedFileIfPresent(String urlOrPath) async {
    final key = getCacheKey(urlOrPath);
    final ext = _extractExtension(urlOrPath);
    final dir = await getCacheDirectory();
    final file = File(p.join(dir.path, '$key$ext'));
    if (file.existsSync() && file.lengthSync() > 0) {
      _cachedFileKeys.add(key);
      return file;
    }
    return null;
  }

  /// Retrieves a media file from cache or downloads and caches it automatically.
  /// Deduplicates concurrent in-flight requests for the same URL.
  Future<File?> getSingleFile(
    String urlOrPath, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final clean = resolveMediaUrl(urlOrPath).trim();
    if (clean.isEmpty) return null;

    // 0. Check data URI
    if (clean.startsWith('data:')) {
      try {
        final commaIdx = clean.indexOf(',');
        final b64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(b64);
        final key = getCacheKey(clean);
        return await putBytes(key, bytes, ext: '.mp4');
      } catch (e) {
        debugPrint('[LajuMediaCacheManager] Base64 decode error: $e');
        return null;
      }
    }

    // 1. Check local file system
    if (clean.startsWith('file://')) {
      final local = File(Uri.parse(clean).toFilePath());
      if (local.existsSync()) return local;
    } else if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      final local = File(clean);
      if (local.existsSync()) return local;
    }

    final key = getCacheKey(clean);
    final ext = _extractExtension(clean);
    final dir = await getCacheDirectory();
    final cacheFile = File(p.join(dir.path, '$key$ext'));

    if (cacheFile.existsSync() && cacheFile.lengthSync() > 0) {
      _cachedFileKeys.add(key);
      return cacheFile;
    }

    // 2. Return active in-flight Future if already being downloaded
    if (_inFlightDownloads.containsKey(key)) {
      return _inFlightDownloads[key]!;
    }

    // 3. Initiate dedicated download with in-flight tracking
    final completer = Completer<File?>();
    _inFlightDownloads[key] = completer.future;

    _downloadToFile(clean, cacheFile, headers, timeout).then((file) {
      if (file != null) {
        _cachedFileKeys.add(key);
      }
      completer.complete(file);
    }).catchError((err) {
      debugPrint('[LajuMediaCacheManager] Download error for $clean: $err');
      completer.complete(null);
    }).whenComplete(() {
      _inFlightDownloads.remove(key);
    });

    return completer.future;
  }

  Future<File?> _downloadToFile(
    String url,
    File destinationFile,
    Map<String, String>? headers,
    Duration timeout,
  ) async {
    final tmpFile = File('${destinationFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    HttpClient? client;

    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..badCertificateCallback = (cert, host, port) => true;
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri).timeout(timeout);

      // Supply rich default headers for media streaming & authenticated endpoints
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      );
      request.headers.set(HttpHeaders.acceptHeader, '*/*');

      final token = ApiClient.instance.authToken;
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final devId = ApiClient.instance.deviceId;
      if (devId != null && devId.isNotEmpty) {
        request.headers.set('x-device-id', devId);
      }

      headers?.forEach((k, v) => request.headers.set(k, v));
      final response = await request.close().timeout(timeout);

      if (response.statusCode != HttpStatus.ok && response.statusCode != HttpStatus.partialContent) {
        debugPrint('[LajuMediaCacheManager] HTTP ${response.statusCode} for $url');
        return null;
      }

      final sink = tmpFile.openWrite();
      await response.timeout(timeout).pipe(sink);
      await sink.flush();
      await sink.close();

      if (tmpFile.existsSync() && tmpFile.lengthSync() > 0) {
        if (destinationFile.existsSync()) {
          destinationFile.deleteSync();
        }
        await tmpFile.rename(destinationFile.path);
        return destinationFile;
      }
    } catch (e) {
      debugPrint('[LajuMediaCacheManager] Download exception for $url: $e');
      if (tmpFile.existsSync()) {
        try {
          tmpFile.deleteSync();
        } catch (_) {}
      }
      return null;
    } finally {
      client?.close();
    }

    return null;
  }

  /// Retrieves raw bytes directly from cache or network
  Future<Uint8List?> getBytes(String urlOrPath) async {
    final file = await getSingleFile(urlOrPath);
    if (file != null && file.existsSync()) {
      return file.readAsBytes();
    }
    return null;
  }

  /// Fire-and-forget preloading for media (e.g. next story or chat wallpaper)
  void preload(String urlOrPath, {Map<String, String>? headers}) {
    if (urlOrPath.trim().isEmpty) return;
    if (isFileCachedSync(urlOrPath)) return;
    unawaited(getSingleFile(urlOrPath, headers: headers));
  }

  /// Clears all media cached on disk
  Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      if (dir.existsSync()) {
        final list = dir.listSync();
        for (final item in list) {
          try {
            item.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      _cachedFileKeys.clear();
      _inFlightDownloads.clear();
    } catch (e) {
      debugPrint('[LajuMediaCacheManager] clearCache error: $e');
    }
  }
}
