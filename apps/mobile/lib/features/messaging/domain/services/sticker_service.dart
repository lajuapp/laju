import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sticker_model.dart';

class StickerService extends ChangeNotifier {
  StickerService._();
  static final StickerService instance = StickerService._();

  static const String _kRecentKey = 'laju_recent_stickers';
  static const String _kFavoriteKey = 'laju_favorite_stickers';

  final List<StickerItem> _recentStickers = [];
  final List<String> _favoriteIds = [];

  List<StickerItem> get recentStickers => List.unmodifiable(_recentStickers);
  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);

  static const List<StickerItem> kSampleCatStickers = [
    StickerItem(
      id: 'cat_thumbs_up',
      name: 'Mantap',
      assetPath: 'assets/images/stickers/cat_thumbs_up.png',
      packId: 'laju_cats',
      emoji: '👍',
    ),
    StickerItem(
      id: 'cat_cool',
      name: 'Keren',
      assetPath: 'assets/images/stickers/cat_cool.png',
      packId: 'laju_cats',
      emoji: '😎',
    ),
    StickerItem(
      id: 'cat_cheer',
      name: 'Semangat',
      assetPath: 'assets/images/stickers/cat_cheer.png',
      packId: 'laju_cats',
      emoji: '🎉',
    ),
  ];

  static const StickerPack kDefaultPack = StickerPack(
    id: 'laju_cats',
    name: 'Kucing Gemoy',
    iconEmoji: '🐱',
    stickers: kSampleCatStickers,
  );

  List<StickerPack> getAllPacks() {
    return [
      kDefaultPack,
    ];
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentJson = prefs.getStringList(_kRecentKey);
      if (recentJson != null) {
        _recentStickers.clear();
        for (final item in recentJson) {
          try {
            _recentStickers.add(StickerItem.fromJson(jsonDecode(item)));
          } catch (_) {}
        }
      }
      final favList = prefs.getStringList(_kFavoriteKey);
      if (favList != null) {
        _favoriteIds.clear();
        _favoriteIds.addAll(favList);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> recordStickerUsage(StickerItem sticker) async {
    _recentStickers.removeWhere((s) => s.id == sticker.id);
    _recentStickers.insert(0, sticker);
    if (_recentStickers.length > 20) {
      _recentStickers.removeRange(20, _recentStickers.length);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _recentStickers.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_kRecentKey, list);
    } catch (_) {}
  }

  bool isFavorite(String stickerId) => _favoriteIds.contains(stickerId);

  Future<void> toggleFavorite(StickerItem sticker) async {
    if (_favoriteIds.contains(sticker.id)) {
      _favoriteIds.remove(sticker.id);
    } else {
      _favoriteIds.add(sticker.id);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kFavoriteKey, _favoriteIds);
    } catch (_) {}
  }

  StickerItem? findSticker(String idOrPath) {
    for (final s in kSampleCatStickers) {
      if (s.id == idOrPath ||
          s.assetPath == idOrPath ||
          idOrPath.contains(s.id) ||
          idOrPath.endsWith('${s.id}.png')) {
        return s;
      }
    }
    return null;
  }
}
