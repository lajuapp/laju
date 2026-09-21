import 'package:flutter/foundation.dart';

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

  // Storage Stats
  final int totalDeviceBytes = 64 * 1024 * 1024 * 1024; // 64 GB
  final int otherAppsBytes = 38 * 1024 * 1024 * 1024; // 38 GB
  final int _lajuDatabaseBytes = 2 * 1024 * 1024; // 2 MB local db
  int _lajuCacheBytes = 0;

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

  // Getters - Storage
  int get lajuDatabaseBytes => _lajuDatabaseBytes;
  int get lajuCacheBytes => _lajuCacheBytes;
  int get lajuMediaBytes => _chatStorageList.fold<int>(0, (sum, item) => sum + item.totalBytes);
  int get lajuTotalBytes => lajuMediaBytes + _lajuDatabaseBytes + _lajuCacheBytes;
  int get freeBytes {
    final free = totalDeviceBytes - otherAppsBytes - lajuTotalBytes;
    return free > 0 ? free : 0;
  }
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

  // Actions - Storage
  void clearCache() {
    _lajuCacheBytes = 0;
    notifyListeners();
  }

  void clearChatMedia(
    String chatId, {
    bool photos = false,
    bool videos = false,
    bool audio = false,
    bool docs = false,
  }) {
    final index = _chatStorageList.indexWhere((item) => item.id == chatId);
    if (index != -1) {
      final item = _chatStorageList[index];
      if (photos) item.photosBytes = 0;
      if (videos) item.videosBytes = 0;
      if (audio) item.audioBytes = 0;
      if (docs) item.docsBytes = 0;
      notifyListeners();
    }
  }

  void clearEntireChat(String chatId) {
    clearChatMedia(chatId, photos: true, videos: true, audio: true, docs: true);
  }

  // Actions - Network
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
  }

  // Actions - Auto-Download
  void setMobileDataTypes(Set<String> types) {
    _mobileDataTypes = Set.from(types);
    notifyListeners();
  }

  void setWifiTypes(Set<String> types) {
    _wifiTypes = Set.from(types);
    notifyListeners();
  }

  void setRoamingTypes(Set<String> types) {
    _roamingTypes = Set.from(types);
    notifyListeners();
  }

  // Actions - Proxy
  void setUseProxy(bool value) {
    _useProxy = value;
    if (!value) {
      _proxyStatus = 'disconnected';
      _proxyPingMs = null;
    } else {
      _proxyStatus = 'connected';
      _proxyPingMs = 38;
    }
    notifyListeners();
  }

  void updateProxyConfig({required String host, required int port, required String secret}) {
    _proxyHost = host;
    _proxyPort = port;
    _proxySecret = secret;
    if (_useProxy) {
      _proxyStatus = 'connected';
      _proxyPingMs = 42;
    }
    notifyListeners();
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
