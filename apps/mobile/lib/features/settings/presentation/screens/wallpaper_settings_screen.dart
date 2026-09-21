import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class WallpaperSettingsScreen extends StatelessWidget {
  const WallpaperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langCode = LocaleController.instance.value.languageCode;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return ListenableBuilder(
      listenable: ChatAppearanceController.instance,
      builder: (context, _) {
        final currentWallpaperId = ChatAppearanceController.instance.selectedWallpaper;
        final activeWallpaper = kPresetWallpapers.firstWhere(
          (w) => w.id == currentWallpaperId,
          orElse: () => kPresetWallpapers.first,
        );
        final activeAsset = activeWallpaper.getAssetPath(isDark);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            title: Text(langCode == 'id' ? 'Wallpaper Obrolan' : 'Chat Wallpaper'),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Live Preview Mockup
                  Text(
                    langCode == 'id' ? 'Pratinjau Langsung' : 'Live Preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Mockup Phone Frame with Live Wallpaper
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF071216) : activeWallpaper.backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            // Actual Wallpaper Image Asset if present
                            if (activeAsset != null)
                              Positioned.fill(
                                child: Image.asset(
                                  activeAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: isDark ? const Color(0xFF0D1B22) : const Color(0xFFE8F5E9),
                                    child: Center(
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 48,
                                        color: isDark ? Colors.white24 : Colors.black12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                      // Sample Chat Bubbles Overlay
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  langCode == 'id'
                                      ? 'Sistem obrolan aman LAJU siap digunakan 🔒'
                                      : 'LAJU secure messaging active 🔒',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF065F46) : const Color(0xFFD6F8EC),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(14),
                                    bottomLeft: Radius.circular(14),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      langCode == 'id'
                                          ? 'Enkripsi kuantum PQ-X3DH terverifikasi'
                                          : 'PQ-X3DH quantum keys verified',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF064E3B),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.done_all_rounded, size: 15, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              const SizedBox(height: 24),

              Text(
                langCode == 'id' ? 'Pilih Tema Latar Belakang' : 'Select Wallpaper Theme',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),

              // Wallpaper Grid Picker
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: kPresetWallpapers.length,
                itemBuilder: (context, index) {
                  final item = kPresetWallpapers[index];
                  final isSelected = item.id == currentWallpaperId;
                  final itemAsset = item.getAssetPath(isDark);

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ChatAppearanceController.instance.setWallpaper(item.id);
                      LajuToast.success(
                        context,
                        langCode == 'id'
                            ? 'Wallpaper "${item.nameId}" dipilih'
                            : 'Wallpaper "${item.nameEn}" selected',
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            // Mini Asset preview if present
                            if (itemAsset != null)
                              Positioned.fill(
                                child: Image.asset(
                                  itemAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(),
                                ),
                              ),

                            // Overlay gradient for text readability
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.25),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.65),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          itemAsset != null ? 'Official' : 'Solid',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    item.getName(langCode),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Color(0xCC000000),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  },
);
  }
}
