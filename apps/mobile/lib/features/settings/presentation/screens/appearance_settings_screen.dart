import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import 'wallpaper_settings_screen.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  void _showFontSizeBottomSheet(BuildContext context) {
    final langCode = LocaleController.instance.value.languageCode;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final currentSize = ChatAppearanceController.instance.fontSize;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      langCode == 'id' ? 'Ukuran Font Obrolan' : 'Chat Font Size',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF4B5563), size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  langCode == 'id'
                      ? 'Pilih ukuran teks untuk pesan di obrolan LAJU'
                      : 'Choose text size for messages across LAJU chats',
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                for (final size in LajuFontSize.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        ChatAppearanceController.instance.setFontSize(size);
                        Navigator.pop(ctx);
                        LajuToast.success(
                          context,
                          langCode == 'id'
                              ? 'Ukuran font diubah ke ${size.labelId}'
                              : 'Font size changed to ${size.labelEn}',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: currentSize == size
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: currentSize == size
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                            width: currentSize == size ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                size.getLabel(langCode),
                                style: TextStyle(
                                  fontSize: 15 * size.scale,
                                  fontWeight: currentSize == size ? FontWeight.w700 : FontWeight.w500,
                                  color: currentSize == size
                                      ? (isDark ? const Color(0xFF6EE7B7) : AppColors.primaryDark)
                                      : (isDark ? Colors.white : const Color(0xFF111827)),
                                ),
                              ),
                            ),
                            if (currentSize == size)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                              )
                            else
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeModeController.instance,
        ChatAppearanceController.instance,
        LocaleController.instance,
      ]),
      builder: (context, _) {
        final currentMode = ThemeModeController.instance.value;
        final isDark = ThemeModeController.instance.isDarkMode(context);
        final langCode = LocaleController.instance.value.languageCode;
        final activeWallpaperId = ChatAppearanceController.instance.selectedWallpaper;
        final activeWallpaper = kPresetWallpapers.firstWhere(
          (w) => w.id == activeWallpaperId,
          orElse: () => kPresetWallpapers.first,
        );
        final activeFontSize = ChatAppearanceController.instance.fontSize;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
          appBar: LajuGlassAppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('appearanceTitle'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                // Section: Theme Mode Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    context.tr('theme').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // Theme Option 1: System Default (Recommended default)
                _buildThemeOptionCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.settings_suggest_rounded,
                  title: context.tr('systemDefault'),
                  description: context.tr('systemDefaultDesc'),
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () {
                    ThemeModeController.instance.setThemeMode(ThemeMode.system);
                    LajuToast.success(context, context.tr('themeChanged'));
                  },
                ),

                const SizedBox(height: 10),

                // Theme Option 2: Light
                _buildThemeOptionCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.light_mode_rounded,
                  title: context.tr('lightTheme'),
                  description: context.tr('lightThemeDesc'),
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () {
                    ThemeModeController.instance.setThemeMode(ThemeMode.light);
                    LajuToast.success(context, context.tr('themeChanged'));
                  },
                ),

                const SizedBox(height: 10),

                // Theme Option 3: Dark
                _buildThemeOptionCard(
                  context: context,
                  isDark: isDark,
                  icon: Icons.dark_mode_rounded,
                  title: context.tr('darkTheme'),
                  description: context.tr('darkThemeDesc'),
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () {
                    ThemeModeController.instance.setThemeMode(ThemeMode.dark);
                    LajuToast.success(context, context.tr('themeChanged'));
                  },
                ),

                const SizedBox(height: 20),

                // Section: Chat Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    (langCode == 'id' ? 'Tampilan Obrolan' : 'Chat Display').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                LajuGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Column(
                    children: [
                      // Wallpaper tile
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.wallpaper_rounded, color: isDark ? AppColors.primary : const Color(0xFF2563EB), size: 20),
                          ),
                          title: Text(
                            context.tr('chatWallpaper'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            activeWallpaper.getName(langCode),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: activeWallpaper.backgroundColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey.shade400, width: 1),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WallpaperSettingsScreen()),
                            );
                          },
                        ),
                      ),

                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 56,
                        endIndent: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                      ),

                      // Font size tile
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.format_size_rounded, color: AppColors.cyan, size: 20),
                          ),
                          title: Text(
                            context.tr('fontSize'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            activeFontSize.getLabel(langCode),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activeFontSize.getLabel(langCode),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
                            ],
                          ),
                          onTap: () => _showFontSizeBottomSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOptionCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return LajuGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 18,
      blurSigma: 16,
      borderColor: isSelected ? AppColors.primary : null,
      borderWidth: isSelected ? 1.8 : 1.0,
      customShadow: isSelected
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ]
          : null,
      onTap: onTap,
      child: Material(
        color: isSelected
            ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight.withValues(alpha: 0.5))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primaryDark
                      : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (isDark ? const Color(0xFF6EE7B7) : AppColors.primaryDark)
                            : (isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? (isDark ? const Color(0xFFA7F3D0) : AppColors.primaryDark.withValues(alpha: 0.8))
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
