import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core.dart';
import '../../features/auth/domain/auth_controller.dart';
import '../../features/settings/domain/account_controller.dart';
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
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 600,
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
      final raw = barcode.rawValue ?? barcode.displayValue;
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
    LajuSoundService.triggerVibrate('Pendek');

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
    String? targetUsername;
    String? targetUserId;
    String? targetPhone;
    bool isLajuContact = false;

    final trimmed = rawData.trim();

    if (trimmed.startsWith('laju://contact')) {
      isLajuContact = true;
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        targetUsername = uri.queryParameters['u'] ?? uri.queryParameters['username'];
        targetUserId = uri.queryParameters['id'] ?? uri.queryParameters['userId'];
        targetPhone = uri.queryParameters['phone'] ?? uri.queryParameters['phoneNumber'];
      }
    } else if (trimmed.startsWith('laju://verify-key/')) {
      final uri = Uri.tryParse(trimmed);
      targetUsername = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : trimmed;
      isLajuContact = true;
    } else if (trimmed.startsWith('laju://')) {
      final clean = trimmed.replaceFirst('laju://', '');
      final parts = clean.split('?');
      final hostOrPath = parts.first.replaceAll('/', '').trim();
      if (hostOrPath.isNotEmpty) {
        targetUsername = hostOrPath;
        isLajuContact = true;
      }
    } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        if (uri.queryParameters.containsKey('u') || uri.queryParameters.containsKey('username')) {
          targetUsername = uri.queryParameters['u'] ?? uri.queryParameters['username'];
          targetUserId = uri.queryParameters['id'] ?? uri.queryParameters['userId'];
          targetPhone = uri.queryParameters['phone'];
          isLajuContact = true;
        } else if (uri.path.contains('/contact') || uri.path.contains('/u/')) {
          final segments = uri.pathSegments;
          if (segments.isNotEmpty) {
            targetUsername = segments.last;
            isLajuContact = true;
          }
        }
      }
    } else if (trimmed.startsWith('@')) {
      targetUsername = trimmed.substring(1).trim();
      isLajuContact = true;
    } else if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      // JSON format QR code
      if (trimmed.contains('"u"') || trimmed.contains('"username"') || trimmed.contains('"id"')) {
        isLajuContact = true;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return _ScannedResultBottomSheet(
          rawData: trimmed,
          isLajuContact: isLajuContact,
          targetUsername: targetUsername,
          targetUserId: targetUserId,
          targetPhone: targetPhone,
          scannerContext: context,
        );
      },
    ).whenComplete(() {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _hasDetected = false;
            });
          }
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

enum _SheetStep { resolving, selfScan, userFound, success, invalidQr, generic }

class _ScannedResultBottomSheet extends StatefulWidget {
  final String rawData;
  final bool isLajuContact;
  final String? targetUsername;
  final String? targetUserId;
  final String? targetPhone;
  final BuildContext scannerContext;

  const _ScannedResultBottomSheet({
    required this.rawData,
    required this.isLajuContact,
    this.targetUsername,
    this.targetUserId,
    this.targetPhone,
    required this.scannerContext,
  });

  @override
  State<_ScannedResultBottomSheet> createState() => _ScannedResultBottomSheetState();
}

