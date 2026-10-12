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

  void _sendLocation({
    bool isLive = false,
    int? liveDurationMinutes,
    String? comment,
  }) {
    if (_location == null) return;
    DateTime? liveExpiresAt;
    if (isLive && liveDurationMinutes != null) {
      liveExpiresAt = DateTime.now().add(Duration(minutes: liveDurationMinutes));
    }
    final locToSend = LocationData(
      latitude: _location!.latitude,
      longitude: _location!.longitude,
      accuracy: _location!.accuracy,
      name: isLive ? 'Lokasi Terkini (Live)' : _location!.name,
      address: _location!.address,
      isLive: isLive,
      liveDurationMinutes: liveDurationMinutes,
      liveExpiresAt: liveExpiresAt,
      comment: comment,
    );
    Navigator.pop(context, locToSend);
  }

  void _showLiveLocationDurationSheet() {
    if (_location == null) {
      LajuToast.info(context, 'Sedang memindai lokasi GPS, mohon tunggu sebentar...');
      _fetchLocation();
      return;
    }
    int selectedMinutes = 60; // 15, 60, 480, 1440
    final commentController = TextEditingController();
    final isDark = ThemeModeController.instance.isDarkMode(context);

    String formatExpiryTime(int mins) {
      final exp = DateTime.now().add(Duration(minutes: mins));
      final hh = exp.hour.toString().padLeft(2, '0');
      final mm = exp.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    String formatDurationLabel(int mins) {
      if (mins < 60) return '$mins menit';
      final h = mins ~/ 60;
      return '$h jam';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final expiryTimeStr = formatExpiryTime(selectedMinutes);
            final durationStr = formatDurationLabel(selectedMinutes);

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share_location_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bagikan Lokasi Langsung',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih durasi waktu pembaruan real-time:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp-style Duration Selector Chips (15 menit, 1 jam, 8 jam, 24 jam)
                    Row(
                      children: [
                        _buildDurationChip(
                          label: '15 mnt',
                          minutes: 15,
                          isSelected: selectedMinutes == 15,
                          isDark: isDark,
                          onTap: () => setSheetState(() => selectedMinutes = 15),
                        ),
                        const SizedBox(width: 8),
                        _buildDurationChip(
                          label: '1 jam',
                          minutes: 60,
                          isSelected: selectedMinutes == 60,
                          isDark: isDark,
                          onTap: () => setSheetState(() => selectedMinutes = 60),
                        ),
                        const SizedBox(width: 8),
                        _buildDurationChip(
                          label: '8 jam',
                          minutes: 480,
                          isSelected: selectedMinutes == 480,
                          isDark: isDark,
                          onTap: () => setSheetState(() => selectedMinutes = 480),
                        ),
                        const SizedBox(width: 8),
                        _buildDurationChip(
                          label: '24 jam',
                          minutes: 1440,
                          isSelected: selectedMinutes == 1440,
                          isDark: isDark,
                          onTap: () => setSheetState(() => selectedMinutes = 1440),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Expiry indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text(
                            'Lokasi akan dibagikan selama $durationStr (hingga $expiryTimeStr)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Comment input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: TextField(
                        controller: commentController,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tambah keterangan (opsional)...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Explicit Send Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        'Mulai Berbagi Lokasi ($durationStr)',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        final text = commentController.text.trim();
                        Navigator.pop(sheetContext);
                        _sendLocation(
                          isLive: true,
                          liveDurationMinutes: selectedMinutes,
                          comment: text.isNotEmpty ? text : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  },
).whenComplete(() => commentController.dispose());
  }

  Widget _buildDurationChip({
    required String label,
    required int minutes,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : (isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
                width: isSelected ? 1.8 : 1,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Material(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          title: Row(
                            children: [
                              Text(
                                'Bagikan Lokasi Langsung',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Pilih durasi waktu: 15 menit, 1 jam, 8 jam, atau 24 jam',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          onTap: _showLiveLocationDurationSheet,
                        ),
                        Divider(color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6), height: 16),

                        // Option 2: Current Location (Static)
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
                            'Kirim Lokasi Saat Ini (Statis)',
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
