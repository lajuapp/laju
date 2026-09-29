import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/media_url_resolver.dart';
import '../services/laju_media_cache_manager.dart';

/// Universal High-Performance Cached Image Widget for LAJU Mobile.
///
/// Features:
/// - Disk-cached network images with persistent offline storage via [LajuMediaCacheManager].
/// - Hardware-accelerated memory downsampling via [cacheWidth] and [cacheHeight] to save up to 85% RAM.
/// - Smooth cross-fade transition from placeholder to loaded image.
/// - Universal format support: HTTP/HTTPS, server-relative `/admin/media/...`, local files, assets, and base64.
class LajuCachedImage extends StatefulWidget {
  final String? imageUrlOrPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeDuration;
  final Map<String, String>? httpHeaders;

  const LajuCachedImage({
    super.key,
    required this.imageUrlOrPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 200),
    this.httpHeaders,
  });

  @override
  State<LajuCachedImage> createState() => _LajuCachedImageState();
}

class _LajuCachedImageState extends State<LajuCachedImage> with SingleTickerProviderStateMixin {
  File? _cachedFile;
  Uint8List? _memoryBytes;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    // Instant synchronous cache resolution before first frame render
    final raw = widget.imageUrlOrPath?.trim();
    if (raw != null && raw.isNotEmpty && !raw.startsWith('data:image') && !raw.startsWith('assets/')) {
      final resolved = resolveMediaUrl(raw);
      final syncFile = LajuMediaCacheManager.instance.getCachedFileIfPresentSync(resolved);
      if (syncFile != null) {
        _cachedFile = syncFile;
        _isLoading = false;
        _fadeController.value = 1.0;
        return;
      }
    }

    _loadImage();
  }

  @override
  void didUpdateWidget(covariant LajuCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrlOrPath != widget.imageUrlOrPath) {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final raw = widget.imageUrlOrPath?.trim();
    if (raw == null || raw.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    // 1. Base64 Data URI
    if (raw.startsWith('data:image')) {
      try {
        final b64 = raw.contains(',') ? raw.split(',').last : raw;
        final bytes = base64Decode(b64);
        if (mounted) {
          setState(() {
            _memoryBytes = bytes;
            _isLoading = false;
            _hasError = false;
          });
          _fadeController.forward(from: 0);
        }
        return;
      } catch (_) {
        if (mounted) setState(() => _hasError = true);
        return;
      }
    }

    // 2. Asset Image
    if (raw.startsWith('assets/')) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        _fadeController.forward(from: 0);
      }
      return;
    }

    // 3. Local File System
    String filePath = raw;
    if (raw.startsWith('file://')) {
      try {
        filePath = Uri.parse(raw).toFilePath();
      } catch (_) {
        filePath = raw.replaceFirst('file://', '');
      }
    }

    final localFile = File(filePath);
    if (!raw.startsWith('http://') && !raw.startsWith('https://') && !raw.startsWith('/') && localFile.existsSync()) {
      if (mounted) {
        setState(() {
          _cachedFile = localFile;
          _isLoading = false;
          _hasError = false;
        });
        _fadeController.forward(from: 0);
      }
      return;
    }

    // 4. Remote / Server-Relative Network Image
    final resolvedUrl = resolveMediaUrl(raw);
    if (resolvedUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    // Check synchronous cache hit for zero-frame delay
    final existingFile = await LajuMediaCacheManager.instance.getCachedFileIfPresent(resolvedUrl);
    if (existingFile != null && mounted) {
      setState(() {
        _cachedFile = existingFile;
        _isLoading = false;
        _hasError = false;
      });
      _fadeController.value = 1.0; // Instant display on cache hit
      return;
    }

    // Fetch and store in persistent disk cache
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    final file = await LajuMediaCacheManager.instance.getSingleFile(
      resolvedUrl,
      headers: widget.httpHeaders,
    );

    if (!mounted) return;

    if (file != null && file.existsSync()) {
      setState(() {
        _cachedFile = file;
        _isLoading = false;
        _hasError = false;
      });
      _fadeController.forward(from: 0);
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
        borderRadius: widget.borderRadius,
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorWidget != null) return widget.errorWidget!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.sticky_note_2_outlined,
          size: (widget.width != null && widget.width! < 60) ? 18 : 24,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrlOrPath?.trim() ?? '';

    Widget content;
    if (_hasError || raw.isEmpty) {
      content = _buildError(context);
    } else if (_isLoading) {
      content = _buildPlaceholder(context);
    } else if (_memoryBytes != null) {
      content = FadeTransition(
        opacity: _fadeAnimation,
        child: Image.memory(
          _memoryBytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: (_, __, ___) => _buildError(context),
        ),
      );
    } else if (raw.startsWith('assets/')) {
      content = FadeTransition(
        opacity: _fadeAnimation,
        child: Image.asset(
          raw,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: (_, __, ___) => _buildError(context),
        ),
      );
    } else if (_cachedFile != null) {
      content = FadeTransition(
        opacity: _fadeAnimation,
        child: Image.file(
          _cachedFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: (_, __, ___) => _buildError(context),
        ),
      );
    } else {
      content = _buildPlaceholder(context);
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
