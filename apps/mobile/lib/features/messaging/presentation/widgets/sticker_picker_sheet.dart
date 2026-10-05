import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/models/sticker_model.dart';
import '../../domain/services/sticker_service.dart';

class StickerPickerSheet extends StatefulWidget {
  final ValueChanged<StickerItem> onStickerSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
  });

  static void show({
    required BuildContext context,
    required ValueChanged<StickerItem> onStickerSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StickerPickerSheet(
        onStickerSelected: (sticker) {
          Navigator.pop(ctx);
          onStickerSelected(sticker);
        },
      ),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        StickerService.instance.init();
        StickerService.instance.fetchRemoteStickers();
      }
    });
  }

  void _showStickerPreview(BuildContext context, StickerItem sticker, bool isDark) {
    HapticFeedback.mediumImpact();
    final isFav = StickerService.instance.isFavorite(sticker.id);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Center(
                    child: LajuAnimatedSticker(
                      pathOrUrl: sticker.isRemote ? sticker.effectivePathOrUrl : sticker.assetPath,
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  sticker.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isFav ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
                          side: BorderSide(
                            color: isFav ? Colors.amber : (isDark ? Colors.white24 : Colors.black26),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 19,
                          color: isFav ? Colors.amber : null,
                        ),
                        label: Text(
                          isFav ? 'Favorit' : 'Favoritkan',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          StickerService.instance.toggleFavorite(sticker);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Kirim',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          StickerService.instance.recordStickerUsage(sticker);
                          widget.onStickerSelected(sticker);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgCardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: StickerService.instance,
      builder: (context, _) {
        final packs = StickerService.instance.getAllPacks();
        final recentIndex = packs.length;
        final favIndex = packs.length + 1;

        // Ensure selected tab is within bounds
        final safeTabIndex = _selectedTabIndex > favIndex ? 0 : _selectedTabIndex;

        List<StickerItem> displayStickers;
        String currentSectionTitle = 'Stiker LAJU';
        String currentSectionSubtitle = 'Kirim stiker lucu dan ekspresif';

        if (safeTabIndex == recentIndex) {
          displayStickers = StickerService.instance.recentStickers;
          currentSectionTitle = 'Baru Digunakan';
          currentSectionSubtitle = '${displayStickers.length} stiker';
        } else if (safeTabIndex == favIndex) {
          final allStickers = packs.expand((p) => p.stickers).toList();
          displayStickers = allStickers
              .where((s) => StickerService.instance.isFavorite(s.id))
              .toList();
          currentSectionTitle = 'Stiker Favorit';
          currentSectionSubtitle = '${displayStickers.length} stiker favorit tersimpan';
        } else if (safeTabIndex < packs.length) {
          final p = packs[safeTabIndex];
          displayStickers = p.stickers;
          currentSectionTitle = p.name;
          currentSectionSubtitle = '${p.stickers.length} stiker • ${p.publisher ?? 'Official LAJU'}';
        } else {
          displayStickers = packs.isNotEmpty ? packs.first.stickers : [];
          if (packs.isNotEmpty) {
            currentSectionTitle = packs.first.name;
            currentSectionSubtitle = '${packs.first.stickers.length} stiker';
          }
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.60,
          decoration: BoxDecoration(
            color: bgCardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Top Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_emotions_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSectionTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currentSectionSubtitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: subColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (StickerService.instance.isLoadingRemote)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subColor, size: 22),
                      splashRadius: 20,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Horizontally Scrollable Pack Tabs with Real Thumbnails
              if (packs.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: packs.length + 2,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index < packs.length) {
                        final pack = packs[index];
                        return _buildPackThumbnailTab(
                          index: index,
                          pack: pack,
                          isSelected: safeTabIndex == index,
                          isDark: isDark,
                        );
                      } else if (index == recentIndex) {
                        return _buildIconTab(
                          index: recentIndex,
                          icon: Icons.history_rounded,
                          label: 'Terbaru',
                          isSelected: safeTabIndex == recentIndex,
                          isDark: isDark,
                        );
                      } else {
                        return _buildIconTab(
                          index: favIndex,
                          icon: Icons.star_rounded,
                          label: 'Favorit',
                          isSelected: safeTabIndex == favIndex,
                          isDark: isDark,
                        );
                      }
                    },
                  ),
                ),
              if (packs.isNotEmpty) const SizedBox(height: 10),
              if (packs.isNotEmpty) Divider(height: 1, color: borderColor),

              // Stickers Grid View
              Expanded(
                child: packs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                ),
                                child: const Icon(
                                  Icons.emoji_emotions_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum Ada Stiker Online',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Stiker resmi yang diunggah melalui Backoffice akan muncul di sini secara otomatis.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: subColor, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {
                                  StickerService.instance.fetchRemoteStickers();
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Muat Ulang Stiker'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : displayStickers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  safeTabIndex == recentIndex
                                      ? Icons.history_rounded
                                      : (safeTabIndex == favIndex
                                          ? Icons.star_border_rounded
                                          : Icons.sticky_note_2_outlined),
                                  size: 48,
                                  color: subColor.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  safeTabIndex == recentIndex
                                      ? 'Belum ada stiker yang baru digunakan'
                                      : (safeTabIndex == favIndex
                                          ? 'Belum ada stiker favorit tersimpan'
                                          : 'Pack stiker ini kosong'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: displayStickers.length,
                            itemBuilder: (context, index) {
                              final sticker = displayStickers[index];
                              return _buildStickerTile(sticker, isDark);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab Item: Sticker Pack with Real Thumbnail ────────────────────────────
  Widget _buildPackThumbnailTab({
    required int index,
    required StickerPack pack,
    required bool isSelected,
    required bool isDark,
  }) {
    final thumb = pack.thumbnailPathOrUrl;

    Widget thumbWidget;
    if (thumb != null && thumb.isNotEmpty) {
      if (thumb.startsWith('http://') || thumb.startsWith('https://') || thumb.startsWith('/')) {
        thumbWidget = LajuCachedImage(
          imageUrlOrPath: thumb,
          width: 26,
          height: 26,
          fit: BoxFit.contain,
          cacheWidth: 80,
          errorWidget: const Icon(Icons.sticky_note_2_rounded, size: 18, color: AppColors.primary),
        );
      } else {
        thumbWidget = Image.asset(thumb, width: 26, height: 26, fit: BoxFit.contain);
      }
    } else {
      thumbWidget = const Icon(Icons.sticky_note_2_rounded, size: 18, color: AppColors.primary);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Center(child: thumbWidget),
            ),
            const SizedBox(width: 8),
            Text(
              pack.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Item: Icon Tab (Terbaru & Favorit) ─────────────────────────────────
  Widget _buildIconTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticker Grid Tile ─────────────────────────────────────────────────────
  Widget _buildStickerTile(StickerItem sticker, bool isDark) {
    final pathOrUrl = sticker.isRemote ? sticker.effectivePathOrUrl : sticker.assetPath;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          StickerService.instance.recordStickerUsage(sticker);
          widget.onStickerSelected(sticker);
        },
        onLongPress: () => _showStickerPreview(context, sticker, isDark),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: LajuCachedImage(
            imageUrlOrPath: pathOrUrl,
            fit: BoxFit.contain,
            cacheWidth: 192,
            placeholder: const SizedBox(),
            errorWidget: Icon(
              Icons.sticky_note_2_outlined,
              size: 24,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ),
      ),
    );
  }
}
