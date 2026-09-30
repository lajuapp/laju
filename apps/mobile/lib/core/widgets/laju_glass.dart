import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

/// Renders a multi-layered ambient neon lighting canvas with glowing orbs
/// (emerald green, electric cyan, and indigo) behind screen content.
/// Provides authentic specular refraction depth for frosted glass surfaces.
class LajuGlassBackground extends StatelessWidget {
  final Widget child;
  final bool showOrbs;

  const LajuGlassBackground({
    super.key,
    required this.child,
    this.showOrbs = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Stack(
      children: [
        // Base Theme Background isolated from repaints
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
            ),
          ),
        ),

        // Ambient Glowing Neon Orbs isolated with RepaintBoundary so foreground scrolls do not repaint canvas
        if (showOrbs)
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  // Top Left Neon Emerald Orb
                  Positioned(
                    top: -60,
                    left: -40,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Mid Right Electric Cyan Orb
                  Positioned(
                    top: 220,
                    right: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.18 : 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Left Violet Orb
                  Positioned(
                    bottom: -60,
                    left: 20,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: isDark ? 0.14 : 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Main Foreground Child
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

/// A high-performance frosted glass container with specular gradient reflection,
/// subtle glass border, translucent tinting, and ambient drop shadow.
///
/// By default, uses an optimized specular faux-glass gradient (`enableBackdropBlur: false`)
/// which provides 60-120fps buttery-smooth scrolling without GPU `saveLayer` bottlenecks.
/// BackdropFilter can be enabled when needed (e.g. for floating overlays).
class LajuGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final bool enableBackdropBlur;
  final Color? tintColor;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final List<BoxShadow>? customShadow;

  const LajuGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.blurSigma = 16,
    this.enableBackdropBlur = false,
    this.tintColor,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1.0,
    this.onTap,
    this.customShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    // Dynamic glass gradient (authentic frosted specular look)
    final effectiveGradient = gradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  (tintColor ?? const Color(0xFF1E293B)).withValues(alpha: 0.72),
                  (tintColor ?? const Color(0xFF0F172A)).withValues(alpha: 0.58),
                ]
              : [
                  (tintColor ?? Colors.white).withValues(alpha: 0.88),
                  (tintColor ?? const Color(0xFFF8FAFC)).withValues(alpha: 0.70),
                ],
        );

    final effectiveBorderColor = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.45));

    final effectiveShadow = customShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ];

    final innerRadius = borderRadius > borderWidth ? borderRadius - borderWidth : borderRadius;
    final innerCard = Container(
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    Widget content;
    if (enableBackdropBlur && blurSigma > 0) {
      content = Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: effectiveShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: innerCard,
          ),
        ),
      );
    } else {
      content = Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: effectiveShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: innerCard,
        ),
      );
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// A frosted glass App Bar with backdrop blur, specular bottom border,
/// and responsive layout.
class LajuGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double elevation;
  final bool centerTitle;
  final double? titleSpacing;

  const LajuGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.elevation = 0,
    this.centerTitle = false,
    this.titleSpacing,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.82),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
            ),
            child: AppBar(
              title: title,
              leading: leading,
              actions: actions,
              bottom: bottom,
              centerTitle: centerTitle,
              titleSpacing: titleSpacing,
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
