import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core.dart';
import '../../features/conversations/domain/conversation_service.dart';
import '../../features/messaging/presentation/screens/chat_screen.dart';

/// Reusable QR Scanner widget that embeds a real-time live camera stream,
/// professional viewfinder overlay, torch & flip controls, and gallery picker.
class LajuQrScannerView extends StatefulWidget {
  final ValueChanged<String>? onScan;
  final String? promptText;
  final bool autoPopOnScan;

  const LajuQrScannerView({
    super.key,
    this.onScan,
    this.promptText,
    this.autoPopOnScan = false,
  });

  @override
  State<LajuQrScannerView> createState() => _LajuQrScannerViewState();
}

class _LajuQrScannerViewState extends State<LajuQrScannerView>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserController;
  bool _isTorchOn = false;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    HapticFeedback.selectionClick();
    try {
      await _scannerController.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    HapticFeedback.selectionClick();
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _handleDetected(raw.trim());
        break;
      }
    }
  }

  void _handleDetected(String rawData) {
    if (_hasDetected) return;
    _hasDetected = true;
    HapticFeedback.heavyImpact();

    if (widget.onScan != null) {
      widget.onScan!(rawData);
    }

    if (widget.autoPopOnScan && mounted) {
      Navigator.pop(context, rawData);
      return;
    }

    if (widget.onScan == null) {
      _showScannedResultSheet(context, rawData);
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();
    final path = await DeviceMediaService.openGallery();
    if (path != null && mounted) {
      try {
        final capture = await _scannerController.analyzeImage(path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final raw = capture.barcodes.first.rawValue;
          if (raw != null && raw.trim().isNotEmpty) {
            _handleDetected(raw.trim());
            return;
          }
        }
        if (mounted) {
          LajuToast.error(context, 'Tidak ada kode QR yang ditemukan pada foto');
        }
      } catch (e) {
        if (mounted) {
          LajuToast.error(context, 'Gagal memproses gambar galeri');
        }
      }
    }
  }

  void _showScannedResultSheet(BuildContext context, String rawData) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    String displayName = rawData;
    String? username;
    bool isLajuContact = false;

    if (rawData.startsWith('laju://verify-key/')) {
      final uri = Uri.tryParse(rawData);
      displayName = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : rawData;
      isLajuContact = true;
    } else if (rawData.startsWith('laju://')) {
      final clean = rawData.replaceFirst('laju://', '');
      final parts = clean.split('?');
      username = parts.first;
      displayName = username;
      isLajuContact = true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                if (isLajuContact) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Kontak LAJU',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ModernAvatar(
                    name: displayName,
                    radius: 36,
                    isVerified: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${username ?? displayName}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('Tambah Kontak', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final targetUsername = username ?? displayName;
                            try {
                              final users = await ConversationService.instance.searchUsers(targetUsername);
                              final match = users.where((u) =>
                                u.username.toLowerCase() == targetUsername.toLowerCase()
                              ).toList();
                              if (match.isNotEmpty) {
                                await ConversationService.instance.createPersonalConversation(match.first.id);
                                if (context.mounted) {
                                  LajuToast.success(context, '$targetUsername berhasil ditambahkan!');
                                }
                              } else {
                                if (context.mounted) {
                                  LajuToast.error(context, 'Pengguna $targetUsername tidak ditemukan');
                                }
                              }
                            } catch (_) {
                              if (context.mounted) {
                                LajuToast.error(context, 'Gagal menambahkan kontak');
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('Kirim Pesan', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final targetUsername = username ?? displayName;
                            try {
                              final users = await ConversationService.instance.searchUsers(targetUsername);
                              final match = users.where((u) =>
                                u.username.toLowerCase() == targetUsername.toLowerCase()
                              ).toList();
                              if (match.isNotEmpty) {
                                final convId = await ConversationService.instance
                                    .createPersonalConversation(match.first.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        conversationId: convId ?? 'conv-${match.first.id}',
                                        title: targetUsername,
                                        isGroup: false,
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  LajuToast.error(context, 'Pengguna $targetUsername tidak ditemukan');
                                }
                              }
                            } catch (_) {
                              if (context.mounted) {
                                LajuToast.error(context, 'Gagal membuka obrolan');
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Hasil Pindai Kode QR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: SelectableText(
                      rawData,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Salin Hasil Pindai', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawData));
                        Navigator.pop(ctx);
                        LajuToast.success(context, 'Teks berhasil disalin ke papan klip');
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _hasDetected = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Live Camera Stream
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 52),
                        const SizedBox(height: 14),
                        const Text(
                          'Kamera Sedang Memuat...',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jika baru menambahkan package, jalankan ulang aplikasi (stop & flutter run) agar binary kamera terpasang di HP.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Muat Ulang Kamera', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _scannerController.start(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Dark Overlay with Cutout
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                scanAreaSize: 260,
                borderRadius: 28,
              ),
            ),
          ),

          // 3. Viewfinder Controls, HUD, and Laser
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Top Controls: Torch & Camera Switch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: _isTorchOn
                              ? AppColors.primary
                              : Colors.black.withValues(alpha: 0.5),
                          foregroundColor: _isTorchOn ? Colors.black : Colors.white,
                        ),
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          size: 22,
                        ),
                        onPressed: _toggleTorch,
                        tooltip: 'Senter',
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flip_camera_ios_rounded, size: 22),
                        onPressed: _switchCamera,
                        tooltip: 'Putar Kamera',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Central Viewfinder Frame & Animated Laser
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _hasDetected ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(
                      children: [
                        // Viewfinder 4 Corner Brackets
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _buildCornerBracket(isTop: true, isLeft: true),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _buildCornerBracket(isTop: true, isLeft: false),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: _buildCornerBracket(isTop: false, isLeft: true),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: _buildCornerBracket(isTop: false, isLeft: false),
                        ),

                        // Animated sweeping laser line
                        AnimatedBuilder(
                          animation: _laserController,
                          builder: (context, child) {
                            return Positioned(
                              top: 20 + (_laserController.value * 210),
                              left: 16,
                              right: 16,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.primary,
                                      Color(0xFF38BDF8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Clean alignment guidance text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.promptText ?? context.tr('alignQrCode'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Controls: Pindai dari Galeri
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: Text(
                        context.tr('scanFromGallery'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _pickFromGallery,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBracket({required bool isTop, required bool isLeft}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: AppColors.primary, width: 3.5) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: AppColors.primary, width: 3.5) : BorderSide.none,
          left: isLeft ? const BorderSide(color: AppColors.primary, width: 3.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: AppColors.primary, width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }
}

/// Standalone Full-Screen QR Scanner
class LajuQrScannerScreen extends StatelessWidget {
  final String title;
  final String? promptText;
  final ValueChanged<String>? onScan;

  const LajuQrScannerScreen({
    super.key,
    this.title = 'Pindai Kode QR',
    this.promptText,
    this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18.5,
          ),
        ),
      ),
      body: LajuQrScannerView(
        promptText: promptText,
        onScan: onScan,
        autoPopOnScan: onScan != null,
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final double borderRadius;

  _ScannerOverlayPainter({
    required this.scanAreaSize,
    this.borderRadius = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final scanRect = Rect.fromCenter(
      center: center,
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius)));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
