import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

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

  static const String _kRemoteWallpapersKey = 'laju_remote_wallpapers_cache';
  static const String _kChatWallpapersPrefix = 'laju_chat_wallpaper_';

  // Selected wallpaper index or ID
  String _selectedWallpaper = 'none';
  LajuFontSize _fontSize = LajuFontSize.medium;

  final Map<String, String> _chatWallpapers = {};
  List<WallpaperOption> _remoteWallpapers = [];
  bool _isLoadingRemote = false;

  String get selectedWallpaper => _selectedWallpaper;
  LajuFontSize get fontSize => _fontSize;
  double get fontScale => _fontSize.scale;

  List<WallpaperOption> get remoteWallpapers => List.unmodifiable(_remoteWallpapers);
  List<WallpaperOption> get allWallpapers => _remoteWallpapers.isNotEmpty ? _remoteWallpapers : kDefaultOnlineWallpapers;
  bool get isLoadingRemote => _isLoadingRemote;

  /// Gets the wallpaper ID assigned to a specific chat/group.
  /// Returns null or 'none' if using the default (no wallpaper / clean canvas).
  String? getChatWallpaper(String chatId) {
    return _chatWallpapers[chatId];
  }

  /// Sets or removes the wallpaper assigned to a specific chat/group.
  Future<void> setChatWallpaper(String chatId, String? wallpaperId) async {
    if (wallpaperId == null || wallpaperId == 'none' || wallpaperId.isEmpty) {
      _chatWallpapers.remove(chatId);
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_kChatWallpapersPrefix$chatId');
      } catch (_) {}
    } else {
      _chatWallpapers[chatId] = wallpaperId;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_kChatWallpapersPrefix$chatId', wallpaperId);
      } catch (_) {}
    }
  }

  /// Synchronize wallpaper received from a chat participant or backend event
  Future<void> syncRemoteChatWallpaper(String chatId, String? wallpaperId) async {
    final effectiveId = (wallpaperId == null || wallpaperId == 'none' || wallpaperId.isEmpty) ? null : wallpaperId;
    if (_chatWallpapers[chatId] == effectiveId) return;

    if (effectiveId == null) {
      _chatWallpapers.remove(chatId);
    } else {
      _chatWallpapers[chatId] = effectiveId;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (effectiveId == null) {
        await prefs.remove('$_kChatWallpapersPrefix$chatId');
      } else {
        await prefs.setString('$_kChatWallpapersPrefix$chatId', effectiveId);
      }
    } catch (_) {}
  }

  /// Look up a WallpaperOption by ID across available wallpapers
  WallpaperOption? findWallpaper(String? id) {
    if (id == null || id.isEmpty || id == 'none') return null;
    try {
      return allWallpapers.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Load saved appearance settings from SharedPreferences on app start
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedWallpaper = prefs.getString('laju_wallpaper') ?? 'none';
      final savedFont = prefs.getString('laju_font_size') ?? 'medium';
      _fontSize = LajuFontSize.values.firstWhere(
        (f) => f.name == savedFont,
        orElse: () => LajuFontSize.medium,
      );

      // Load per-chat wallpaper settings
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_kChatWallpapersPrefix)) {
          final chatId = key.substring(_kChatWallpapersPrefix.length);
          final wpId = prefs.getString(key);
          if (chatId.isNotEmpty && wpId != null && wpId.isNotEmpty) {
            _chatWallpapers[chatId] = wpId;
          }
        }
      }

      // Load cached remote wallpapers
      final cachedList = prefs.getStringList(_kRemoteWallpapersKey);
      if (cachedList != null && cachedList.isNotEmpty) {
        _remoteWallpapers = cachedList.map((item) {
          try {
            return WallpaperOption.fromJson(jsonDecode(item) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        }).whereType<WallpaperOption>().toList();
      }

      if (_selectedWallpaper.isEmpty || _selectedWallpaper == 'default') {
        _selectedWallpaper = 'none';
      }

      if (_remoteWallpapers.isNotEmpty) {
        scheduleMicrotask(() {
          notifyListeners();
        });
      }

      // Refresh from server in background
      fetchRemoteWallpapers();
    } catch (_) {}
  }

  /// Fetches latest active wallpapers uploaded from Backoffice
  Future<void> fetchRemoteWallpapers() async {
    _isLoadingRemote = true;
    scheduleMicrotask(() {
      notifyListeners();
    });

    try {
      final response = await ApiClient.instance.get(ApiEndpoints.publicWallpapers);
      if (response.isSuccess && response.rawJson is List) {
        final list = response.rawJson as List;
        final parsed = <WallpaperOption>[];

        for (final item in list) {
          if (item is Map) {
            final id = item['id'] as String? ?? '';
            final name = item['name'] as String? ?? 'Wallpaper';
            final cat = item['category'] as String? ?? 'IMAGE';
            final colorHex = item['colorHex'] as String?;
            final imageUrl = item['imageUrl'] as String?;
            final isDef = item['isDefault'] as bool? ?? false;

            Color bgColor = const Color(0xFF0F172A);
            if (colorHex != null && colorHex.isNotEmpty) {
              final hex = colorHex.replaceAll('#', '').trim();
              if (hex.length == 6) {
                bgColor = Color(int.parse('FF$hex', radix: 16));
              } else if (hex.length == 8) {
                bgColor = Color(int.parse(hex, radix: 16));
              }
            }

            parsed.add(WallpaperOption(
              id: id,
              nameEn: name,
              nameId: name,
              backgroundColor: bgColor,
              remoteImageUrl: imageUrl,
              category: cat,
              isDefault: isDef,
            ));
          }
        }

        _remoteWallpapers = parsed;
        notifyListeners();

        // Persist cache
        final prefs = await SharedPreferences.getInstance();
        final cacheList = _remoteWallpapers.map((w) => jsonEncode(w.toJson())).toList();
        await prefs.setStringList(_kRemoteWallpapersKey, cacheList);
      }
    } catch (_) {
      // Keep existing cached or preset wallpapers on network failure
    } finally {
      _isLoadingRemote = false;
      notifyListeners();
    }
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
  final String? remoteImageUrl;
  final String? category;
  final bool isDefault;
  final bool isRemote;
  final bool hasDoodlePattern;

  const WallpaperOption({
    required this.id,
    required this.nameEn,
    required this.nameId,
    required this.backgroundColor,
    this.secondaryColor,
    this.lightAsset,
    this.darkAsset,
    this.remoteImageUrl,
    this.category,
    this.isDefault = false,
    this.isRemote = true,
    this.hasDoodlePattern = false,
  });

  bool get hasRemoteImage => remoteImageUrl != null && remoteImageUrl!.trim().isNotEmpty;

  String getName(String langCode) => langCode == 'id' ? nameId : nameEn;

  /// Returns the asset path if this option uses a custom local image background
  String? getAssetPath(bool isDark) {
    if (isRemote) return null;
    if (isDark) {
      return darkAsset ?? lightAsset;
    } else {
      return lightAsset ?? darkAsset;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameId': nameId,
    'backgroundColor': backgroundColor.toARGB32(),
    'secondaryColor': secondaryColor?.toARGB32(),
    'lightAsset': lightAsset,
    'darkAsset': darkAsset,
    'remoteImageUrl': remoteImageUrl,
    'category': category,
    'isDefault': isDefault,
    'isRemote': isRemote,
    'hasDoodlePattern': hasDoodlePattern,
  };

  factory WallpaperOption.fromJson(Map<String, dynamic> json) => WallpaperOption(
    id: json['id'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? 'Wallpaper',
    nameId: json['nameId'] as String? ?? 'Wallpaper',
    backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFF0F172A),
    secondaryColor: json['secondaryColor'] != null ? Color(json['secondaryColor'] as int) : null,
    lightAsset: json['lightAsset'] as String?,
    darkAsset: json['darkAsset'] as String?,
    remoteImageUrl: json['remoteImageUrl'] as String?,
    category: json['category'] as String?,
    isDefault: json['isDefault'] as bool? ?? false,
    isRemote: json['isRemote'] as bool? ?? true,
    hasDoodlePattern: json['hasDoodlePattern'] as bool? ?? false,
  );
}

final List<WallpaperOption> kDefaultOnlineWallpapers = [
  const WallpaperOption(
    id: '9bbfdf85-1d78-4fcb-98f3-c336a0edeec4',
    nameEn: 'Default Minimalist',
    nameId: 'Default Minimalis',
    backgroundColor: Color(0xFF0F172A),
    category: 'SOLID',
    isDefault: true,
    isRemote: true,
  ),
  const WallpaperOption(
    id: '9cc97784-c849-470c-97ce-acb6f88a01f1',
    nameEn: 'Warm Amber Sand',
    nameId: 'Warm Amber Sand',
    backgroundColor: Color(0xFF78350F),
    category: 'SOLID',
    isDefault: false,
    isRemote: true,
  ),
  const WallpaperOption(
    id: '06abfcf3-ca9e-49d7-a0a8-15518b2a8f5c',
    nameEn: 'Emerald Forest',
    nameId: 'Emerald Forest',
    backgroundColor: Color(0xFF064E3B),
    category: 'SOLID',
    isDefault: false,
    isRemote: true,
  ),
  const WallpaperOption(
    id: '9401def0-f1eb-4ca3-8e6f-f2b998d2cb9e',
    nameEn: 'Deep Midnight Slate',
    nameId: 'Deep Midnight Slate',
    backgroundColor: Color(0xFF1E1B4B),
    category: 'GRADIENT',
    isDefault: false,
    isRemote: true,
  ),
];
