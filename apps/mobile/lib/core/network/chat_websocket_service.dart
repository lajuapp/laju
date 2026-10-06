import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import 'api_client.dart';

/// Real-time WebSocket connection for Chat messaging, receipts, typing, and recalls.
class ChatWebSocketService {
  ChatWebSocketService._();
  static final ChatWebSocketService instance = ChatWebSocketService._();

  WebSocket? _ws;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _shouldReconnect = true;

  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  bool get isConnected => isConnectedNotifier.value;

  final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  /// Callbacks
  Function(Map<String, dynamic> message)? onNewMessage;
  Function(String conversationId, String messageId)? onMessageDeleted;
  Function(String conversationId, String userId, String? username, bool isTyping)? onTyping;
  Function(String conversationId)? onConversationPurged;
  Function(String conversationId, String messageId, String userId, String emoji, String action)? onMessageReaction;
  Function(Map<String, dynamic> payload)? onCallIncoming;
  Function(Map<String, dynamic> payload)? onStatusUpdate;

  /// Connect to /ws/chat
  Future<void> connect() async {
    if (_isConnecting || (_ws != null && _ws!.readyState == WebSocket.open)) {
      return;
    }

    final token = ApiClient.instance.authToken;
    if (token == null || token.isEmpty) {
      debugPrint('[ChatWS] No auth token available, skipping WS connect');
      return;
    }

    _isConnecting = true;
    _shouldReconnect = true;

    try {
      final wsBase = EnvConfig.instance.websocketUrl;
      final uri = Uri.parse('$wsBase/ws/chat?token=${Uri.encodeComponent(token)}');

      debugPrint('[ChatWS] Connecting to $uri');
      _ws = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 8));

      _isConnecting = false;
      isConnectedNotifier.value = true;
      debugPrint('[ChatWS] Connected successfully to /ws/chat');

      _startPing();

      _ws!.listen(
        _handleMessage,
        onError: (err) {
          debugPrint('[ChatWS] Error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[ChatWS] Disconnected (done)');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      isConnectedNotifier.value = false;
      debugPrint('[ChatWS] Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final text = data is String ? data : utf8.decode(data as List<int>);
      final json = jsonDecode(text);
      if (json is! Map) return;
      final map = Map<String, dynamic>.from(json);

      final type = map['type'] as String? ?? map['event'] as String? ?? '';

      // Ignore PONG
      if (type == 'PONG') return;

      _eventStreamController.add(map);

      switch (type) {
        case 'NEW_MESSAGE':
          if (map['message'] is Map) {
            onNewMessage?.call(Map<String, dynamic>.from(map['message'] as Map));
          }
          break;

        case 'MESSAGE_DELETED':
          final convId = map['conversationId'] as String? ?? '';
          final msgId = map['messageId'] as String? ?? '';
          if (convId.isNotEmpty && msgId.isNotEmpty) {
            onMessageDeleted?.call(convId, msgId);
          }
          break;

        case 'TYPING':
          final convId = map['conversationId'] as String? ?? '';
          final uId = map['userId'] as String? ?? '';
          final uName = map['username'] as String?;
          final isTyping = map['isTyping'] == true;
          if (convId.isNotEmpty) {
            onTyping?.call(convId, uId, uName, isTyping);
          }
          break;

        case 'CONVERSATION_PURGED':
          final convId = map['conversationId'] as String? ?? '';
          if (convId.isNotEmpty) {
            onConversationPurged?.call(convId);
          }
          break;

        case 'MESSAGE_REACTION':
          final convId = map['conversationId'] as String? ?? '';
          final msgId = map['messageId'] as String? ?? '';
          final uId = map['userId'] as String? ?? '';
          final emoji = map['emoji'] as String? ?? '';
          final action = map['action'] as String? ?? 'ADD';
          if (convId.isNotEmpty && msgId.isNotEmpty && emoji.isNotEmpty) {
            onMessageReaction?.call(convId, msgId, uId, emoji, action);
          }
          break;

        case 'CALL_INCOMING':
          onCallIncoming?.call(map);
          break;

        case 'STATUS_UPDATE':
          onStatusUpdate?.call(map);
          break;
      }
    } catch (e) {
      debugPrint('[ChatWS] Error parsing message: $e');
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _ws = null;
    isConnectedNotifier.value = false;
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_shouldReconnect && ApiClient.instance.authToken != null) {
        connect();
      }
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (t) {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        try {
          _ws!.add(jsonEncode({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch}));
        } catch (_) {}
      } else {
        t.cancel();
      }
    });
  }

  /// Inform backend of typing state via WebSocket
  void sendTyping(String conversationId, bool isTyping) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      try {
        _ws!.add(jsonEncode({
          'type': 'typing',
          'conversationId': conversationId,
          'isTyping': isTyping,
        }));
      } catch (_) {}
    }
  }

  /// Recall message via WebSocket
  void sendRecall(String messageId) {
    if (_ws != null && _ws!.readyState == WebSocket.open) {
      try {
        _ws!.add(jsonEncode({
          'type': 'recall_message',
          'messageId': messageId,
        }));
      } catch (_) {}
    }
  }

  /// Disconnect explicitly (e.g. on user logout)
  void disconnect() {
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    isConnectedNotifier.value = false;
  }
}
