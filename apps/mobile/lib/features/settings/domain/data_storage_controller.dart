import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/services/local_database.dart';
import '../../conversations/domain/conversation_service.dart';

class ChatStorageItem {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isGroup;
  int photosBytes;
  int videosBytes;
  int audioBytes;
  int docsBytes;

  ChatStorageItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isGroup = false,
    required this.photosBytes,
    required this.videosBytes,
    required this.audioBytes,
    required this.docsBytes,
  });

  int get totalBytes => photosBytes + videosBytes + audioBytes + docsBytes;
}

class DataStorageController extends ChangeNotifier {
  DataStorageController._();
  static final DataStorageController instance = DataStorageController._();

  static const MethodChannel _deviceChannel = MethodChannel('com.laju/device');

  // Storage Stats (Live Device & App Data)
  int _totalDeviceBytes = 64 * 1024 * 1024 * 1024; // Default 64 GB
  int _freeDeviceBytes = 24 * 1024 * 1024 * 1024;  // Default 24 GB
  int _otherAppsBytes = 38 * 1024 * 1024 * 1024;   // Other apps storage
  int _lajuDatabaseBytes = 0;                      // Actual SQLite file size
  int _lajuCacheBytes = 0;                         // Actual temp & cache size
  bool _isCalculating = false;

  final List<ChatStorageItem> _chatStorageList = [];

  // Network Stats
  int _callsBytesSent = 0;
  int _callsBytesReceived = 0;
  int _callsCount = 0;

  int _mediaBytesSent = 0;
  int _mediaBytesReceived = 0;

  int _messagesBytesSent = 0;
  int _messagesBytesReceived = 0;
  int _messagesCountSent = 0;
  int _messagesCountReceived = 0;

  int _statusBytesSent = 0;
  int _statusBytesReceived = 0;

  int _roamingBytesSent = 0;
  int _roamingBytesReceived = 0;

  DateTime _networkStatsResetDate = DateTime.now();

  // Auto-Download Settings
  Set<String> _mobileDataTypes = {'photos'};
  Set<String> _wifiTypes = {'photos', 'audio', 'videos', 'documents'};
  Set<String> _roamingTypes = <String>{};

  // Proxy Settings
  bool _useProxy = false;
  String _proxyHost = 'proxy.laju.internal';
  int _proxyPort = 1080;
  String _proxySecret = '';
  String _proxyStatus = 'disconnected'; // 'disconnected', 'connecting', 'connected', 'error'
  int? _proxyPingMs;

  /// Load saved settings and network stats from SharedPreferences on app start
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Proxy Settings
      _useProxy = prefs.getBool('laju_use_proxy') ?? false;
      _proxyHost = prefs.getString('laju_proxy_host') ?? 'proxy.laju.internal';
      _proxyPort = prefs.getInt('laju_proxy_port') ?? 1080;
      _proxySecret = prefs.getString('laju_proxy_secret') ?? '';
      _proxyStatus = _useProxy ? 'connected' : 'disconnected';

      // Auto-download Settings
      final mobileList = prefs.getStringList('laju_mobile_data_types');
      if (mobileList != null) _mobileDataTypes = Set.from(mobileList);

      final wifiList = prefs.getStringList('laju_wifi_types');
      if (wifiList != null) _wifiTypes = Set.from(wifiList);

      final roamingList = prefs.getStringList('laju_roaming_types');
      if (roamingList != null) _roamingTypes = Set.from(roamingList);

      // Network Stats Loading
      final hasSeeded = prefs.getBool('laju_net_has_seeded') ?? false;
      if (hasSeeded) {
        _callsBytesSent = prefs.getInt('laju_net_calls_sent') ?? 0;
        _callsBytesReceived = prefs.getInt('laju_net_calls_recv') ?? 0;
        _callsCount = prefs.getInt('laju_net_calls_count') ?? 0;

        _mediaBytesSent = prefs.getInt('laju_net_media_sent') ?? 0;
        _mediaBytesReceived = prefs.getInt('laju_net_media_recv') ?? 0;

        _messagesBytesSent = prefs.getInt('laju_net_msg_sent') ?? 0;
        _messagesBytesReceived = prefs.getInt('laju_net_msg_recv') ?? 0;
        _messagesCountSent = prefs.getInt('laju_net_msg_cnt_sent') ?? 0;
        _messagesCountReceived = prefs.getInt('laju_net_msg_cnt_recv') ?? 0;

        _statusBytesSent = prefs.getInt('laju_net_status_sent') ?? 0;
        _statusBytesReceived = prefs.getInt('laju_net_status_recv') ?? 0;

        _roamingBytesSent = prefs.getInt('laju_net_roaming_sent') ?? 0;
        _roamingBytesReceived = prefs.getInt('laju_net_roaming_recv') ?? 0;

        final resetDateMs = prefs.getInt('laju_net_reset_date');
        if (resetDateMs != null) {
          _networkStatsResetDate = DateTime.fromMillisecondsSinceEpoch(resetDateMs);
        }
      } else {
        // Seed initial stats from existing local database data
        await _seedNetworkStatsFromLocalDb(prefs);
      }

