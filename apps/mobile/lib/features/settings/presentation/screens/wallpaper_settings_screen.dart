import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';

class WallpaperSettingsScreen extends StatefulWidget {
  final String? chatId;
  final String? chatTitle;

  const WallpaperSettingsScreen({
    super.key,
    this.chatId,
    this.chatTitle,
  });

  @override
  State<WallpaperSettingsScreen> createState() => _WallpaperSettingsScreenState();
}

class _WallpaperSettingsScreenState extends State<WallpaperSettingsScreen> {
  String? _previewWallpaperId;
  Timer? _syncTimer;

  static const WallpaperOption kPlainWallpaperOption = WallpaperOption(
    id: 'none',
    nameEn: 'Default (Plain)',
    nameId: 'Default (Polos)',
    backgroundColor: Color(0xFF0F172A),
    category: 'POLOS',
    isDefault: true,
    isRemote: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ChatAppearanceController.instance.fetchRemoteWallpapers();
      }
    });

    if (widget.chatId != null) {
      _syncTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (mounted) {
          ConversationService.instance.fetchMessages(widget.chatId!);
        }
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = LocaleController.instance.value.languageCode;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return ListenableBuilder(
      listenable: ChatAppearanceController.instance,
      builder: (context, _) {
        final currentWallpaperId = _previewWallpaperId ??
            (widget.chatId != null
                ? (ChatAppearanceController.instance.getChatWallpaper(widget.chatId!) ?? 'none')
                : ChatAppearanceController.instance.selectedWallpaper);

        final rawWallpapers = ChatAppearanceController.instance.allWallpapers;
        final allWallpapers = [kPlainWallpaperOption, ...rawWallpapers];

        final activeWallpaper = allWallpapers.firstWhere(
          (w) => w.id == currentWallpaperId,
          orElse: () => kPlainWallpaperOption,
        );

        final pageTitle = widget.chatTitle != null
            ? (langCode == 'id' ? 'Wallpaper - ${widget.chatTitle}' : 'Wallpaper - ${widget.chatTitle}')
            : (langCode == 'id' ? 'Wallpaper Obrolan' : 'Chat Wallpaper');

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            title: Text(pageTitle),
            actions: [
              if (ChatAppearanceController.instance.isLoadingRemote)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                ),
            ],
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Live Preview Mockup
                  Text(
                    langCode == 'id' ? 'Pratinjau Langsung (Online)' : 'Live Preview (Online)',
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
                        color: activeWallpaper.backgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            // Plain default background if 'none'
                            if (activeWallpaper.id == 'none')
                              Positioned.fill(
                                child: Container(
                                  color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF1F5F9),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.format_color_reset_rounded,
                                          size: 32,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          langCode == 'id' ? 'Default Polos (Tanpa Wallpaper)' : 'Default Plain (No Wallpaper)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              // Base Color & Gradient Fill
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activeWallpaper.backgroundColor,
                                    gradient: activeWallpaper.category == 'GRADIENT'
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              activeWallpaper.backgroundColor,
                                              activeWallpaper.backgroundColor.withValues(alpha: 0.75),
                                              const Color(0xFF0F172A),
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                              ),

                              // Remote Wallpaper Image from Backoffice if present
                              if (activeWallpaper.hasRemoteImage)
                                Positioned.fill(
                                  child: Image.network(
                                    resolveMediaUrl(activeWallpaper.remoteImageUrl),
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        color: activeWallpaper.backgroundColor,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => Container(
                                      color: activeWallpaper.backgroundColor,
                                    ),
                                  ),
                                ),
                            ],

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
                                            ? 'Halo! Pesan ini dienkripsi end-to-end 🔒'
                                            : 'Hello! This message is end-to-end encrypted 🔒',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
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
                    itemCount: allWallpapers.length,
                    itemBuilder: (context, index) {
                      final item = allWallpapers[index];
                      final isSelected = item.id == currentWallpaperId;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _previewWallpaperId = item.id;
                          });
                          final name = item.id == 'none'
                              ? (langCode == 'id' ? 'Default Polos' : 'Default Plain')
                              : item.getName(langCode);

                          if (widget.chatId != null) {
                            ChatAppearanceController.instance.setChatWallpaper(widget.chatId!, item.id);
                            ConversationService.instance.sendWallpaperChange(
                              conversationId: widget.chatId!,
                              wallpaperId: item.id,
                              wallpaperName: name,
                            );
                          } else {
                            ChatAppearanceController.instance.setWallpaper(item.id);
                          }

                          LajuToast.success(
                            context,
                            langCode == 'id'
                                ? 'Wallpaper "$name" diterapkan untuk ${widget.chatTitle ?? 'obrolan ini'}'
                                : 'Wallpaper "$name" applied for ${widget.chatTitle ?? 'this chat'}',
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
                                if (item.id == 'none')
                                  Positioned.fill(
                                    child: Container(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.block_rounded,
                                              size: 26,
                                              color: isDark ? Colors.white54 : Colors.black45,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Polos',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Background Color & Gradient
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: item.backgroundColor,
                                        gradient: item.category == 'GRADIENT'
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  item.backgroundColor,
                                                  item.backgroundColor.withValues(alpha: 0.75),
                                                  const Color(0xFF0F172A),
                                                ],
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),

                                  // Remote Image preview if present
                                  if (item.hasRemoteImage)
                                    Positioned.fill(
                                      child: Image.network(
                                        resolveMediaUrl(item.remoteImageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const SizedBox(),
                                      ),
                                    ),
                                ],

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
                                          Colors.black.withValues(alpha: 0.7),
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
                                              item.category ?? 'ONLINE',
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