class _ScannedResultBottomSheetState extends State<_ScannedResultBottomSheet> {
  _SheetStep _step = _SheetStep.resolving;
  String? _resolvedUserId;
  String? _resolvedUsername;
  String? _resolvedDisplayName;
  String? _resolvedAvatarUrl;
  String? _resolvedPhone;
  String? _conversationId;
  String _errorMessage = '';
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _resolveContactProfile();
  }

  Future<void> _resolveContactProfile() async {
    final myId = AuthController.instance.currentUser?.id;
    final myUsername = AccountController.instance.userName.trim().toLowerCase();
    final targetUser = widget.targetUsername?.trim();
    final targetId = widget.targetUserId?.trim();
    final targetPhone = widget.targetPhone?.trim();

    // 1. Detect if self-scan
    if ((targetId != null && targetId.isNotEmpty && targetId == myId) ||
        (targetUser != null && targetUser.isNotEmpty && targetUser.toLowerCase() == myUsername)) {
      if (mounted) {
        setState(() {
          _step = _SheetStep.selfScan;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _step = _SheetStep.resolving;
      });
    }

    try {
      String? foundUserId = (targetId != null && targetId.isNotEmpty) ? targetId : null;
      String? foundUsername = targetUser;
      String? foundAvatar;
      String? foundPhone = targetPhone;

      // Check if direct userId profile can be fetched
      if (foundUserId != null && foundUserId.isNotEmpty) {
        final profile = await ConversationService.instance.fetchUserProfile(foundUserId);
        if (profile != null) {
          foundUsername = profile['username'] ?? foundUsername;
          foundAvatar = profile['avatarUrl'] ?? profile['avatar'];
          foundPhone = profile['phoneNumber'] ?? foundPhone;
        }
      }

      // If no direct userId or username missing, search by username
      if (foundUserId == null && targetUser != null && targetUser.isNotEmpty) {
        final users = await ConversationService.instance.searchUsers(targetUser);
        final exactMatch = users.where((u) => u.username.toLowerCase() == targetUser.toLowerCase()).toList();
        if (exactMatch.isNotEmpty) {
          foundUserId = exactMatch.first.id;
          foundUsername = exactMatch.first.username;
          foundAvatar = exactMatch.first.avatarUrl;
          foundPhone = exactMatch.first.phoneNumber ?? foundPhone;
        } else if (users.isNotEmpty) {
          foundUserId = users.first.id;
          foundUsername = users.first.username;
          foundAvatar = users.first.avatarUrl;
          foundPhone = users.first.phoneNumber ?? foundPhone;
        }
      }

      // If still not found and phone is available, search by phone
      if (foundUserId == null && targetPhone != null && targetPhone.isNotEmpty) {
        final users = await ConversationService.instance.searchUsers(targetPhone);
        if (users.isNotEmpty) {
          foundUserId = users.first.id;
          foundUsername = users.first.username;
          foundAvatar = users.first.avatarUrl;
          foundPhone = users.first.phoneNumber ?? foundPhone;
        }
      }

      // If still not found but string could be plain username/phone
      if (foundUserId == null && !widget.isLajuContact) {
        final candidate = widget.rawData.replaceAll('@', '').trim();
        if (candidate.isNotEmpty && !candidate.contains(' ') && candidate.length < 30) {
          final users = await ConversationService.instance.searchUsers(candidate);
          final match = users.where((u) => u.username.toLowerCase() == candidate.toLowerCase()).toList();
          if (match.isNotEmpty) {
            foundUserId = match.first.id;
            foundUsername = match.first.username;
            foundAvatar = match.first.avatarUrl;
            foundPhone = match.first.phoneNumber ?? foundPhone;
          }
        }
      }

      // If self-scan detected after resolution
      if (foundUserId != null && foundUserId == myId) {
        if (mounted) {
          setState(() {
            _step = _SheetStep.selfScan;
          });
        }
        return;
      }

      if (foundUserId != null) {
        if (mounted) {
          setState(() {
            _resolvedUserId = foundUserId;
            _resolvedUsername = foundUsername ?? 'Teman LAJU';
            _resolvedDisplayName = foundUsername ?? 'Teman LAJU';
            _resolvedAvatarUrl = foundAvatar;
            _resolvedPhone = foundPhone;
            _step = _SheetStep.userFound;
          });
        }
      } else {
        if (mounted) {
          if (widget.isLajuContact || (targetUser != null && targetUser.isNotEmpty)) {
            setState(() {
              _step = _SheetStep.invalidQr;
              _errorMessage = 'Pengguna @${targetUser ?? ''} tidak ditemukan pada server LAJU.';
            });
          } else {
            setState(() {
              _step = _SheetStep.invalidQr;
              _errorMessage = 'Kode QR ini bukan merupakan profil kontak LAJU yang valid.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _SheetStep.invalidQr;
          _errorMessage = 'Gagal memvalidasi kode QR: $e';
        });
      }
    }
  }

  Future<void> _addContactAction() async {
    final uid = _resolvedUserId;
    if (uid == null) return;

    setState(() {
      _isAdding = true;
    });

    try {
      final convId = await ConversationService.instance.createPersonalConversation(uid);
      ConversationService.instance.fetchConversations();

      HapticFeedback.mediumImpact();
      LajuSoundService.triggerVibrate('Pendek');

      if (mounted) {
        setState(() {
          _isAdding = false;
          _conversationId = convId;
          _step = _SheetStep.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdding = false;
          _errorMessage = 'Gagal menambahkan kontak: $e';
          _step = _SheetStep.invalidQr;
        });
      }
    }
  }

  void _navigateToChat() {
    Navigator.pop(context); // Close bottom sheet
    if (widget.scannerContext.mounted) {
      if (Navigator.canPop(widget.scannerContext)) {
        Navigator.pop(widget.scannerContext); // Close QR screen
      }
      Navigator.push(
        widget.scannerContext,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: _conversationId ?? 'conv-$_resolvedUserId',
            title: _resolvedUsername ?? 'Teman',
            isGroup: false,
            avatarUrl: _resolvedAvatarUrl,
          ),
        ),
      );
    }
  }

  void _finishAndClose() {
    Navigator.pop(context); // Close bottom sheet
    if (widget.scannerContext.mounted) {
      if (Navigator.canPop(widget.scannerContext)) {
        Navigator.pop(widget.scannerContext); // Close QR screen
      }
      LajuToast.success(
        widget.scannerContext,
        'Berhasil berteman dengan ${_resolvedUsername ?? 'kontak baru'}!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_step) {
      case _SheetStep.resolving:
        return Column(
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
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Memvalidasi Kode QR...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Memverifikasi profil kontak pada sistem LAJU...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 36),
          ],
        );

      case _SheetStep.selfScan:
        return Column(
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_pin_rounded, color: Color(0xFFF59E0B), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Kode QR Anda Sendiri',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ini adalah kode QR profil Anda sendiri. Berikan kode ini kepada teman agar mereka dapat memindai dan menambahkan Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );

      case _SheetStep.userFound:
        return Column(
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
            // Validity Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'Kode QR Valid • Kontak Terverifikasi',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // User Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  ModernAvatar(
                    name: _resolvedUsername ?? 'Teman',
                    imagePath: _resolvedAvatarUrl,
                    radius: 32,
                    isVerified: true,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resolvedDisplayName ?? _resolvedUsername ?? 'Teman LAJU',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${_resolvedUsername?.toLowerCase()}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                        if (_resolvedPhone != null && _resolvedPhone!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _resolvedPhone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Enkripsi E2EE Siap Aktif',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Primary Button: Tambah ke Kontak
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: _isAdding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.person_add_rounded, size: 20),
                label: Text(
                  _isAdding ? 'Menambahkan Kontak...' : 'Tambah ke Kontak',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                onPressed: _isAdding ? null : _addContactAction,
              ),
            ),
            const SizedBox(height: 10),
            // Secondary Button: Batal
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );

      case _SheetStep.success:
        return Column(
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 50,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Berhasil Ditambahkan!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sekarang Anda sudah berteman dengan @${_resolvedUsername ?? 'kontak baru'}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 19),
                label: const Text(
                  'Mulai Chat Sekarang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                onPressed: _navigateToChat,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Selesai',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                onPressed: _finishAndClose,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );

      case _SheetStep.invalidQr:
        return Column(
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEF4444), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Kode QR Tidak Valid',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Kode QR ini bukan profil kontak LAJU yang valid atau pengguna tidak ditemukan di server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                ),
              ),
              child: SelectableText(
                widget.rawData,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Pindai Ulang', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        );

      case _SheetStep.generic:
        return Column(
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
                widget.rawData,
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
                  Clipboard.setData(ClipboardData(text: widget.rawData));
                  Navigator.pop(context);
                  LajuToast.success(widget.scannerContext, 'Teks berhasil disalin ke papan klip');
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
    }
  }
}
