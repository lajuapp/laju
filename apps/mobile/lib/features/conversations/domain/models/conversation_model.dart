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
    );
  }
}
