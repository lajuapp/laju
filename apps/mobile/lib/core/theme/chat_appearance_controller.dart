import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LajuFontSize {
  small(0.9, 'Small', 'Kecil'),
  medium(1.0, 'Medium', 'Sedang'),
  large(1.15, 'Large', 'Besar');

  final double scale;
  final String labelEn;
  final String labelId;

  const LajuFontSize(this.scale, this.labelEn, this.labelId);

  String getLabel(String langCode) => langCode == 'id' ? labelId : labelEn;
}

class ChatAppearanceController extends ChangeNotifier {
  ChatAppearanceController._();

  static final ChatAppearanceController instance = ChatAppearanceController._();

  // Selected wallpaper index or key: 'default' automatically adapts to light/dark!
  String _selectedWallpaper = 'default';
  LajuFontSize _fontSize = LajuFontSize.medium;

  String get selectedWallpaper => _selectedWallpaper;
  LajuFontSize get fontSize => _fontSize;
  double get fontScale => _fontSize.scale;

  /// Load saved appearance settings from SharedPreferences on app start
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedWallpaper = prefs.getString('laju_wallpaper') ?? 'default';
      final savedFont = prefs.getString('laju_font_size') ?? 'medium';
      _fontSize = LajuFontSize.values.firstWhere(
        (f) => f.name == savedFont,
        orElse: () => LajuFontSize.medium,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setWallpaper(String wallpaperId) async {
    if (_selectedWallpaper != wallpaperId) {
      _selectedWallpaper = wallpaperId;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_wallpaper', wallpaperId);
      } catch (_) {}
    }
  }

  Future<void> setFontSize(LajuFontSize size) async {
    if (_fontSize != size) {
      _fontSize = size;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('laju_font_size', size.name);
      } catch (_) {}
    }
  }
}

class WallpaperOption {
  final String id;
  final String nameEn;
  final String nameId;
  final Color backgroundColor;
  final Color? secondaryColor;
  final String? lightAsset;
  final String? darkAsset;
  final bool hasDoodlePattern;

  const WallpaperOption({
    required this.id,
    required this.nameEn,
    required this.nameId,
    required this.backgroundColor,
    this.secondaryColor,
    this.lightAsset,
    this.darkAsset,
    this.hasDoodlePattern = false,
  });

  String getName(String langCode) => langCode == 'id' ? nameId : nameEn;

  /// Returns the asset path if this option uses a custom image background
  String? getAssetPath(bool isDark) {
    if (isDark) {
      return darkAsset ?? lightAsset;
    } else {
      return lightAsset ?? darkAsset;
    }
  }
}

final List<WallpaperOption> kPresetWallpapers = [
  const WallpaperOption(
    id: 'default',
    nameEn: 'LAJU Official Doodle (Adaptive)',
    nameId: 'Doodle Resmi LAJU (Adaptif)',
    backgroundColor: Color(0xFFE8F5E9),
    secondaryColor: Color(0xFF0F1A1C),
    lightAsset: 'assets/images/chat_bg_light.png',
    darkAsset: 'assets/images/chat_bg_dark.png',
    hasDoodlePattern: true,
  ),
  const WallpaperOption(
    id: 'dark_obsidian',
    nameEn: 'Dark Obsidian Doodle',
    nameId: 'Obsidian Gelap Doodle',
    backgroundColor: Color(0xFF0A181C),
    secondaryColor: Color(0xFF0F1F24),
    lightAsset: 'assets/images/chat_bg_dark.png',
    darkAsset: 'assets/images/chat_bg_dark.png',
    hasDoodlePattern: true,
  ),
  const WallpaperOption(
    id: 'light_mint',
    nameEn: 'Light Mint Doodle',
    nameId: 'Mint Terang Doodle',
    backgroundColor: Color(0xFFF0FDF4),
    secondaryColor: Color(0xFFDCFCE7),
    lightAsset: 'assets/images/chat_bg_light.png',
    darkAsset: 'assets/images/chat_bg_light.png',
    hasDoodlePattern: true,
  ),
  const WallpaperOption(
    id: 'slate_minimal',
    nameEn: 'Clean Slate Gray',
    nameId: 'Abu-Abu Minimalis',
    backgroundColor: Color(0xFFF3F4F6),
    hasDoodlePattern: false,
  ),
  const WallpaperOption(
    id: 'midnight_navy',
    nameEn: 'Midnight Encrypted Blue',
    nameId: 'Biru Midnight Enkripsi',
    backgroundColor: Color(0xFF0F172A),
    secondaryColor: Color(0xFF1E293B),
    hasDoodlePattern: false,
  ),
  const WallpaperOption(
    id: 'cyber_dusk',
    nameEn: 'Cyber Dusk Violet',
    nameId: 'Violet Senja Siber',
    backgroundColor: Color(0xFF1E1B2E),
    secondaryColor: Color(0xFF2A2440),
    hasDoodlePattern: false,
  ),
];
