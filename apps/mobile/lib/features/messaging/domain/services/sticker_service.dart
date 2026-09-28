import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/sticker_model.dart';

class StickerService extends ChangeNotifier {
  StickerService._();
  static final StickerService instance = StickerService._();

  static const String _kRecentKey = 'laju_recent_stickers';
  static const String _kFavoriteKey = 'laju_favorite_stickers';
  static const String _kRemotePacksKey = 'laju_remote_stickers_cache';

  final List<StickerItem> _recentStickers = [];
  final List<String> _favoriteIds = [];
  final List<StickerPack> _remotePacks = [];
  bool _isLoadingRemote = false;

  List<StickerItem> get recentStickers => List.unmodifiable(_recentStickers);
  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);
  List<StickerPack> get remotePacks => List.unmodifiable(_remotePacks);
  bool get isLoadingRemote => _isLoadingRemote;

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
    return List.unmodifiable(_remotePacks);
  }

  /// Find a sticker by ID, name, or asset/image URL
  StickerItem? findSticker(String idOrPath) {
    if (idOrPath.trim().isEmpty) return null;
    for (final pack in getAllPacks()) {
      for (final s in pack.stickers) {
        if (s.id == idOrPath ||
            s.name == idOrPath ||
            s.assetPath == idOrPath ||
            s.effectivePathOrUrl == idOrPath ||
            idOrPath.contains(s.id) ||
            idOrPath.endsWith('${s.id}.png')) {
          return s;
        }
      }
    }
    for (final s in _recentStickers) {
      if (s.id == idOrPath ||
          s.name == idOrPath ||
          s.assetPath == idOrPath ||
          s.effectivePathOrUrl == idOrPath ||
          idOrPath.contains(s.id) ||
          idOrPath.endsWith('${s.id}.png')) {
        return s;
      }
    }
    return null;
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

      // Load cached remote sticker packs
      final cachedPacksJson = prefs.getStringList(_kRemotePacksKey);
      if (cachedPacksJson != null && cachedPacksJson.isNotEmpty) {
        _remotePacks.clear();
        for (final item in cachedPacksJson) {
          try {
            _remotePacks.add(StickerPack.fromJson(jsonDecode(item) as Map<String, dynamic>));
          } catch (_) {}
        }
      }

      if (_remotePacks.isNotEmpty) {
        scheduleMicrotask(() {
          notifyListeners();
        });
      }

      // Refresh in background
      fetchRemoteStickers();
    } catch (_) {}
  }

  /// Fetches published sticker packs from Backoffice
  Future<void> fetchRemoteStickers() async {
    _isLoadingRemote = true;
    scheduleMicrotask(() {
      notifyListeners();
    });

    try {
      final response = await ApiClient.instance.get(ApiEndpoints.publicStickers);
      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final parsed = <StickerPack>[];

        for (final item in list) {
          if (item is Map) {
            final packId = item['id'] as String? ?? '';
            final packName = item['name'] as String? ?? 'Sticker Pack';
            final cover = item['coverUrl'] as String?;
            final pub = item['publisher'] as String?;
            final desc = item['description'] as String?;
            final stickersList = item['stickers'] as List? ?? [];
            final stickers = <StickerItem>[];

            for (final s in stickersList) {
              if (s is Map) {
                final sId = s['id'] as String? ?? '';
                final sName = s['name'] as String? ?? 'Stiker';
                final sImg = s['imageUrl'] as String? ?? '';
                final sEmoji = s['emoji'] as String? ?? '✨';

                stickers.add(StickerItem(
                  id: sId,
                  name: sName,
                  assetPath: sImg,
                  imageUrl: sImg,
                  packId: packId,
                  emoji: sEmoji,
                ));
              }
            }

            if (stickers.isNotEmpty) {
              parsed.add(StickerPack(
                id: packId,
                name: packName,
                iconEmoji: '✨',
                coverUrl: cover,
                publisher: pub,
                description: desc,
                stickers: stickers,
              ));
            }
          }
        }

        _remotePacks.clear();
        _remotePacks.addAll(parsed);
        notifyListeners();

        // Persist cache
        final prefs = await SharedPreferences.getInstance();
        final serialized = _remotePacks.map((p) => jsonEncode(p.toJson())).toList();
        await prefs.setStringList(_kRemotePacksKey, serialized);
      }
    } catch (_) {
      // Keep existing cached packs on network failure
    } finally {
      _isLoadingRemote = false;
      notifyListeners();
    }
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
}