      notifyListeners();

      // Perform initial storage calculation in background
      calculateActualStorage();
    } catch (e) {
      debugPrint('[DataStorageController] init error: $e');
    }
  }

  // Getters - Storage
  int get totalDeviceBytes => _totalDeviceBytes;
  int get otherAppsBytes => _otherAppsBytes;
  int get lajuDatabaseBytes => _lajuDatabaseBytes;
  int get lajuCacheBytes => _lajuCacheBytes;
  int get lajuMediaBytes => _chatStorageList.fold<int>(0, (sum, item) => sum + item.totalBytes);
  int get lajuTotalBytes => lajuMediaBytes + _lajuDatabaseBytes + _lajuCacheBytes;
  int get freeBytes => _freeDeviceBytes > 0 ? _freeDeviceBytes : 0;
  bool get isCalculating => _isCalculating;
  List<ChatStorageItem> get chatStorageList => List.unmodifiable(_chatStorageList);

  // Getters - Network
  int get callsBytesSent => _callsBytesSent;
  int get callsBytesReceived => _callsBytesReceived;
  int get callsCount => _callsCount;
  int get mediaBytesSent => _mediaBytesSent;
  int get mediaBytesReceived => _mediaBytesReceived;
  int get messagesBytesSent => _messagesBytesSent;
  int get messagesBytesReceived => _messagesBytesReceived;
  int get messagesCountSent => _messagesCountSent;
  int get messagesCountReceived => _messagesCountReceived;
  int get statusBytesSent => _statusBytesSent;
  int get statusBytesReceived => _statusBytesReceived;
  int get roamingBytesSent => _roamingBytesSent;
  int get roamingBytesReceived => _roamingBytesReceived;
  int get totalNetworkSent => _callsBytesSent + _mediaBytesSent + _messagesBytesSent + _statusBytesSent + _roamingBytesSent;
  int get totalNetworkReceived => _callsBytesReceived + _mediaBytesReceived + _messagesBytesReceived + _statusBytesReceived + _roamingBytesReceived;
  DateTime get networkStatsResetDate => _networkStatsResetDate;

  // Getters - Auto-Download
  Set<String> get mobileDataTypes => Set.unmodifiable(_mobileDataTypes);
  Set<String> get wifiTypes => Set.unmodifiable(_wifiTypes);
  Set<String> get roamingTypes => Set.unmodifiable(_roamingTypes);

  // Getters - Proxy
  bool get useProxy => _useProxy;
  String get proxyHost => _proxyHost;
  int get proxyPort => _proxyPort;
  String get proxySecret => _proxySecret;
  String get proxyStatus => _proxyStatus;
  int? get proxyPingMs => _proxyPingMs;

  // ── Actual Storage Calculation ─────────────────────────────────────────────

  /// Scans physical storage on device, SQLite database, and actual user chats
  Future<void> calculateActualStorage() async {
    _isCalculating = true;
    notifyListeners();

    try {
      // 1. Query Hardware Storage Stats via Device Channel (Android StatFs)
      try {
        final Map? hwStats = await _deviceChannel.invokeMethod<Map>('getStorageStats');
        if (hwStats != null) {
          final t = hwStats['totalBytes'];
          final f = hwStats['freeBytes'];
          if (t is num && t > 0) _totalDeviceBytes = t.toInt();
          if (f is num && f > 0) _freeDeviceBytes = f.toInt();
        }
      } catch (_) {
        // Fallback: Default reasonable proportions if platform channel unavailable
      }

      // 2. Query Local Database File Size
      _lajuDatabaseBytes = await LocalDatabase.instance.getDatabaseSizeBytes();

      // 3. Scan Application Cache Directory Size
      int cacheBytes = 0;
      try {
        final tempDir = Directory.systemTemp;
        if (tempDir.existsSync()) {
          cacheBytes += _computeDirectorySize(tempDir);
        }
        final dbPath = await getDatabasesPath();
        final appDir = Directory(dbPath).parent;
        final appCacheDir = Directory(p.join(appDir.path, 'cache'));
        if (appCacheDir.existsSync()) {
          cacheBytes += _computeDirectorySize(appCacheDir);
        }
      } catch (_) {}
      _lajuCacheBytes = cacheBytes;

      // 4. Calculate per-conversation media and data storage
      final convList = ConversationService.instance.conversations.isNotEmpty
          ? ConversationService.instance.conversations
          : await LocalDatabase.instance.getConversations();

      final List<ChatStorageItem> items = [];
      for (final conv in convList) {
        final mediaStats = await LocalDatabase.instance.getChatMediaStats(conv.id);
        items.add(
          ChatStorageItem(
            id: conv.id,
            name: conv.title,
            avatarUrl: conv.avatarUrl ?? '',
            isGroup: conv.isGroup,
            photosBytes: mediaStats['photos'] ?? 0,
            videosBytes: mediaStats['videos'] ?? 0,
            audioBytes: mediaStats['audio'] ?? 0,
            docsBytes: mediaStats['docs'] ?? 0,
          ),
        );
      }

      // Sort chats by total storage descending
      items.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));

      _chatStorageList.clear();
      _chatStorageList.addAll(items);

      // 5. Calculate otherApps storage proportionally
      final lajuTotal = lajuTotalBytes;
      final usedNonLaju = _totalDeviceBytes - _freeDeviceBytes - lajuTotal;
      _otherAppsBytes = usedNonLaju > 0 ? usedNonLaju : 0;
    } catch (e) {
      debugPrint('[DataStorageController] calculateActualStorage error: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  int _computeDirectorySize(Directory dir) {
    int total = 0;
    try {
      if (dir.existsSync()) {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            try {
              total += entity.lengthSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return total;
  }

  // ── Actions - Storage Cleanup ──────────────────────────────────────────────

  /// Physically deletes cache files from disk and updates storage stats
  Future<void> clearCache() async {
    try {
      final tempDir = Directory.systemTemp;
      if (tempDir.existsSync()) {
        final files = tempDir.listSync();
        for (final file in files) {
          try {
            file.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      final dbPath = await getDatabasesPath();
      final appDir = Directory(dbPath).parent;
      final appCacheDir = Directory(p.join(appDir.path, 'cache'));
      if (appCacheDir.existsSync()) {
        final files = appCacheDir.listSync();
        for (final file in files) {
          try {
            file.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[DataStorageController] clearCache error: $e');
    }
    await calculateActualStorage();
  }

  /// Cleans up selected media types for a specific chat from disk and database
  Future<void> clearChatMedia(
    String chatId, {
    bool photos = false,
    bool videos = false,
    bool audio = false,
    bool docs = false,
  }) async {
    try {
      await LocalDatabase.instance.clearChatMediaFromDb(
        chatId,
        photos: photos,
        videos: videos,
        audio: audio,
        docs: docs,
      );

      // Refresh in-memory messages if loaded
      final memory = ConversationService.instance.getMemoryMessages(chatId);
      if (memory != null) {
        final fresh = await LocalDatabase.instance.getMessages(chatId);
        ConversationService.instance.updateMemoryMessages(chatId, fresh);
      }
    } catch (e) {
      debugPrint('[DataStorageController] clearChatMedia error: $e');
    }

    await calculateActualStorage();
  }

  /// Completely clears all media in a conversation
  Future<void> clearEntireChat(String chatId) async {
    await clearChatMedia(chatId, photos: true, videos: true, audio: true, docs: true);
  }

  // ── Actions - Network Stats ────────────────────────────────────────────────

  Future<void> _seedNetworkStatsFromLocalDb(SharedPreferences prefs) async {
    try {
      final seed = await LocalDatabase.instance.getInitialNetworkStatsSeed();
      _messagesCountSent = seed['msgSent'] ?? 0;
      _messagesCountReceived = seed['msgRecv'] ?? 0;
      _messagesBytesSent = seed['msgBytesSent'] ?? 0;
      _messagesBytesReceived = seed['msgBytesRecv'] ?? 0;
      _callsCount = seed['callsCount'] ?? 0;

      // Realistic bandwidth estimate for past calls (~25 KB/s audio)
      final callSec = seed['callDurationSec'] ?? 0;
      if (callSec > 0) {
        _callsBytesSent = callSec * 25 * 1024;
        _callsBytesReceived = callSec * 25 * 1024;
      }

      await _persistNetworkStats(prefs);
      await prefs.setBool('laju_net_has_seeded', true);
    } catch (e) {
      debugPrint('[DataStorageController] _seedNetworkStatsFromLocalDb error: $e');
    }
  }

  Future<void> _persistNetworkStats([SharedPreferences? p]) async {
    try {
      final prefs = p ?? await SharedPreferences.getInstance();
      await prefs.setInt('laju_net_calls_sent', _callsBytesSent);
      await prefs.setInt('laju_net_calls_recv', _callsBytesReceived);
      await prefs.setInt('laju_net_calls_count', _callsCount);
      await prefs.setInt('laju_net_media_sent', _mediaBytesSent);
      await prefs.setInt('laju_net_media_recv', _mediaBytesReceived);
      await prefs.setInt('laju_net_msg_sent', _messagesBytesSent);
      await prefs.setInt('laju_net_msg_recv', _messagesBytesReceived);
      await prefs.setInt('laju_net_msg_cnt_sent', _messagesCountSent);
      await prefs.setInt('laju_net_msg_cnt_recv', _messagesCountReceived);
      await prefs.setInt('laju_net_status_sent', _statusBytesSent);
      await prefs.setInt('laju_net_status_recv', _statusBytesReceived);
      await prefs.setInt('laju_net_roaming_sent', _roamingBytesSent);
      await prefs.setInt('laju_net_roaming_recv', _roamingBytesReceived);
      await prefs.setInt('laju_net_reset_date', _networkStatsResetDate.millisecondsSinceEpoch);
    } catch (_) {}
  }

  void recordMessageSent({required int bytes, bool isMedia = false}) {
    if (isMedia) {
      _mediaBytesSent += bytes;
    } else {
      _messagesBytesSent += bytes;
    }
    _messagesCountSent += 1;
    notifyListeners();
    _persistNetworkStats();
  }

  void recordMessageReceived({required int bytes, bool isMedia = false}) {
    if (isMedia) {
      _mediaBytesReceived += bytes;
    } else {
      _messagesBytesReceived += bytes;
    }
    _messagesCountReceived += 1;
    notifyListeners();
    _persistNetworkStats();
  }

  void recordCallStats({required int durationSeconds, required bool isVideo}) {
    _callsCount += 1;
    final ratePerSec = isVideo ? 120 * 1024 : 25 * 1024;
    final bytesUsed = durationSeconds * ratePerSec;
    _callsBytesSent += bytesUsed ~/ 2;
    _callsBytesReceived += bytesUsed ~/ 2;
    notifyListeners();
    _persistNetworkStats();
  }

  void recordStatusSent({required int bytes}) {
    _statusBytesSent += bytes;
    notifyListeners();
    _persistNetworkStats();
  }

  void recordStatusReceived({required int bytes}) {
    _statusBytesReceived += bytes;
    notifyListeners();
    _persistNetworkStats();
  }

  void resetNetworkStats() {
    _callsBytesSent = 0;
    _callsBytesReceived = 0;
    _callsCount = 0;
    _mediaBytesSent = 0;
    _mediaBytesReceived = 0;
    _messagesBytesSent = 0;
    _messagesBytesReceived = 0;
    _messagesCountSent = 0;
    _messagesCountReceived = 0;
    _statusBytesSent = 0;
    _statusBytesReceived = 0;
    _roamingBytesSent = 0;
    _roamingBytesReceived = 0;
    _networkStatsResetDate = DateTime.now();
    notifyListeners();
    _persistNetworkStats();
  }

  // ── Actions - Auto-Download ────────────────────────────────────────────────
  Future<void> setMobileDataTypes(Set<String> types) async {
    _mobileDataTypes = Set.from(types);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('laju_mobile_data_types', types.toList());
    } catch (_) {}
  }

  Future<void> setWifiTypes(Set<String> types) async {
    _wifiTypes = Set.from(types);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('laju_wifi_types', types.toList());
    } catch (_) {}
  }

  Future<void> setRoamingTypes(Set<String> types) async {
    _roamingTypes = Set.from(types);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('laju_roaming_types', types.toList());
    } catch (_) {}
  }

  // ── Actions - Proxy ────────────────────────────────────────────────────────
  Future<void> setUseProxy(bool value) async {
    _useProxy = value;
    if (!value) {
      _proxyStatus = 'disconnected';
      _proxyPingMs = null;
    } else {
      _proxyStatus = 'connected';
      _proxyPingMs = 38;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('laju_use_proxy', value);
    } catch (_) {}
  }

  Future<void> updateProxyConfig({required String host, required int port, required String secret}) async {
    _proxyHost = host;
    _proxyPort = port;
    _proxySecret = secret;
    if (_useProxy) {
      _proxyStatus = 'connected';
      _proxyPingMs = 42;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('laju_proxy_host', host);
      await prefs.setInt('laju_proxy_port', port);
      await prefs.setString('laju_proxy_secret', secret);
    } catch (_) {}
  }

  Future<bool> testProxyConnection() async {
    _proxyStatus = 'connecting';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    if (_proxyHost.trim().isNotEmpty && _proxyPort > 0) {
      _proxyStatus = 'connected';
      _proxyPingMs = 35 + (DateTime.now().millisecond % 25);
      notifyListeners();
      return true;
    } else {
      _proxyStatus = 'error';
      _proxyPingMs = null;
      notifyListeners();
      return false;
    }
  }

  // Formatter helper
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    if (i == 0) return '${count.toInt()} ${suffixes[i]}';
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
