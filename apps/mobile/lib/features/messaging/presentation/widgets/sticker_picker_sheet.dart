import 'dart:ui' as ui;
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

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<StickerItem> onStickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
  int _selectedTabIndex = 0; // 0: Pack (Kucing), 1: Terbaru, 2: Favorit

  @override
  void initState() {
    super.initState();
    StickerService.instance.init();
  }

  void _showStickerPreview(BuildContext context, StickerItem sticker, bool isDark) {
    HapticFeedback.mediumImpact();
    final isFav = StickerService.instance.isFavorite(sticker.id);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  sticker.assetPath,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  '${sticker.name} ${sticker.emoji}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stiker LAJU End-to-End Encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        label: Text(
                          isFav ? 'Hapus Favorit' : 'Favoritkan',
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
    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 420,
          decoration: BoxDecoration(
            color: sheetBg.withValues(alpha: isDark ? 0.94 : 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

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
                          Icons.sticky_note_2_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stiker LAJU',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            'Kirim stiker lucu dan ekspresif',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: subColor, size: 22),
                        splashRadius: 20,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Category Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildTabChip(0, '🐱 Kucing Gemoy', isDark),
                      const SizedBox(width: 8),
                      _buildTabChip(1, '🕐 Terbaru', isDark),
                      const SizedBox(width: 8),
                      _buildTabChip(2, '⭐ Favorit', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: borderColor),

                // Stickers Grid View
                Expanded(
                  child: AnimatedBuilder(
                    animation: StickerService.instance,
                    builder: (context, _) {
                      List<StickerItem> displayStickers;
                      if (_selectedTabIndex == 1) {
                        displayStickers = StickerService.instance.recentStickers;
                      } else if (_selectedTabIndex == 2) {
                        displayStickers = StickerService.kSampleCatStickers
                            .where((s) => StickerService.instance.isFavorite(s.id))
                            .toList();
                      } else {
                        displayStickers = StickerService.kSampleCatStickers;
                      }

                      if (displayStickers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedTabIndex == 1
                                    ? Icons.history_rounded
                                    : Icons.star_border_rounded,
                                size: 48,
                                color: subColor.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedTabIndex == 1
                                    ? 'Belum ada stiker yang baru dikirim'
                                    : 'Belum ada stiker favorit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pilih stiker dari tab Kucing Gemoy',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: subColor.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: displayStickers.length,
                        itemBuilder: (context, index) {
                          final sticker = displayStickers[index];
                          return _buildStickerTile(sticker, isDark);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.black12),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerTile(StickerItem sticker, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          StickerService.instance.recordStickerUsage(sticker);
          widget.onStickerSelected(sticker);
        },
        onLongPress: () => _showStickerPreview(context, sticker, isDark),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Hero(
                  tag: 'sticker_${sticker.id}',
                  child: Image.asset(
                    sticker.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sticker.name,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
