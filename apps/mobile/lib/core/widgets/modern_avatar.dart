import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../network/media_url_resolver.dart';
import '../services/laju_media_cache_manager.dart';

class ModernAvatar extends StatefulWidget {
  final String name;
  final double radius;
  final double? size;
  final bool isOnline;
  final bool showOfflineDot;
  final bool isVerified;
  final List<Color>? customGradient;
  final String? imagePath;
  final String? heroTag;

  const ModernAvatar({
    super.key,
    required this.name,
    this.radius = 26,
    this.size,
    this.isOnline = false,
    this.showOfflineDot = false,
    this.isVerified = true,
    this.customGradient,
    this.imagePath,
    this.heroTag,
  });

  // Modern vibrant palette for avatars (never black / dark dull colors)
  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald / Mint
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Royal Blue
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)], // Purple / Violet
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Warm Amber / Orange
    [Color(0xFFEC4899), Color(0xFFDB2777)], // Pink / Coral
    [Color(0xFF06B6D4), Color(0xFF0E7490)], // Cyan / Aqua
    [Color(0xFF6366F1), Color(0xFF4338CA)], // Indigo
    [Color(0xFF14B8A6), Color(0xFF0F766E)], // Teal
    [Color(0xFFF97316), Color(0xFFC2410C)], // Sunset Orange
  ];

  // Static in-memory cache to prevent re-decoding base64 or creating duplicate ImageProviders on every rebuild
  static final Map<String, ImageProvider> _imageProviderCache = {};

  static List<Color> _resolveGradient(String text, [List<Color>? customGradient]) {
    if (customGradient != null && customGradient.length >= 2) {
      return customGradient;
    }
    if (text.trim().isEmpty) {
      return _avatarGradients[0];
    }
    final hash = text.trim().codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  static ImageProvider? _resolveProvider(String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty) return null;
    final trimmed = rawPath.trim();

    if (_imageProviderCache.containsKey(trimmed)) {
      return _imageProviderCache[trimmed];
    }

    String normalizedPath = trimmed;
    if (trimmed.startsWith('file://')) {
      try {
        normalizedPath = Uri.parse(trimmed).toFilePath();
      } catch (_) {
        normalizedPath = trimmed.replaceFirst('file://', '');
      }
    }
    // Never treat video URLs or video data as avatar images
    final isVideo = normalizedPath.endsWith('.mp4') ||
        normalizedPath.endsWith('.mov') ||
        normalizedPath.endsWith('.webm') ||
        normalizedPath.startsWith('data:video');
    if (isVideo) {
      return null;
    }

    final isBase64 = normalizedPath.startsWith('data:image') || normalizedPath.startsWith('data:application');
    final isLocalFile = !isBase64 &&
        !normalizedPath.startsWith('http://') &&
        !normalizedPath.startsWith('https://') &&
        File(normalizedPath).existsSync();
    final isNetwork = !isBase64 && !isLocalFile && (
        normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://') ||
        normalizedPath.startsWith('/') ||
        normalizedPath.contains('/'));

    ImageProvider? provider;
    if (isNetwork) {
      final resolved = resolveMediaUrl(normalizedPath);
      final cached = LajuMediaCacheManager.instance.getCachedFileIfPresentSync(resolved);
      if (cached != null) {
        provider = FileImage(cached);
      } else {
        provider = NetworkImage(resolved);
        LajuMediaCacheManager.instance.preload(resolved);
      }
    } else if (isBase64) {
      try {
        final b64 = normalizedPath.split(',').last;
        final bytes = base64Decode(b64);
        provider = MemoryImage(bytes);
      } catch (_) {}
    } else if (isLocalFile) {
      provider = FileImage(File(normalizedPath));
    }

    if (provider != null) {
      // Limit cache size to prevent unbounded memory growth while keeping active avatars warm
      if (_imageProviderCache.length > 300) {
        _imageProviderCache.clear();
      }
      _imageProviderCache[trimmed] = provider;
    }

    return provider;
  }

  @override
  State<ModernAvatar> createState() => _ModernAvatarState();
}

class _ModernAvatarState extends State<ModernAvatar> {
  ImageProvider? _resolvedProvider;
  bool _imageFailed = false;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  @override
  void didUpdateWidget(ModernAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePath != oldWidget.imagePath) {
      _imageFailed = false;
      _loadProvider();
    }
  }

  void _loadProvider() {
    _resolvedProvider = ModernAvatar._resolveProvider(widget.imagePath);
    if (_resolvedProvider != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _resolvedProvider != null) {
          precacheImage(
            _resolvedProvider!,
            context,
            onError: (_, __) {
              if (mounted) setState(() => _imageFailed = true);
            },
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.size != null ? (widget.size! / 2) : widget.radius;
    final trimmed = widget.name.trim();
    final initials = trimmed.isNotEmpty
        ? trimmed.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join('').toUpperCase()
        : '?';

    final gradientColors = ModernAvatar._resolveGradient(widget.name, widget.customGradient);
    final showImage = _resolvedProvider != null && !_imageFailed;

    Widget avatarCircle = Container(
      width: effectiveRadius * 2,
      height: effectiveRadius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: showImage
            ? Image(
                image: _resolvedProvider!,
                fit: BoxFit.cover,
                width: effectiveRadius * 2,
                height: effectiveRadius * 2,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) {
                  return Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: effectiveRadius * 0.72,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: effectiveRadius * 0.72,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    shadows: const [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );

    if (widget.heroTag != null && widget.heroTag!.isNotEmpty) {
      avatarCircle = Hero(
        tag: widget.heroTag!,
        flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
          return Material(
            color: Colors.transparent,
            child: toHeroContext.widget,
          );
        },
        child: avatarCircle,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarCircle,
        if (widget.isOnline || widget.showOfflineDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: effectiveRadius > 22 ? 14 : 11,
              height: effectiveRadius > 22 ? 14 : 11,
              decoration: BoxDecoration(
                color: widget.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        if (widget.isVerified && !widget.isOnline && !widget.showOfflineDot)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 13,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
