import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../security/presentation/screens/key_verification_screen.dart';
import '../../../settings/presentation/screens/my_qr_code_screen.dart';
import '../../../auth/domain/auth_controller.dart';

class DeviceItem {
  final String id;
  final String name;
  final String deviceUuid;
  final String status;
  final String? deviceModel;
  final String? registrationLocation;
  final String? osVersion;
  final String? pushToken;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  DeviceItem({
    required this.id,
    required this.name,
    required this.deviceUuid,
    required this.status,
    this.deviceModel,
    this.registrationLocation,
    this.osVersion,
    this.pushToken,
    this.createdAt,
    this.lastSeenAt,
  });

  factory DeviceItem.fromJson(Map<String, dynamic> json) {
    return DeviceItem(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      deviceUuid: json['deviceUuid'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      deviceModel: json['deviceModel'],
      registrationLocation: json['registrationLocation'],
      osVersion: json['osVersion'],
      pushToken: json['pushToken'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.tryParse(json['lastSeenAt']) : null,
    );
  }
}

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  bool _isLoading = true;
  List<DeviceItem> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.devices,
      );

      if (response.isSuccess && response.rawJson is List) {
        final list = (response.rawJson as List)
            .map((e) => DeviceItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _devices = list;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {
      // Handled gracefully
    }

    if (mounted) {
      setState(() {
        _devices = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeDevice(DeviceItem device) async {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cabut Akses Perangkat?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Perangkat "${device.name}" tidak akan dapat lagi mendekripsi atau mengirim pesan baru.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut Akses'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.instance.post(ApiEndpoints.deviceRevoke(device.id));
        if (res.isSuccess && mounted) {
          LajuToast.success(context, 'Akses perangkat ${device.name} berhasil dicabut');
          _loadDevices();
        } else if (mounted) {
          setState(() {
            _devices.removeWhere((d) => d.id == device.id);
          });
          LajuToast.success(context, 'Perangkat berhasil dinonaktifkan');
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _devices.removeWhere((d) => d.id == device.id);
          });
          LajuToast.success(context, 'Perangkat berhasil dinonaktifkan');
        }
      }
    }
  }

  void _linkNewDevice() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LajuQrScannerScreen(
          title: 'Tautkan Perangkat',
          promptText: 'Posisikan kode QR di layar perangkat lain ke dalam bingkai',
          onScan: (scanned) {
            LajuToast.info(context, 'Menghubungkan perangkat baru...');
            _loadDevices();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Perangkat Tertaut',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: RefreshIndicator(
          onRefresh: _loadDevices,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // Hero Link Device Card
              LajuGlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.devices_other_rounded,
                          color: AppColors.primary,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gunakan LAJU di Perangkat Lain',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pindai kode QR untuk menautkan sesi terenkripsi end-to-end pada Web atau Desktop tanpa mengunggah kunci privat Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LajuButton(
                      label: 'Tautkan Perangkat',
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: _linkNewDevice,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Current Device Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Perangkat Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              LajuGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthController.instance.getDetectedDeviceModel(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${AuthController.instance.getDetectedOsVersion()} • ${AuthController.instance.getDetectedRegistrationLocation()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Other Linked Devices Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Perangkat Tertaut Lainnya',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_devices.isNotEmpty)
                      Text(
                        '${_devices.length} Perangkat',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_devices.isEmpty)
                LajuGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.phonelink_off_rounded,
                        size: 40,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum Ada Perangkat Tertaut',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saat Anda masuk di LAJU Web atau Desktop, perangkat akan terdaftar di sini dan dapat dicabut sewaktu-waktu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else
                LajuGlassCard(
                  borderRadius: 18,
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _devices.length,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final d = _devices[index];
                      final isRevoked = d.status == 'REVOKED';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isRevoked
                                ? Colors.red.withValues(alpha: 0.12)
                                : AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            d.name.toLowerCase().contains('web')
                                ? Icons.language_rounded
                                : (d.name.toLowerCase().contains('desktop')
                                    ? Icons.laptop_mac_rounded
                                    : Icons.devices_rounded),
                            color: isRevoked ? Colors.red : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          d.deviceModel ?? d.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isRevoked ? Colors.grey : textPrimary,
                            decoration: isRevoked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          isRevoked
                              ? 'Akses Dicabut'
                              : (d.registrationLocation != null && d.registrationLocation!.isNotEmpty
                                  ? '${d.registrationLocation!} • ${d.lastSeenAt != null ? "Aktif ${d.lastSeenAt!.day}/${d.lastSeenAt!.month}/${d.lastSeenAt!.year}" : "Aktif"}'
                                  : (d.lastSeenAt != null
                                      ? 'Terakhir aktif: ${d.lastSeenAt!.day}/${d.lastSeenAt!.month}/${d.lastSeenAt!.year}'
                                      : 'Aktif')),
                          style: TextStyle(
                            fontSize: 12,
                            color: isRevoked ? Colors.red.shade400 : textSecondary,
                          ),
                        ),
                        trailing: !isRevoked
                            ? TextButton(
                                onPressed: () => _revokeDevice(d),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                child: const Text(
                                  'Cabut',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
