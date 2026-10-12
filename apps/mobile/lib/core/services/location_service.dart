import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../security/app_lock_controller.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String name;
  final String address;
  final bool isLive;
  final int? liveDurationMinutes;
  final DateTime? liveExpiresAt;
  final String? comment;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    required this.name,
    required this.address,
    this.isLive = false,
    this.liveDurationMinutes,
    this.liveExpiresAt,
    this.comment,
  });

  bool get isLiveExpired {
    if (!isLive || liveExpiresAt == null) return false;
    return DateTime.now().isAfter(liveExpiresAt!);
  }

  String get liveRemainingText {
    if (!isLive || liveExpiresAt == null) return '';
    final diff = liveExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Berakhir';
    if (diff.inHours > 0) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return mins > 0 ? '$hours jam $mins mnt' : '$hours jam';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes} mnt';
    }
    return '${diff.inSeconds} dtk';
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? name,
    String? address,
    bool? isLive,
    int? liveDurationMinutes,
    DateTime? liveExpiresAt,
    String? comment,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      name: name ?? this.name,
      address: address ?? this.address,
      isLive: isLive ?? this.isLive,
      liveDurationMinutes: liveDurationMinutes ?? this.liveDurationMinutes,
      liveExpiresAt: liveExpiresAt ?? this.liveExpiresAt,
      comment: comment ?? this.comment,
    );
  }

  String get osmUrl =>
      'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=16/$latitude/$longitude';

  String getOsmTileUrl({int zoom = 16}) {
    return LocationData.calculateOsmTileUrl(latitude, longitude, zoom);
  }

  static String calculateOsmTileUrl(double lat, double lng, int zoom) {
    try {
      final n = 1 << zoom;
      final x = ((lng + 180) / 360 * n).floor().clamp(0, n - 1);
      final latRad = lat * math.pi / 180.0;
      final sec = 1.0 / math.cos(latRad);
      final y = ((1.0 - (math.log(math.tan(latRad) + sec) / math.pi)) / 2.0 * n)
          .floor()
          .clamp(0, n - 1);
      return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
    } catch (_) {
      return 'https://tile.openstreetmap.org/16/0/0.png';
    }
  }

  Map<String, dynamic> toMap() => {
        'type': 'location',
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'name': name,
        'address': address,
        'isLive': isLive,
        if (liveDurationMinutes != null) 'liveDurationMinutes': liveDurationMinutes,
        if (liveExpiresAt != null) 'liveExpiresAt': liveExpiresAt!.toIso8601String(),
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };

  String toJson() => jsonEncode(toMap());

  factory LocationData.fromMap(Map<String, dynamic> map) {
    DateTime? expiresAt;
    if (map['liveExpiresAt'] != null) {
      expiresAt = DateTime.tryParse(map['liveExpiresAt'].toString());
    }
    return LocationData(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      name: (map['name'] as String?)?.isNotEmpty == true
          ? map['name'] as String
          : 'Lokasi Terkini',
      address: (map['address'] as String?)?.isNotEmpty == true
          ? map['address'] as String
          : '${map['latitude']}, ${map['longitude']}',
      isLive: map['isLive'] as bool? ?? false,
      liveDurationMinutes: map['liveDurationMinutes'] as int?,
      liveExpiresAt: expiresAt,
      comment: map['comment'] as String?,
    );
  }

  factory LocationData.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return LocationData.fromMap(decoded);
      }
    } catch (_) {}
    return const LocationData(
      latitude: 0.0,
      longitude: 0.0,
      name: 'Lokasi',
      address: '',
    );
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const MethodChannel _channel = MethodChannel('com.laju/location');

  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasLocationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestLocationPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      if (map != null) {
        var loc = LocationData.fromMap(map);
        // If address is just coordinates, try OpenStreetMap Nominatim reverse geocode
        if (loc.address.isEmpty || loc.address.contains(RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$'))) {
          final osmAddress = await reverseGeocodeNominatim(loc.latitude, loc.longitude);
          if (osmAddress != null) {
            loc = LocationData(
              latitude: loc.latitude,
              longitude: loc.longitude,
              accuracy: loc.accuracy,
              name: osmAddress['name'] ?? loc.name,
              address: osmAddress['address'] ?? loc.address,
              isLive: loc.isLive,
            );
          }
        }
        return loc;
      }
    } catch (e) {
      debugPrint('[LocationService] getCurrentLocation error: $e');
    }
    return null;
  }

  /// Reverse geocode using OpenStreetMap Nominatim (Privacy friendly, open source)
  Future<Map<String, String>?> reverseGeocodeNominatim(double lat, double lng) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'LajuMobileApp/1.0 (Privacy-First Secure Messenger)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map) {
          final displayName = (data['display_name'] as String?) ?? '';
          final addr = data['address'] as Map?;
          String placeName = 'Lokasi Terkini';
          if (addr != null) {
            placeName = (addr['building'] ??
                    addr['amenity'] ??
                    addr['road'] ??
                    addr['suburb'] ??
                    addr['village'] ??
                    addr['city'] ??
                    'Lokasi Terkini')
                .toString();
          }
          return {
            'name': placeName,
            'address': displayName.isNotEmpty ? displayName : '$lat, $lng',
          };
        }
      }
    } catch (_) {
    } finally {
      client?.close();
    }
    return null;
  }

  Future<void> openMap(double latitude, double longitude, {String? label}) async {
    try {
      AppLockController.instance.markExternalIntentStarted();
      await _channel.invokeMethod('openMap', {
        'latitude': latitude,
        'longitude': longitude,
        'label': label ?? 'Lokasi',
      });
    } catch (e) {
      debugPrint('[LocationService] openMap error: $e');
    } finally {
      AppLockController.instance.markExternalIntentFinished();
    }
  }
}
