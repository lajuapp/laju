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

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = size != null ? (size! / 2) : radius;
    final trimmed = name.trim();
    final initials = trimmed.isNotEmpty
        ? trimmed.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join('').toUpperCase()
        : '?';

    final gradientColors = _resolveGradient(name);

    final path = imagePath?.trim();
    final isNetwork = path != null && (path.startsWith('http://') || path.startsWith('https://'));
    final isLocalFile = !isNetwork && path != null && path.isNotEmpty && File(path).existsSync();
    final hasValidImage = isNetwork || isLocalFile;
    final ImageProvider? avatarProvider = isNetwork
        ? NetworkImage(path)
        : (isLocalFile ? FileImage(File(path)) : null);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: effectiveRadius * 2,
          height: effectiveRadius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasValidImage
                ? null
                : LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            image: hasValidImage && avatarProvider != null
                ? DecorationImage(
                    image: avatarProvider,
                    fit: BoxFit.cover,
                  )
                : null,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasValidImage ? AppColors.primary : gradientColors[0]).withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: hasValidImage
              ? null
              : Text(
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
