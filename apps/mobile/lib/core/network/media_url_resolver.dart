import 'dart:io';
import '../config/env_config.dart';

/// Resolves an asset path, data URI, local file, or server-relative media URL
/// to a valid URI/path ready for [LajuCachedImage] or [Image].
///
/// Examples:
/// - `https://example.com/pic.png` -> `https://example.com/pic.png`
/// - `data:image/jpeg;base64,...` -> `data:image/jpeg;base64,...` (preserved intact)
/// - `/data/user/0/.../pic.jpg` -> `/data/user/0/.../pic.jpg` (local file preserved)
/// - `/status/media/blob-123.jpg` -> `https://api.laju.chat/status/media/blob-123.jpg`
String resolveMediaUrl(String? pathOrUrl) {
  if (pathOrUrl == null || pathOrUrl.trim().isEmpty) {
    return '';
  }

  final trimmed = pathOrUrl.trim();

  // 1. Fully-qualified HTTP/HTTPS URLs
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  // 2. Base64 Data URIs (e.g. data:image/jpeg;base64,...)
  if (trimmed.startsWith('data:')) {
    return trimmed;
  }

  // 3. Local file URIs or Flutter assets
  if (trimmed.startsWith('file://') || trimmed.startsWith('assets/')) {
    return trimmed;
  }

  // 4. Existing local filesystem paths (e.g. /data/user/0/..., /storage/..., /var/...)
  try {
    if (File(trimmed).existsSync()) {
      return trimmed;
    }
  } catch (_) {}

  // 5. Server-relative endpoint paths (e.g. /status/media/..., /attachments/...)
  final base = EnvConfig.instance.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return '$base$cleanPath';
}
