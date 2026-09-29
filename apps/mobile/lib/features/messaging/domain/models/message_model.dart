import 'dart:convert';

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
  location,
  sticker,
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
  final bool isDeleted;

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
    this.isDeleted = false,
  });

  bool get isRecalled => isDeleted || content == '__DELETED_FOR_EVERYONE__';

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
    bool? isDeleted,
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
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Clean, human-readable snippet for quotes, reply previews, and notifications
  String get displaySnippet {
    if (isRecalled) {
      return isOutgoing ? 'Anda menarik pesan ini' : 'Pesan ini telah ditarik';
    }
    if (contentType == MessageContentType.sticker ||
        content.startsWith('sticker:') ||
        (attachmentName != null && (attachmentName!.startsWith('cat_') || attachmentName!.contains('sticker')))) {
      return 'Stiker';
    }
    if (contentType == MessageContentType.voiceNote) {
      return attachmentSize != null && attachmentSize!.isNotEmpty
          ? 'Pesan Suara ($attachmentSize)'
          : 'Pesan Suara';
    }
    if (contentType == MessageContentType.location ||
        content.contains('"type":"location"') ||
        content.contains('"type": "location"')) {
      try {
        final parsed = jsonDecode(content);
        if (parsed is Map && parsed['name'] != null && (parsed['name'] as String).isNotEmpty) {
          return parsed['name'] as String;
        }
      } catch (_) {}
      return 'Lokasi';
    }
    if (contentType == MessageContentType.attachment) {
      if (attachmentName != null &&
          attachmentName!.isNotEmpty &&
          attachmentName != 'Foto.jpg' &&
          !attachmentName!.toLowerCase().endsWith('.jpg') &&
          !attachmentName!.toLowerCase().endsWith('.png')) {
        final clean = content.trim();
        if (clean.isNotEmpty &&
            !clean.startsWith('{') &&
            !clean.startsWith('data:') &&
            !clean.startsWith('Berkas Dokumen Asli')) {
          return clean;
        }
        return attachmentName!;
      }
      if (content.isNotEmpty && !content.startsWith('{') && !content.startsWith('data:')) {
        return content;
      }
      return 'Foto';
    }
    if (content.startsWith('{') && content.contains('"caption"')) {
      try {
        final parsed = jsonDecode(content);
        if (parsed is Map && parsed['caption'] != null && (parsed['caption'] as String).isNotEmpty) {
          return parsed['caption'] as String;
        }
      } catch (_) {}
    }
    if (content.startsWith('{') && content.contains('"text"')) {
      try {
        final parsed = jsonDecode(content);
        if (parsed is Map && parsed['text'] != null && (parsed['text'] as String).isNotEmpty) {
          return parsed['text'] as String;
        }
      } catch (_) {}
    }
    return content;
  }

  /// Deduplicates a list of messages, collapsing optimistic temporary IDs
  /// with confirmed server messages, and removing redundant duplicates.
  static List<MessageModel> deduplicate(List<MessageModel> list) {
    if (list.isEmpty) return [];

    final result = <MessageModel>[];
    final sorted = List<MessageModel>.from(list)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final inc in sorted) {
      final idx = result.indexWhere((m) {
        if (m.id == inc.id) return true;

        if (inc.clientMessageId != null && inc.clientMessageId!.isNotEmpty) {
          if (m.id == inc.clientMessageId || m.clientMessageId == inc.clientMessageId) {
            return true;
          }
        }
        if (m.clientMessageId != null && m.clientMessageId!.isNotEmpty) {
          if (inc.id == m.clientMessageId || inc.clientMessageId == m.clientMessageId) {
            return true;
          }
        }

        // Match outgoing messages with same content and timestamp within 15 seconds
        if (m.isOutgoing && inc.isOutgoing &&
            m.contentType == inc.contentType &&
            m.content.trim() == inc.content.trim() &&
            (m.timestamp.difference(inc.timestamp).abs().inSeconds < 15)) {
          return true;
        }

        return false;
      });

      if (idx != -1) {
        final existing = result[idx];
        final isExistingTemp = existing.id.startsWith('msg-') ||
            existing.id.startsWith('img-') ||
            existing.id.startsWith('doc-') ||
            existing.id.startsWith('aud-') ||
            existing.id.startsWith('voice-') ||
            existing.id.startsWith('loc-') ||
            existing.id.startsWith('stk-');
        final isIncTemp = inc.id.startsWith('msg-') ||
            inc.id.startsWith('img-') ||
            inc.id.startsWith('doc-') ||
            inc.id.startsWith('aud-') ||
            inc.id.startsWith('voice-') ||
            inc.id.startsWith('loc-') ||
            inc.id.startsWith('stk-');

        if (isExistingTemp && !isIncTemp) {
          result[idx] = inc.copyWith(
            clientMessageId: inc.clientMessageId ?? existing.clientMessageId ?? existing.id,
            attachmentPath: existing.attachmentPath ?? inc.attachmentPath,
            attachmentName: existing.attachmentName ?? inc.attachmentName,
            attachmentSize: existing.attachmentSize ?? inc.attachmentSize,
            replyTo: existing.replyTo ?? inc.replyTo,
          );
        } else {
          result[idx] = existing.copyWith(
            clientMessageId: existing.clientMessageId ?? inc.clientMessageId,
            status: inc.status != MessageDeliveryStatus.sending ? inc.status : existing.status,
            reactions: inc.reactions.isNotEmpty ? inc.reactions : existing.reactions,
            attachmentPath: existing.attachmentPath ?? inc.attachmentPath,
            attachmentName: existing.attachmentName ?? inc.attachmentName,
            attachmentSize: existing.attachmentSize ?? inc.attachmentSize,
            replyTo: existing.replyTo ?? inc.replyTo,
          );
        }
      } else {
        result.add(inc);
      }
    }

    return result;
  }
}

