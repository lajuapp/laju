class StickerItem {
  final String id;
  final String name;
  final String assetPath;
  final String packId;
  final String emoji;

  const StickerItem({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.packId,
    this.emoji = '🐱',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetPath': assetPath,
        'packId': packId,
        'emoji': emoji,
      };

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        assetPath: json['assetPath'] as String? ?? '',
        packId: json['packId'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🐱',
      );
}

class StickerPack {
  final String id;
  final String name;
  final String iconEmoji;
  final List<StickerItem> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.iconEmoji,
    required this.stickers,
  });
}
