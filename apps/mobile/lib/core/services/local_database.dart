import 'dart:async';
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
      cached_at             INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createMessages = '''
    CREATE TABLE IF NOT EXISTS messages (
      id               TEXT PRIMARY KEY,
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
      is_edited        INTEGER NOT NULL DEFAULT 0,
      cached_at        INTEGER NOT NULL DEFAULT 0
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
        await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id)');
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN avatar_url TEXT');
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
    } catch (_) {
      return [];
    }
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
      final rows = await _database.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'timestamp ASC',
      );
      return rows.map(_rowToMessage).toList();
    } catch (_) {
      return [];
    }
  }

  /// Insert or replace a list of messages. Evicts oldest if over [_maxMessagesPerConv].
  Future<void> upsertMessages(String conversationId, List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _database.batch();
    for (final m in messages) {
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

  /// Update the delivery status of a specific message.
  Future<void> updateMessageStatus(String messageId, MessageDeliveryStatus status) async {
    await _database.update(
      'messages',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [messageId],
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
    return {
      'id': c.id,
      'title': c.title,
      'last_message': c.lastMessage,
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
      'cached_at': cachedAt,
    };
  }

  ConversationModel _rowToConversation(Map<String, dynamic> row) {
    return ConversationModel(
      id: row['id'] as String,
      title: row['title'] as String,
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
    );
  }

  Map<String, dynamic> _messageToRow(MessageModel m, int cachedAt) {
    return {
      'id': m.id,
      'conversation_id': m.conversationId,
      'sender_name': m.senderName,
      'content': m.content,
      'timestamp': m.timestamp.millisecondsSinceEpoch,
      'is_outgoing': m.isOutgoing ? 1 : 0,
      'status': m.status.name,
      'content_type': m.contentType.name,
      'is_disappearing': m.isDisappearing ? 1 : 0,
      'remaining_seconds': m.remainingSeconds,
      'attachment_name': m.attachmentName,
      'attachment_size': m.attachmentSize,
      'attachment_path': m.attachmentPath,
      'is_edited': m.isEdited ? 1 : 0,
      'cached_at': cachedAt,
    };
  }

  MessageModel _rowToMessage(Map<String, dynamic> row) {
    return MessageModel(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderName: row['sender_name'] as String,
      content: row['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      isOutgoing: (row['is_outgoing'] as int) == 1,
      status: MessageDeliveryStatus.values.firstWhere(
        (s) => s.name == row['status'],
        orElse: () => MessageDeliveryStatus.sent,
      ),
      contentType: MessageContentType.values.firstWhere(
        (t) => t.name == row['content_type'],
        orElse: () => MessageContentType.text,
      ),
      isDisappearing: (row['is_disappearing'] as int) == 1,
      remainingSeconds: row['remaining_seconds'] as int?,
      attachmentName: row['attachment_name'] as String?,
      attachmentSize: row['attachment_size'] as String?,
      attachmentPath: row['attachment_path'] as String?,
      isEdited: (row['is_edited'] as int) == 1,
    );
  }
}
