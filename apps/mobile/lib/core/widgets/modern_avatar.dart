import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ModernAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final double? size;
  final bool isOnline;
  final bool isVerified;
  final List<Color>? customGradient;
  final String? imagePath;

  const ModernAvatar({
    super.key,
    required this.name,
    this.radius = 26,
    this.size,
    this.isOnline = false,
    this.isVerified = true,
    this.customGradient,
    this.imagePath,
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

  List<Color> _resolveGradient(String text) {
    if (customGradient != null && customGradient!.length >= 2) {
      return customGradient!;
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

    final isNetwork = normalizedPath.startsWith('http://') || normalizedPath.startsWith('https://');
    final isBase64 = normalizedPath.startsWith('data:image') || normalizedPath.startsWith('data:application');
    final isLocalFile = !isNetwork && !isBase64 && File(normalizedPath).existsSync();

    ImageProvider? provider;
    if (isNetwork) {
      provider = NetworkImage(normalizedPath);
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
      // Limit cache size to prevent unbounded memory growth
      if (_imageProviderCache.length > 200) {
        _imageProviderCache.clear();
      }
      _imageProviderCache[trimmed] = provider;
    }

    return provider;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = size != null ? (size! / 2) : radius;
    final trimmed = name.trim();
    final initials = trimmed.isNotEmpty
        ? trimmed.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join('').toUpperCase()
        : '?';

    final gradientColors = _resolveGradient(name);
    final avatarProvider = _resolveProvider(imagePath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: effectiveRadius * 2,
          height: effectiveRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Always retain the gradient background so there is NEVER a transparent/white flash
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
          alignment: Alignment.center,
          child: ClipOval(
            child: SizedBox(
              width: effectiveRadius * 2,
              height: effectiveRadius * 2,
              child: avatarProvider != null
                  ? Image(
                      image: avatarProvider,
                      width: effectiveRadius * 2,
                      height: effectiveRadius * 2,
                      fit: BoxFit.cover,
                      gaplessPlayback: true, // Prevents glitch/blink during rebuilds!
                      errorBuilder: (context, error, stackTrace) {
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
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: effectiveRadius > 22 ? 14 : 11,
              height: effectiveRadius > 22 ? 14 : 11,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        if (isVerified && !isOnline)
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
