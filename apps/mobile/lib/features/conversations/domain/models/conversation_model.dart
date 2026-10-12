enum ConversationCategory {
  personal,
  group,
}

class ConversationModel {
  final String id;
  final String title;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final bool isOnline;
  final bool isKeyVerified;
  final bool hasDisappearingMessages;
  final int? disappearingSeconds;
  final String safetyNumberPreview;
  final bool isPinned;
  final bool isLocked;
  final bool isArchived;
  final bool isMuted;
  final String? participantUserId;
  final String? participantPhone;
  final String? participantAbout;
  final int? participantTrustScore;
  final bool isOutgoingLatest;

  const ConversationModel({
    required this.id,
    required this.title,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isGroup = false,
    this.isOnline = false,
    this.isKeyVerified = true,
    this.hasDisappearingMessages = false,
    this.disappearingSeconds,
    this.safetyNumberPreview = '4812 ••• 9901',
    this.isPinned = false,
    this.isLocked = false,
    this.isArchived = false,
    this.isMuted = false,
    this.participantUserId,
    this.participantPhone,
    this.participantAbout,
    this.participantTrustScore,
    this.isOutgoingLatest = false,
  });

  ConversationModel copyWith({
    String? id,
    String? title,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isGroup,
    bool? isOnline,
    bool? isKeyVerified,
    bool? hasDisappearingMessages,
    int? disappearingSeconds,
    String? safetyNumberPreview,
    bool? isPinned,
    bool? isLocked,
    bool? isArchived,
    bool? isMuted,
    String? participantUserId,
    String? participantPhone,
    String? participantAbout,
    int? participantTrustScore,
    bool? isOutgoingLatest,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      isOnline: isOnline ?? this.isOnline,
      isKeyVerified: isKeyVerified ?? this.isKeyVerified,
      hasDisappearingMessages: hasDisappearingMessages ?? this.hasDisappearingMessages,
      disappearingSeconds: disappearingSeconds ?? this.disappearingSeconds,
      safetyNumberPreview: safetyNumberPreview ?? this.safetyNumberPreview,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      participantUserId: participantUserId ?? this.participantUserId,
      participantPhone: participantPhone ?? this.participantPhone,
      participantAbout: participantAbout ?? this.participantAbout,
      participantTrustScore: participantTrustScore ?? this.participantTrustScore,
      isOutgoingLatest: isOutgoingLatest ?? this.isOutgoingLatest,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationModel &&
        other.id == id &&
        other.title == title &&
        other.avatarUrl == avatarUrl &&
        other.lastMessage == lastMessage &&
        other.lastMessageTime.millisecondsSinceEpoch == lastMessageTime.millisecondsSinceEpoch &&
        other.unreadCount == unreadCount &&
        other.isPinned == isPinned &&
        other.isMuted == isMuted &&
        other.isOnline == isOnline &&
        other.isLocked == isLocked &&
        other.isArchived == isArchived;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      avatarUrl,
      lastMessage,
      lastMessageTime.millisecondsSinceEpoch,
      unreadCount,
      isPinned,
      isMuted,
      isOnline,
    );
  }

  static bool areListsEqual(List<ConversationModel>? a, List<ConversationModel>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

