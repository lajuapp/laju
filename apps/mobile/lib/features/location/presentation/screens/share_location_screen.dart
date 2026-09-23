import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class ShareLocationScreen extends StatefulWidget {
  const ShareLocationScreen({super.key});

  @override
  State<ShareLocationScreen> createState() => _ShareLocationScreenState();
}

class _ShareLocationScreenState extends State<ShareLocationScreen> {
  LocationData? _location;
  bool _isLoading = true;
  String? _errorMessage;
  int _zoom = 16;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final loc = await LocationService.instance.getCurrentLocation();
    if (mounted) {
      if (loc != null) {
        setState(() {
          _location = loc;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mendeteksi lokasi GPS perangkat';
          // Fallback location (Jakarta Pusat) so user can still share or pick
          _location = const LocationData(
            latitude: -6.2088,
            longitude: 106.8456,
            accuracy: 50.0,
            name: 'Jakarta Pusat',
            address: 'DKI Jakarta, Indonesia',
          );
        });
      }
    }
  }

  void _sendLocation({bool isLive = false}) {
    if (_location == null) return;
    final locToSend = LocationData(
      latitude: _location!.latitude,
      longitude: _location!.longitude,
      accuracy: _location!.accuracy,
      name: isLive ? 'Lokasi Langsung (Live)' : _location!.name,
      address: _location!.address,
      isLive: isLive,
    );
    Navigator.pop(context, locToSend);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final lat = _location?.latitude ?? -6.2088;
    final lng = _location?.longitude ?? 106.8456;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Bagi Lokasi',
          style: TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Lokasi',
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(Icons.my_location_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
            onPressed: _isLoading ? null : _fetchLocation,
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // OpenStreetMap Tile Map Background
          Positioned.fill(
            child: _buildOsmMapBackground(lat, lng, isDark),
          ),

          // OSM Attribution Chip (Required by OpenStreetMap Foundation)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black87 : Colors.white70),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
            ),
          ),

          // Center Radar Pulse & Pin
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: 0.20),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),

          // Accuracy & Current Coords Chip
          if (_location != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      _location!.accuracy > 0
                          ? 'Akurasi: ~${_location!.accuracy.round()}m'
                          : 'GPS Terhubung',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Sheet Actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Option 1: Live Location
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.share_location_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Bagikan Lokasi Langsung',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        'Bagikan pembaruan lokasi langsung real-time',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () => _sendLocation(isLive: true),
                    ),
                    Divider(color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6), height: 16),

                    // Option 2: Current Location
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF3F4F6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.my_location_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        'Kirim Lokasi Terkini',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        _location != null
                            ? '${_location!.name} • ${_location!.address}'
                            : 'Memindai sinyal GPS satelit...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _sendLocation(isLive: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOsmMapBackground(double lat, double lng, bool isDark) {
    // Generate OpenStreetMap 3x3 tile grid centered on user coordinates
    final n = 1 << _zoom;
    final centerTileX = ((lng + 180) / 360 * n).floor().clamp(0, n - 1);
    final latRad = lat * math.pi / 180.0;
    final sec = 1.0 / math.cos(latRad);
    final centerTileY = ((1.0 - (math.log(math.tan(latRad) + sec) / math.pi)) / 2.0 * n)
        .floor()
        .clamp(0, n - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Base background
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: RadarMapPainter(isDark: isDark),
            ),
            // OpenStreetMap tile image
            Positioned.fill(
              child: Opacity(
                opacity: 0.88,
                child: Image.network(
                  'https://tile.openstreetmap.org/$_zoom/$centerTileX/$centerTileY.png',
                  fit: BoxFit.cover,
                  headers: const {
                    'User-Agent': 'LajuMobileApp/1.0 (Privacy-First Secure Messenger)',
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return CustomPaint(
                      painter: RadarMapPainter(isDark: isDark),
                    );
                  },
                ),
              ),
            ),
            if (isDark)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RadarMapPainter extends CustomPainter {
  final bool isDark;
  RadarMapPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE5E7EB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadColor = isDark ? const Color(0xFF334155) : Colors.white;

    final roadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final roadThinPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw stylized street grid
    for (double x = 40; x < size.width; x += 90) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadThinPaint);
    }
    for (double y = 60; y < size.height; y += 100) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadThinPaint);
    }

    // Main avenues
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.45, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant RadarMapPainter oldDelegate) => oldDelegate.isDark != isDark;
}
