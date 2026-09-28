class StickerItem {
  final String id;
  final String name;
  final String assetPath;
  final String? imageUrl;
  final String packId;
  final String emoji;

  const StickerItem({
    required this.id,
    required this.name,
    required this.assetPath,
    this.imageUrl,
    required this.packId,
    this.emoji = '🐱',
  });

  bool get isRemote =>
      assetPath.startsWith('http://') ||
      assetPath.startsWith('https://') ||
      assetPath.startsWith('/') ||
      (imageUrl != null && imageUrl!.trim().isNotEmpty);

  String get effectivePathOrUrl =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty) ? imageUrl! : assetPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetPath': assetPath,
        'imageUrl': imageUrl,
        'packId': packId,
        'emoji': emoji,
      };

  factory StickerItem.fromJson(Map<String, dynamic> json) {
    final img = json['imageUrl'] as String?;
    final asset = json['assetPath'] as String? ?? img ?? '';
    return StickerItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetPath: asset,
      imageUrl: img,
      packId: json['packId'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🐱',
    );
  }
}

class StickerPack {
  final String id;
  final String name;
  final String iconEmoji;
  final String? coverUrl;
  final String? publisher;
  final String? description;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.iconEmoji,
    this.coverUrl,
    this.publisher,
    this.description,
    required this.stickers,
  });

  String? get thumbnailPathOrUrl {
    if (coverUrl != null && coverUrl!.trim().isNotEmpty) {
      return coverUrl!;
    }
    if (stickers.isNotEmpty) {
      return stickers.first.effectivePathOrUrl;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconEmoji': iconEmoji,
        'coverUrl': coverUrl,
        'publisher': publisher,
        'description': description,
        'stickers': stickers.map((s) => s.toJson()).toList(),
      };

  factory StickerPack.fromJson(Map<String, dynamic> json) => StickerPack(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        iconEmoji: json['iconEmoji'] as String? ?? '🐱',
        coverUrl: json['coverUrl'] as String?,
        publisher: json['publisher'] as String?,
        description: json['description'] as String?,
        stickers: (json['stickers'] as List? ?? [])
            .map((s) => StickerItem.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
