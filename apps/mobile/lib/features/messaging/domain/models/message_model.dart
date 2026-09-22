enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum MessageContentType {
  text,
  attachment,
  voiceNote,
  systemNotice,
}

class MessageModel {
  final String id;
  final String? clientMessageId;
  final String conversationId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;
  final MessageDeliveryStatus status;
  final MessageContentType contentType;
  final bool isDisappearing;
  final int? remainingSeconds;
  final String? attachmentName;
  final String? attachmentSize;
  final String? attachmentPath;

  final MessageModel? replyTo;
  final List<String> reactions;
  final bool isEdited;

  const MessageModel({
    required this.id,
    this.clientMessageId,
    required this.conversationId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isOutgoing,
    this.status = MessageDeliveryStatus.sent,
    this.contentType = MessageContentType.text,
    this.isDisappearing = false,
    this.remainingSeconds,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentPath,
    this.replyTo,
    this.reactions = const [],
    this.isEdited = false,
  });

  MessageModel copyWith({
    String? id,
    String? clientMessageId,
    String? conversationId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isOutgoing,
    MessageDeliveryStatus? status,
    MessageContentType? contentType,
    bool? isDisappearing,
    int? remainingSeconds,
    String? attachmentName,
    String? attachmentSize,
    String? attachmentPath,
    MessageModel? replyTo,
    List<String>? reactions,
    bool? isEdited,
  }) {
    return MessageModel(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
      contentType: contentType ?? this.contentType,
      isDisappearing: isDisappearing ?? this.isDisappearing,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      replyTo: replyTo ?? this.replyTo,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}
