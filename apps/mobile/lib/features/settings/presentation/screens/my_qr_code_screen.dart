import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  void _copyContactLink() {
    HapticFeedback.selectionClick();
    final ctrl = AccountController.instance;
    final myUserId = AuthController.instance.currentUser?.id ?? '';
    final link = 'laju://contact?u=${Uri.encodeComponent(ctrl.userName)}&id=$myUserId&v=$_qrVersion';
    Clipboard.setData(ClipboardData(text: link));
    LajuToast.success(context, 'Tautan kontak disalin ke papan klip');
  }

  Future<void> _shareQrCode() async {
    HapticFeedback.selectionClick();
    final ctrl = AccountController.instance;
    final myUserId = AuthController.instance.currentUser?.id ?? '';
    final link = 'laju://contact?u=${Uri.encodeComponent(ctrl.userName)}&id=$myUserId&v=$_qrVersion';
    final shareText =
        'Pindai kode QR saya untuk menambahkan kontak terenkripsi di LAJU:\n$link';

    // If currently on scan code tab, animate to my code tab first so card is in tree
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 250));
    }

    String? imagePath;
    try {
      final boundary =
          _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        if (boundary.debugNeedsPaint) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        final uiImage = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final tempDir = Directory.systemTemp;
          final file = File('${tempDir.path}/laju_qr_${ctrl.userName}.png');
          await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
          if (file.existsSync()) {
            imagePath = file.path;
          }
        }
      }
    } catch (e) {
      debugPrint('[MyQrCodeScreen] Error capturing QR card: $e');
    }

    final success = await DeviceMediaService.shareContent(
      text: shareText,
      filePath: imagePath,
      title: 'Bagikan Kode QR Kontak LAJU',
    );

    if (mounted) {
      if (success) {
        LajuToast.success(context, 'Membuka menu bagikan...');
      } else {
        await Clipboard.setData(ClipboardData(text: shareText));
        LajuToast.success(context, 'Tautan kontak disalin ke papan klip');
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
              if (val == 'reset') {
                _confirmResetQrCode(context);
              } else if (val == 'copy') {
                _copyContactLink();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    const Icon(Icons.copy_rounded, size: 20),
                    const SizedBox(width: 10),
                    const Text('Salin Tautan Kontak'),
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

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: Text(context.tr('shareQrCode'), style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _shareQrCode,
            ),
          ],
        ),
      ),
    );
  }
}
