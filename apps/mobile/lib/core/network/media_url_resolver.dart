import '../config/env_config.dart';

/// Resolves an asset path or server-relative media URL to a fully-qualified URL
/// ready for [Image.network].
///
/// Examples:
/// - `https://example.com/pic.png` -> `https://example.com/pic.png`
/// - `/admin/media/blob-123.png` -> `https://api.laju.chat/admin/media/blob-123.png`
/// - `admin/media/blob-123.png` -> `https://api.laju.chat/admin/media/blob-123.png`
String resolveMediaUrl(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.trim().isEmpty) {
    return '';
  }

  final trimmed = pathOrUrl.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  final base = EnvConfig.instance.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$base$cleanPath';
}
