import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/core.dart';
import '../../../auth/domain/auth_controller.dart';
import '../../domain/account_controller.dart';

class MyQrCodeScreen extends StatefulWidget {
  final int initialTabIndex;

  const MyQrCodeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MyQrCodeScreen> createState() => _MyQrCodeScreenState();
}

class _MyQrCodeScreenState extends State<MyQrCodeScreen> with TickerProviderStateMixin {
  final GlobalKey _qrCardKey = GlobalKey();
  late final TabController _tabController;
  int _qrVersion = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  String _getContactWebLink() {
    final ctrl = AccountController.instance;
    return 'https://laju.chat/u/${Uri.encodeComponent(ctrl.userName)}';
  }

  void _copyContactLink() {
    HapticFeedback.selectionClick();
    final link = _getContactWebLink();
    Clipboard.setData(ClipboardData(text: link));
    LajuToast.success(context, context.tr('contactLinkCopied'));
  }

  Future<Uint8List> _generateQrCardImage({
    required String name,
    required String qrData,
    required bool isDark,
  }) async {
    const double width = 720;
    const double height = 940;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // 1. Clean Canvas Background
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Main Card Surface (High Contrast)
    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(36, 40, width - 72, height - 80),
      const Radius.circular(32),
    );
    final cardPaint = Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white;
    canvas.drawRRect(cardRect, cardPaint);

    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(cardRect, borderPaint);

    // 3. User Avatar Circle with Initials
    final avatarCenter = const Offset(width / 2, 130);
    final avatarPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(avatarCenter, 42, avatarPaint);

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'L';
    final initialPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 38,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    initialPainter.paint(
      canvas,
      avatarCenter - Offset(initialPainter.width / 2, initialPainter.height / 2),
    );

    // 4. Display Name
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 120);
    namePainter.paint(canvas, Offset(width / 2 - namePainter.width / 2, 190));

    // 5. Subtitle
    final subPainter = TextPainter(
      text: const TextSpan(
        text: 'Kontak Terenkripsi LAJU',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(canvas, Offset(width / 2 - subPainter.width / 2, 228));

    // 6. QR Code Container Box & QR Code Matrix
    const double qrContainerSize = 420;
    const double qrCodeSize = 380;
    final qrBoxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(width / 2, 490), width: qrContainerSize, height: qrContainerSize),
      const Radius.circular(24),
    );
    final qrBoxPaint = Paint()..color = Colors.white;
    canvas.drawRRect(qrBoxRect, qrBoxPaint);
    final qrBoxBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(qrBoxRect, qrBoxBorder);

    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF0F172A),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF0F172A),
      ),
      gapless: true,
    );
    canvas.save();
    canvas.translate(width / 2 - qrCodeSize / 2, 490 - qrCodeSize / 2);
    qrPainter.paint(canvas, const Size(qrCodeSize, qrCodeSize));
    canvas.restore();

    // 7. Footer Text
    final footerPainter = TextPainter(
      text: const TextSpan(
        text: 'laju.chat • Pindai untuk menambahkan teman',
        style: TextStyle(
          color: Color(0xFF059669),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    footerPainter.paint(canvas, Offset(width / 2 - footerPainter.width / 2, 740));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _captureQrBytes() async {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    // If currently on scan code tab, animate to my code tab first
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 250));
    }

    final ctrl = AccountController.instance;
    final myUserId = AuthController.instance.currentUser?.id ?? '';
    final qrData = 'laju://contact?u=${Uri.encodeComponent(ctrl.userName)}&id=$myUserId&v=$_qrVersion';

    // Try RepaintBoundary first
    try {
      final boundary =
          _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final uiImage = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && byteData.lengthInBytes > 0) {
          return byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('[MyQrCodeScreen] Boundary capture notice: $e');
    }

    // Direct Canvas generator fallback (100% guaranteed)
    return await _generateQrCardImage(
      name: ctrl.userName,
      qrData: qrData,
      isDark: isDark,
    );
  }

  Future<void> _shareQrCode() async {
    HapticFeedback.selectionClick();
    final webLink = _getContactWebLink();
    final shareText =
        'Pindai kode QR atau buka tautan untuk menambahkan kontak terenkripsi di LAJU:\n$webLink';

    final imageBytes = await _captureQrBytes();

    final success = await DeviceMediaService.shareContent(
      text: shareText,
      imageBytes: imageBytes,
      title: 'Bagikan Kode QR Kontak LAJU',
    );

    if (mounted) {
      if (!success) {
        await Clipboard.setData(ClipboardData(text: shareText));
        if (mounted) {
          LajuToast.success(context, context.tr('contactLinkCopied'));
        }
      }
    }
  }

  Future<void> _saveQrToGallery() async {
    HapticFeedback.selectionClick();
    final ctrl = AccountController.instance;

    // Direct OS default permission check/request - no custom dialogs
    final hasPerm = await DeviceMediaService.hasStoragePermission();
    if (!hasPerm) {
      final granted = await DeviceMediaService.requestStoragePermission();
      if (!granted) {
        if (mounted) {
          LajuToast.error(context, context.tr('saveGalleryFailed'));
        }
        return;
      }
    }

    final imageBytes = await _captureQrBytes();

    final success = await DeviceMediaService.saveImageToGallery(
      imageBytes: imageBytes,
      fileName: 'laju_qr_${ctrl.userName}.png',
    );

    if (mounted) {
      if (success) {
        LajuToast.success(context, context.tr('qrSavedToGallery'));
      } else {
        LajuToast.error(context, context.tr('saveGalleryFailed'));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmResetQrCode(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          context.tr('resetQrConfirmTitle'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          context.tr('resetQrConfirmDesc'),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _qrVersion++);
              LajuToast.success(context, context.tr('qrResetDone'));
            },
            child: Text(context.tr('reset'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('qrCode'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: isDark ? Colors.white : const Color(0xFF111827)),
            onPressed: _shareQrCode,
            tooltip: context.tr('shareQrCode'),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
            color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
            onSelected: (val) {
              if (val == 'save') {
                _saveQrToGallery();
              } else if (val == 'reset') {
                _confirmResetQrCode(context);
              } else if (val == 'copy') {
                _copyContactLink();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    const Icon(Icons.download_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(context.tr('saveToGallery')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(context.tr('copyContactLink')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(context.tr('resetQrCode')),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          tabs: [
            Tab(text: context.tr('myCode')),
            Tab(text: context.tr('scanCode')),
          ],
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyCodeTab(context, isDark),
              const LajuQrScannerView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCodeTab(BuildContext context, bool isDark) {
    final ctrl = AccountController.instance;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Frosted Glass QR Card Container (Capturable for sharing)
            RepaintBoundary(
              key: _qrCardKey,
              child: LajuGlassCard(
                blurSigma: 20,
                padding: const EdgeInsets.all(22),
                borderRadius: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: ModernAvatar(
                        name: ctrl.userName,
                        radius: 34,
                        isVerified: true,
                        imagePath: ctrl.avatarUrl,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ctrl.userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('lajuContact'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // High-contrast clean white QR tile with embedded LAJU logo
                    Builder(
                      builder: (context) {
                        final myUserId = AuthController.instance.currentUser?.id ?? '';
                        final qrData = 'laju://contact?u=${Uri.encodeComponent(ctrl.userName)}&id=$myUserId&v=$_qrVersion';
                        return LajuQrCodeView(
                          data: qrData,
                          size: 216,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.tr('qrPrivateDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF1F2937),
                      side: BorderSide(
                        color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFD1D5DB),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      context.tr('saveToGallery'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: _saveQrToGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(
                      context.tr('shareQrCode'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: _shareQrCode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
