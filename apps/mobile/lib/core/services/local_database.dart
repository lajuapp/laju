import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/conversations/domain/models/conversation_model.dart';
import '../../features/messaging/domain/models/message_model.dart';

/// SQLite-backed local cache for conversations and messages.
/// Follows the singleton pattern; call [init()] once in main() before runApp().
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  static const int _version = 1;
  static const String _dbName = 'laju_cache.db';

  // Max messages to keep per conversation (oldest evicted automatically)
  static const int _maxMessagesPerConv = 100;

  // ── Schema ────────────────────────────────────────────────────────────────

  static const String _createConversations = '''
    CREATE TABLE IF NOT EXISTS conversations (
      id                    TEXT PRIMARY KEY,
      title                 TEXT NOT NULL,
      avatar_url            TEXT,
      last_message          TEXT NOT NULL DEFAULT '',
      last_message_time     INTEGER NOT NULL DEFAULT 0,
      unread_count          INTEGER NOT NULL DEFAULT 0,
      is_group              INTEGER NOT NULL DEFAULT 0,
      is_online             INTEGER NOT NULL DEFAULT 0,
      is_key_verified       INTEGER NOT NULL DEFAULT 1,
      is_pinned             INTEGER NOT NULL DEFAULT 0,
      is_locked             INTEGER NOT NULL DEFAULT 0,
      is_archived           INTEGER NOT NULL DEFAULT 0,
      is_muted              INTEGER NOT NULL DEFAULT 0,
      safety_number_preview TEXT NOT NULL DEFAULT '4812 ••• 9901',
      has_disappearing      INTEGER NOT NULL DEFAULT 0,
      disappearing_seconds  INTEGER,
      participant_user_id   TEXT,
      participant_phone     TEXT,
      participant_about     TEXT,
      participant_trust_score INTEGER,
      cached_at             INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createMessages = '''
    CREATE TABLE IF NOT EXISTS messages (
      id               TEXT PRIMARY KEY,
      client_message_id TEXT,
      conversation_id  TEXT NOT NULL,
      sender_name      TEXT NOT NULL DEFAULT '',
      content          TEXT NOT NULL DEFAULT '',
      timestamp        INTEGER NOT NULL DEFAULT 0,
      is_outgoing      INTEGER NOT NULL DEFAULT 0,
      status           TEXT NOT NULL DEFAULT 'sent',
      content_type     TEXT NOT NULL DEFAULT 'text',
      is_disappearing  INTEGER NOT NULL DEFAULT 0,
      remaining_seconds INTEGER,
      attachment_name  TEXT,
      attachment_size  TEXT,
      attachment_path  TEXT,
      reply_to_json    TEXT,
      is_edited        INTEGER NOT NULL DEFAULT 0,
      is_deleted       INTEGER NOT NULL DEFAULT 0,
      cached_at        INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createCallLogs = '''
    CREATE TABLE IF NOT EXISTS call_logs (
      id                TEXT PRIMARY KEY,
      contact_name      TEXT NOT NULL,
      contact_id        TEXT,
      contact_phone     TEXT,
      avatar_url        TEXT,
      is_video          INTEGER NOT NULL DEFAULT 0,
      is_outgoing       INTEGER NOT NULL DEFAULT 1,
      status            TEXT NOT NULL DEFAULT 'completed',
      duration_seconds  INTEGER NOT NULL DEFAULT 0,
      timestamp         INTEGER NOT NULL
    )
  ''';

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute(_createConversations);
        await db.execute(_createMessages);
        await db.execute(_createCallLogs);
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_client ON messages(client_message_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_calls_ts ON call_logs(timestamp)');
      },
      onOpen: (db) async {
        try {
          await db.execute(_createCallLogs);
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE call_logs ADD COLUMN avatar_url TEXT');
        } catch (_) {}
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_calls_ts ON call_logs(timestamp)');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN client_message_id TEXT');
        } catch (_) {}
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_client ON messages(client_message_id)');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN reply_to_json TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN avatar_url TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN participant_user_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN participant_phone TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN participant_about TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN participant_trust_score INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('CREATE TABLE IF NOT EXISTS deleted_for_me_messages (id TEXT PRIMARY KEY)');
        } catch (_) {}

        // Fix existing corrupted oversized rows from prior sessions that break SQLite CursorWindow (2MB limit)
        try {
          await db.execute('UPDATE conversations SET last_message = SUBSTR(last_message, 1, 300) WHERE LENGTH(last_message) > 500');
        } catch (_) {}
        try {
          await db.execute('UPDATE conversations SET avatar_url = NULL WHERE avatar_url IS NOT NULL AND LENGTH(avatar_url) > 2000');
        } catch (_) {}
        try {
          await db.execute('UPDATE messages SET reply_to_json = NULL WHERE reply_to_json IS NOT NULL AND LENGTH(reply_to_json) > 5000');
        } catch (_) {}
        try {
          await db.execute('UPDATE messages SET content = SUBSTR(content, 1, 1000) WHERE LENGTH(content) > 20000');
        } catch (_) {}
      },
    );
  }

  Database get _database {
    if (_db == null) throw StateError('LocalDatabase not initialized. Call init() first.');
    return _db!;
  }

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Returns all cached conversations ordered by last message time descending.
  Future<List<ConversationModel>> getConversations() async {
    try {
      final rows = await _database.query(
        'conversations',
        orderBy: 'last_message_time DESC',
      );
      return rows.map(_rowToConversation).toList();
    } catch (e) {
      debugPrint('[LocalDatabase] getConversations error: $e');
      try {
        await _database.execute('UPDATE conversations SET last_message = SUBSTR(last_message, 1, 300) WHERE LENGTH(last_message) > 500');
        await _database.execute('UPDATE conversations SET avatar_url = NULL WHERE avatar_url IS NOT NULL AND LENGTH(avatar_url) > 2000');
        final rows = await _database.query('conversations', orderBy: 'last_message_time DESC');
        return rows.map(_rowToConversation).toList();
      } catch (_) {
        try {
          await _database.delete('conversations');
        } catch (_) {}
        return [];
      }
    }
  }

  /// Returns a single cached conversation by ID, or null if not found.
  Future<ConversationModel?> getConversation(String id) async {
    try {
      final rows = await _database.query(
        'conversations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return _rowToConversation(rows.first);
      }
    } catch (e) {
      debugPrint('[LocalDatabase] getConversation error: $e');
    }
    return null;
  }

  /// Insert or replace a list of conversations in cache.
  Future<void> upsertConversations(List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _database.batch();
    for (final c in conversations) {
      batch.insert(
        'conversations',
        _conversationToRow(c, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Delete a single conversation and its messages.
  Future<void> deleteConversation(String id) async {
    await _database.delete('conversations', where: 'id = ?', whereArgs: [id]);
    await _database.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Returns cached messages for a conversation, ordered by timestamp ascending.
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final deletedForMe = await getDeletedForMeIds();
      final rows = await _database.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'timestamp ASC',
      );
      final rawList = rows
          .where((r) => !deletedForMe.contains(r['id'] as String))
          .map(_rowToMessage)
          .toList();
      return MessageModel.deduplicate(rawList);
    } catch (_) {
      return [];
    }
  }

  /// Insert or replace a list of messages. Evicts oldest if over [_maxMessagesPerConv].
  Future<void> upsertMessages(String conversationId, List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    final deduplicated = MessageModel.deduplicate(messages);
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _database.batch();
    for (final m in deduplicated) {
      if (m.clientMessageId != null && m.clientMessageId!.isNotEmpty) {
        batch.delete(
          'messages',
          where: '(id = ? OR client_message_id = ?) AND id != ?',
          whereArgs: [m.clientMessageId, m.clientMessageId, m.id],
        );
      }
      batch.insert(
        'messages',
        _messageToRow(m, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _evictOldMessages(conversationId);
  }

  /// Save a single outgoing message immediately (before API call).
  Future<void> insertSentMessage(MessageModel message) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.insert(
      'messages',
      _messageToRow(message, now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atomically replace an optimistic message with the server-confirmed message
  Future<void> replaceOptimisticMessage(String clientMessageId, MessageModel serverMessage) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database.delete(
        'messages',
        where: 'id = ? OR client_message_id = ?',
        whereArgs: [clientMessageId, clientMessageId],
      );
      await _database.insert(
        'messages',
        _messageToRow(serverMessage.copyWith(clientMessageId: clientMessageId), now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDatabase] replaceOptimisticMessage error: $e');
    }
  }

  /// Update the delivery status of a specific message.
  Future<void> updateMessageStatus(String messageId, MessageDeliveryStatus status) async {
    await _database.update(
      'messages',
      {'status': status.name},
      where: 'id = ? OR client_message_id = ?',
      whereArgs: [messageId, messageId],
    );
  }

  /// Delete a single message from local cache.
  Future<void> deleteMessage(String messageId) async {
    await _database.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Mark a message as recalled/deleted for everyone.
  Future<void> markMessageDeleted(String messageId) async {
    try {
      await _database.update(
        'messages',
        {
          'is_deleted': 1,
          'content': '__DELETED_FOR_EVERYONE__',
          'attachment_name': null,
          'attachment_size': null,
          'attachment_path': null,
        },
        where: 'id = ? OR client_message_id = ?',
        whereArgs: [messageId, messageId],
      );
    } catch (e) {
      debugPrint('[LocalDatabase] markMessageDeleted error: $e');
    }
  }

  /// Delete a message for current user only and track its ID so it does not reappear on sync.
  Future<void> deleteMessageForMe(String messageId) async {
    try {
      await _database.delete(
        'messages',
        where: 'id = ? OR client_message_id = ?',
        whereArgs: [messageId, messageId],
      );
      await _database.insert(
        'deleted_for_me_messages',
        {'id': messageId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDatabase] deleteMessageForMe error: $e');
    }
  }

  /// Returns set of message IDs deleted by user on this device.
  Future<Set<String>> getDeletedForMeIds() async {
    try {
      final rows = await _database.query('deleted_for_me_messages');
      return rows.map((r) => r['id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Clear all messages for a specific conversation from local cache.
  Future<void> clearMessages(String conversationId) async {
    await _database.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Update content of an edited message in local cache.
  Future<void> updateMessageContent(String messageId, String newContent) async {
    await _database.update(
      'messages',
      {'content': newContent, 'is_edited': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Delete all cached data. Call on logout.
  Future<void> clearAll() async {
    try {
      await _database.delete('messages');
      await _database.delete('conversations');
    } catch (_) {}
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _evictOldMessages(String conversationId) async {
    final count = Sqflite.firstIntValue(await _database.rawQuery(
      'SELECT COUNT(*) FROM messages WHERE conversation_id = ?',
      [conversationId],
    )) ?? 0;

    if (count > _maxMessagesPerConv) {
      final excess = count - _maxMessagesPerConv;
      await _database.rawDelete('''
        DELETE FROM messages
        WHERE id IN (
          SELECT id FROM messages
          WHERE conversation_id = ?
          ORDER BY timestamp ASC
          LIMIT ?
        )
      ''', [conversationId, excess]);
    }
  }

  Map<String, dynamic> _conversationToRow(ConversationModel c, int cachedAt) {
    final safeLastMsg = c.lastMessage.length > 300 ? c.lastMessage.substring(0, 300) : c.lastMessage;
    final safeAvatarUrl = (c.avatarUrl != null && c.avatarUrl!.length > 2000) ? null : c.avatarUrl;
    final safeAbout = (c.participantAbout != null && c.participantAbout!.length > 500)
        ? c.participantAbout!.substring(0, 500)
        : c.participantAbout;

    return {
      'id': c.id,
      'title': c.title.length > 100 ? c.title.substring(0, 100) : c.title,
      'avatar_url': safeAvatarUrl,
      'last_message': safeLastMsg,
      'last_message_time': c.lastMessageTime.millisecondsSinceEpoch,
      'unread_count': c.unreadCount,
      'is_group': c.isGroup ? 1 : 0,
      'is_online': c.isOnline ? 1 : 0,
      'is_key_verified': c.isKeyVerified ? 1 : 0,
      'is_pinned': c.isPinned ? 1 : 0,
      'is_locked': c.isLocked ? 1 : 0,
      'is_archived': c.isArchived ? 1 : 0,
      'is_muted': c.isMuted ? 1 : 0,
      'safety_number_preview': c.safetyNumberPreview,
      'has_disappearing': c.hasDisappearingMessages ? 1 : 0,
      'disappearing_seconds': c.disappearingSeconds,
      'participant_user_id': c.participantUserId,
      'participant_phone': c.participantPhone,
      'participant_about': safeAbout,
      'participant_trust_score': c.participantTrustScore,
      'cached_at': cachedAt,
    };
  }

  ConversationModel _rowToConversation(Map<String, dynamic> row) {
    return ConversationModel(
      id: row['id'] as String,
      title: row['title'] as String,
      avatarUrl: row['avatar_url'] as String?,
      lastMessage: row['last_message'] as String,
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(row['last_message_time'] as int),
      unreadCount: row['unread_count'] as int,
      isGroup: (row['is_group'] as int) == 1,
      isOnline: (row['is_online'] as int) == 1,
      isKeyVerified: (row['is_key_verified'] as int) == 1,
      isPinned: (row['is_pinned'] as int) == 1,
      isLocked: (row['is_locked'] as int) == 1,
      isArchived: (row['is_archived'] as int) == 1,
      isMuted: (row['is_muted'] as int) == 1,
      safetyNumberPreview: row['safety_number_preview'] as String,
      hasDisappearingMessages: (row['has_disappearing'] as int) == 1,
      disappearingSeconds: row['disappearing_seconds'] as int?,
      participantUserId: row['participant_user_id'] as String?,
      participantPhone: row['participant_phone'] as String?,
      participantAbout: row['participant_about'] as String?,
      participantTrustScore: row['participant_trust_score'] as int?,
    );
  }

  Map<String, dynamic> _messageToRow(MessageModel m, int cachedAt) {
    String? replyToJson;
    if (m.replyTo != null) {
      try {
        final safeReplyContent = m.replyTo!.content.length > 300
            ? m.replyTo!.content.substring(0, 300)
            : m.replyTo!.content;
        replyToJson = jsonEncode({
          'id': m.replyTo!.id,
          'sender_name': m.replyTo!.senderName,
          'content': safeReplyContent,
          'content_type': m.replyTo!.contentType.name,
          'attachment_name': m.replyTo!.attachmentName,
          'attachment_size': m.replyTo!.attachmentSize,
          'attachment_path': m.replyTo!.attachmentPath,
        });
      } catch (_) {}
    }

    final safeContent = m.content.length > 20000 ? m.content.substring(0, 20000) : m.content;

    return {
      'id': m.id,
      'client_message_id': m.clientMessageId,
      'conversation_id': m.conversationId,
      'sender_name': m.senderName,
      'content': safeContent,
      'timestamp': m.timestamp.millisecondsSinceEpoch,
      'is_outgoing': m.isOutgoing ? 1 : 0,
      'status': m.status.name,
      'content_type': m.contentType.name,
      'is_disappearing': m.isDisappearing ? 1 : 0,
      'remaining_seconds': m.remainingSeconds,
      'attachment_name': m.attachmentName,
      'attachment_size': m.attachmentSize,
      'attachment_path': m.attachmentPath,
      'reply_to_json': replyToJson,
      'is_edited': m.isEdited ? 1 : 0,
      'is_deleted': m.isRecalled ? 1 : 0,
      'cached_at': cachedAt,
    };
  }

  MessageModel _rowToMessage(Map<String, dynamic> row) {
    MessageModel? replyTo;
    final rRaw = row['reply_to_json'] as String?;
    if (rRaw != null && rRaw.isNotEmpty) {
      try {
        final rMap = jsonDecode(rRaw);
        if (rMap is Map) {
          replyTo = MessageModel(
            id: rMap['id'] as String? ?? '',
            conversationId: row['conversation_id'] as String,
            senderName: rMap['sender_name'] as String? ?? 'Contact',
            content: rMap['content'] as String? ?? '',
            attachmentName: rMap['attachment_name'] as String?,
            attachmentSize: rMap['attachment_size'] as String?,
            attachmentPath: rMap['attachment_path'] as String?,
            contentType: MessageContentType.values.firstWhere(
              (t) => t.name == rMap['content_type'],
              orElse: () => MessageContentType.text,
            ),
            timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
            isOutgoing: false,
          );
        }
      } catch (_) {}
    }

    final isDeleted = (row['is_deleted'] as int? ?? 0) == 1 || (row['content'] ?? '') == '__DELETED_FOR_EVERYONE__';
    String content = isDeleted ? '__DELETED_FOR_EVERYONE__' : (row['content'] ?? '') as String;
    String? attName = isDeleted ? null : row['attachment_name'] as String?;
    String? attSize = isDeleted ? null : row['attachment_size'] as String?;
    String? attPath = isDeleted ? null : row['attachment_path'] as String?;

    if (!isDeleted && content.startsWith('{') && (content.contains('"media"') || content.contains('"type"'))) {
      try {
        final parsed = jsonDecode(content);
        if (parsed is Map) {
          content = (parsed['caption'] ?? '') as String;
          attName ??= parsed['fileName'] as String?;
          attSize ??= parsed['fileSize'] as String?;
          attPath ??= parsed['media'] as String?;
        }
      } catch (_) {
        content = '';
      }
    } else if (!isDeleted && (content.startsWith('data:') || content.startsWith('Berkas Dokumen Asli'))) {
      content = '';
    }

    return MessageModel(
      id: row['id'] as String,
      clientMessageId: row['client_message_id'] as String?,
      conversationId: row['conversation_id'] as String,
      senderName: row['sender_name'] as String,
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      isOutgoing: (row['is_outgoing'] as int) == 1,
      status: MessageDeliveryStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => MessageDeliveryStatus.sent,
      ),
      contentType: isDeleted
          ? MessageContentType.text
          : MessageContentType.values.firstWhere(
              (t) => t.name == row['content_type'],
              orElse: () => MessageContentType.text,
            ),
      isDisappearing: (row['is_disappearing'] as int) == 1,
      remainingSeconds: row['remaining_seconds'] as int?,
      attachmentName: attName,
      attachmentSize: attSize,
      attachmentPath: attPath,
      replyTo: isDeleted ? null : replyTo,
      isEdited: (row['is_edited'] as int) == 1,
      isDeleted: isDeleted,
    );
  }

  // ── Call Logs ──────────────────────────────────────────────────────────────

  Future<void> insertCallLog({
    required String id,
    required String contactName,
    String? contactId,
    String? contactPhone,
    String? avatarUrl,
    required bool isVideo,
    required bool isOutgoing,
    required String status, // 'completed', 'missed', 'rejected', 'cancelled'
    int durationSeconds = 0,
    int? timestamp,
  }) async {
    try {
      final safeName = contactName.trim().isNotEmpty
          ? contactName.trim()
          : (contactPhone?.trim().isNotEmpty == true
              ? contactPhone!.trim()
              : (contactId?.trim().isNotEmpty == true ? contactId!.trim() : 'Panggilan'));

      await _database.insert(
        'call_logs',
        {
          'id': id,
          'contact_name': safeName,
          'contact_id': contactId,
          'contact_phone': contactPhone,
          'avatar_url': avatarUrl,
          'is_video': isVideo ? 1 : 0,
          'is_outgoing': isOutgoing ? 1 : 0,
          'status': status,
          'duration_seconds': durationSeconds,
          'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[LocalDatabase] insertCallLog saved: $safeName (out=$isOutgoing, status=$status, dur=$durationSeconds)');
    } catch (e) {
      debugPrint('[LocalDatabase] insertCallLog error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCallLogs() async {
    try {
      final rows = await _database.query(
        'call_logs',
        orderBy: 'timestamp DESC',
        limit: 100,
      );
      return rows;
    } catch (_) {
      return [];
    }
  }

  Future<void> clearCallLogs() async {
    try {
      await _database.delete('call_logs');
    } catch (_) {}
  }

  Future<void> deleteCallLog(String id) async {
    try {
      await _database.delete(
        'call_logs',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  Future<void> syncCallLogsWithServerIds(Set<String> validServerIds) async {
    try {
      final localRows = await _database.query('call_logs');
      for (final row in localRows) {
        final id = row['id'] as String? ?? '';
        // If it was downloaded from server (not a temporary local id) and no longer exists on server, remove it
        if (!id.startsWith('call-log-') && !validServerIds.contains(id)) {
          await _database.delete('call_logs', where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (_) {}
  }

  // ── Storage & Network Stats Helpers ────────────────────────────────────────

  /// Returns total SQLite database file size on disk (main db + WAL + SHM)
  Future<int> getDatabaseSizeBytes() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, _dbName);
      int total = 0;
      final mainDb = File(path);
      if (await mainDb.exists()) {
        total += await mainDb.length();
      }
      final walDb = File('$path-wal');
      if (await walDb.exists()) {
        total += await walDb.length();
      }
      final shmDb = File('$path-shm');
      if (await shmDb.exists()) {
        total += await shmDb.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Calculates actual photos, videos, audio, and documents bytes for a conversation
  Future<Map<String, int>> getChatMediaStats(String conversationId) async {
    int photos = 0;
    int videos = 0;
    int audio = 0;
    int docs = 0;

    try {
      final rows = await _database.query(
        'messages',
        columns: ['content', 'content_type', 'attachment_path', 'attachment_name', 'attachment_size'],
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );

      for (final row in rows) {
        final cType = (row['content_type'] as String? ?? 'text').toLowerCase();
        final attPath = row['attachment_path'] as String?;
        final content = row['content'] as String? ?? '';
        final attName = (row['attachment_name'] as String? ?? '').toLowerCase();

        int itemSize = 0;
        if (attPath != null && attPath.isNotEmpty) {
          if (attPath.startsWith('data:')) {
            itemSize = (attPath.length * 3) ~/ 4;
          } else {
            final f = File(attPath);
            if (f.existsSync()) {
              itemSize = f.lengthSync();
            } else {
              itemSize = _parseSizeString(row['attachment_size'] as String?);
            }
          }
        } else if (content.startsWith('{') && content.contains('"media"')) {
          itemSize = content.length;
        }

        if (itemSize <= 0) {
          itemSize = content.length;
        }

        if (cType == 'voicenote' ||
            attName.endsWith('.m4a') ||
            attName.endsWith('.mp3') ||
            attName.endsWith('.wav') ||
            attName.endsWith('.ogg') ||
            (attPath != null && attPath.startsWith('data:audio'))) {
          audio += itemSize;
        } else if (attName.endsWith('.mp4') ||
            attName.endsWith('.mov') ||
            attName.endsWith('.mkv') ||
            attName.endsWith('.avi') ||
            (attPath != null && attPath.startsWith('data:video'))) {
          videos += itemSize;
        } else if (attName.endsWith('.jpg') ||
            attName.endsWith('.jpeg') ||
            attName.endsWith('.png') ||
            attName.endsWith('.webp') ||
            attName.endsWith('.gif') ||
            (attPath != null && attPath.startsWith('data:image'))) {
          photos += itemSize;
        } else if (cType == 'attachment' || cType == 'document' || attName.isNotEmpty) {
          docs += itemSize;
        }
      }
    } catch (e) {
      debugPrint('[LocalDatabase] getChatMediaStats error: $e');
    }

    return {
      'photos': photos,
      'videos': videos,
      'audio': audio,
      'docs': docs,
    };
  }

  /// Clears specified media types for a conversation from disk & database
  Future<void> clearChatMediaFromDb(
    String conversationId, {
    bool photos = false,
    bool videos = false,
    bool audio = false,
    bool docs = false,
  }) async {
    try {
      final rows = await _database.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );

      for (final row in rows) {
        final id = row['id'] as String;
        final cType = (row['content_type'] as String? ?? 'text').toLowerCase();
        final attPath = row['attachment_path'] as String?;
        final attName = (row['attachment_name'] as String? ?? '').toLowerCase();

        bool match = false;
        if (audio &&
            (cType == 'voicenote' ||
                attName.endsWith('.m4a') ||
                attName.endsWith('.mp3') ||
                attName.endsWith('.wav') ||
                attName.endsWith('.ogg') ||
                (attPath != null && attPath.startsWith('data:audio')))) {
          match = true;
        } else if (videos &&
            (attName.endsWith('.mp4') ||
                attName.endsWith('.mov') ||
                attName.endsWith('.mkv') ||
                attName.endsWith('.avi') ||
                (attPath != null && attPath.startsWith('data:video')))) {
          match = true;
        } else if (photos &&
            (attName.endsWith('.jpg') ||
                attName.endsWith('.jpeg') ||
                attName.endsWith('.png') ||
                attName.endsWith('.webp') ||
                attName.endsWith('.gif') ||
                (attPath != null && attPath.startsWith('data:image')))) {
          match = true;
        } else if (docs && (cType == 'attachment' || cType == 'document' || attName.isNotEmpty)) {
          match = true;
        }

        if (match) {
          // Delete physical file if present on disk
          if (attPath != null && attPath.isNotEmpty && !attPath.startsWith('data:')) {
            try {
              final f = File(attPath);
              if (await f.exists()) {
                await f.delete();
              }
            } catch (_) {}
          }

          // Strip media data from SQLite message record
          await _database.update(
            'messages',
            {
              'attachment_path': null,
              'attachment_name': null,
              'attachment_size': null,
              'content': '',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (e) {
      debugPrint('[LocalDatabase] clearChatMediaFromDb error: $e');
    }
  }

  /// Calculates initial network usage seed from existing local database records
  Future<Map<String, int>> getInitialNetworkStatsSeed() async {
    int msgSent = 0;
    int msgRecv = 0;
    int msgBytesSent = 0;
    int msgBytesRecv = 0;
    int callsCount = 0;
    int callDurationSec = 0;

    try {
      final sentRow = await _database.rawQuery(
        'SELECT COUNT(*) as cnt, SUM(LENGTH(content) + COALESCE(LENGTH(attachment_path), 0)) as totalBytes FROM messages WHERE is_outgoing = 1',
      );
      if (sentRow.isNotEmpty) {
        msgSent = (sentRow.first['cnt'] as int?) ?? 0;
        msgBytesSent = (sentRow.first['totalBytes'] as int?) ?? 0;
      }

      final recvRow = await _database.rawQuery(
        'SELECT COUNT(*) as cnt, SUM(LENGTH(content) + COALESCE(LENGTH(attachment_path), 0)) as totalBytes FROM messages WHERE is_outgoing = 0',
      );
      if (recvRow.isNotEmpty) {
        msgRecv = (recvRow.first['cnt'] as int?) ?? 0;
        msgBytesRecv = (recvRow.first['totalBytes'] as int?) ?? 0;
      }

      final callRow = await _database.rawQuery(
        'SELECT COUNT(*) as cnt, SUM(duration_seconds) as totalDur FROM call_logs',
      );
      if (callRow.isNotEmpty) {
        callsCount = (callRow.first['cnt'] as int?) ?? 0;
        callDurationSec = (callRow.first['totalDur'] as int?) ?? 0;
      }
    } catch (_) {}

    return {
      'msgSent': msgSent,
      'msgRecv': msgRecv,
      'msgBytesSent': msgBytesSent,
      'msgBytesRecv': msgBytesRecv,
      'callsCount': callsCount,
      'callDurationSec': callDurationSec,
    };
  }

  static int _parseSizeString(String? sizeStr) {
    if (sizeStr == null || sizeStr.trim().isEmpty) return 0;
    final clean = sizeStr.trim().toUpperCase();
    try {
      if (clean.endsWith('MB')) {
        final val = double.tryParse(clean.replaceAll('MB', '').trim()) ?? 0;
        return (val * 1024 * 1024).round();
      } else if (clean.endsWith('KB')) {
        final val = double.tryParse(clean.replaceAll('KB', '').trim()) ?? 0;
        return (val * 1024).round();
      } else if (clean.endsWith('B')) {
        final val = double.tryParse(clean.replaceAll('B', '').trim()) ?? 0;
        return val.round();
      } else {
        return int.tryParse(clean) ?? 0;
      }
    } catch (_) {
      return 0;
    }
  }
}
