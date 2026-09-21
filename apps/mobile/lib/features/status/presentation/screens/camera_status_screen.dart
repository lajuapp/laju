import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import 'status_view_screen.dart';
import 'status_privacy_contact_picker_screen.dart';

class CameraStatusScreen extends StatefulWidget {
  final bool isForChatAttachment;
  final String? initialPhotoPath;

  const CameraStatusScreen({
    super.key,
    this.isForChatAttachment = false,
    this.initialPhotoPath,
  });

  @override
  State<CameraStatusScreen> createState() => _CameraStatusScreenState();
}

class _CameraStatusScreenState extends State<CameraStatusScreen>
    with TickerProviderStateMixin {
  final GlobalKey _previewKey = GlobalKey();

  bool _isCaptured = false;
  String? _capturedFilePath;
  String _flashMode = 'off'; // 'off', 'on', 'auto'
  bool _isFrontCamera = false;
  double _zoomLevel = 1.0;
  String _selectedMode = 'STATUS'; // 'STATUS', 'FOTO', 'MALAM'
  final TextEditingController _captionController = TextEditingController();

  // Status Privacy Audience state
  String _privacyMode = 'contacts'; // 'contacts', 'contacts_except', 'only_share'
  Set<String> _excludedContactIds = {};
  Set<String> _onlyShareContactIds = {};

  // Crop & Rotate state
  bool _isCropMode = false;
  int _rotationTurns = 0; // 0 = 0deg, 1 = 90deg, 2 = 180deg, 3 = 270deg
  double? _cropAspectRatio; // null = free/original, 1.0 = 1:1, 4/5 = 4:5, 9/16 = 9:16

  // Text on Photo overlay state
  String? _photoText;
  Color _photoTextColor = Colors.white;
  bool _photoTextHasBackground = true;
  Offset _textOffset = const Offset(0, 0);

  // Tap-to-focus state
  Offset? _focusOffset;
  bool _showFocusReticle = false;
  late AnimationController _focusAnimController;
  late AnimationController _shutterFlashController;
  late AnimationController _flipAnimController;

  // Visual filter presets for realistic simulated viewfinder
  final List<Color> _normalLensGrad = [
    const Color(0xFF111827),
    const Color(0xFF1E293B),
    const Color(0xFF0F172A),
  ];
  final List<Color> _nightLensGrad = [
    const Color(0xFF020617),
    const Color(0xFF0F172A),
    const Color(0xFF022C22),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPhotoPath != null) {
      _capturedFilePath = widget.initialPhotoPath;
      _isCaptured = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openSystemCamera();
      });
    }
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shutterFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _flipAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    _shutterFlashController.dispose();
    _flipAnimController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _onTapViewfinder(TapDownDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _focusOffset = details.localPosition;
      _showFocusReticle = true;
    });
    _focusAnimController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted && _showFocusReticle) {
        setState(() {
          _showFocusReticle = false;
        });
      }
    });
  }

  Future<void> _openSystemCamera() async {
    HapticFeedback.mediumImpact();
    final path = await DeviceMediaService.openCamera();
    if (path != null && mounted && File(path).existsSync()) {
      setState(() {
        _capturedFilePath = path;
        _isCaptured = true;
      });
    } else if (mounted && !_isCaptured) {
      // If user cancelled camera and there is no captured photo to preview, return
      Navigator.pop(context);
    }
  }

  Future<void> _openGalleryPicker() async {
    HapticFeedback.selectionClick();
    // Open real phone gallery directly
    final path = await DeviceMediaService.openGallery();
    if (path != null && mounted) {
      if (widget.isForChatAttachment) {
        Navigator.pop(context, path);
      } else {
        setState(() {
          _capturedFilePath = path;
          _isCaptured = true;
        });
      }
    }
  }

  void _toggleFlash() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_flashMode == 'off') {
        _flashMode = 'auto';
      } else if (_flashMode == 'auto') {
        _flashMode = 'on';
      } else {
        _flashMode = 'off';
      }
    });
  }

  void _toggleCamera() {
    HapticFeedback.mediumImpact();
    if (_isFrontCamera) {
      _flipAnimController.reverse();
    } else {
      _flipAnimController.forward();
    }
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_zoomLevel == 1.0) {
        _zoomLevel = 2.0;
      } else {
        _zoomLevel = 1.0;
      }
    });
  }

  void _setZoom(double zoom) {
    HapticFeedback.selectionClick();
    setState(() {
      _zoomLevel = zoom;
    });
  }

  Future<void> _takePicture() async {
    HapticFeedback.heavyImpact();
    await _openSystemCamera();
  }

  String _getPrivacyLabel() {
    if (widget.isForChatAttachment) return 'Kirim ke Obrolan';
    switch (_privacyMode) {
      case 'contacts_except':
        return _excludedContactIds.isNotEmpty
            ? 'Status (Kecuali ${_excludedContactIds.length})'
            : 'Status (Kontak Saya, Kecuali...)';
      case 'only_share':
        return _onlyShareContactIds.isNotEmpty
            ? 'Status (${_onlyShareContactIds.length} Kontak)'
            : 'Status (Hanya Bagikan Dengan...)';
      case 'contacts':
      default:
        return 'Status (Kontak Saya)';
    }
  }

  void _showPrivacyBottomSheet() {
    if (widget.isForChatAttachment) return;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final excludedCount = _excludedContactIds.length;
            final onlyShareCount = _onlyShareContactIds.length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Privasi Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Siapa yang dapat melihat pembaruan status ini',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Kontak Saya
                    RadioListTile<String>(
                      title: const Text('Kontak Saya', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Semua kontak Anda yang terverifikasi di LAJU', style: TextStyle(fontSize: 12)),
                      value: 'contacts',
                      groupValue: _privacyMode,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _privacyMode = val);
                          setState(() => _privacyMode = val);
                        }
                      },
                    ),

                    // 2. Kontak Saya, Kecuali...
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Expanded(
                            child: Text('Kontak Saya, Kecuali...', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final result = await Navigator.push<Set<String>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StatusPrivacyContactPickerScreen(
                                    mode: PrivacyPickerMode.exclude,
                                    initialSelectedIds: _excludedContactIds,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setSheetState(() => _excludedContactIds = result);
                                setState(() => _excludedContactIds = result);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    excludedCount > 0 ? '$excludedCount dipilih' : 'Pilih',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: excludedCount > 0 ? const Color(0xFFDC2626) : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        excludedCount > 0 ? '$excludedCount kontak disembunyikan' : 'Sembunyikan dari beberapa kontak',
                        style: TextStyle(
                          fontSize: 12,
                          color: excludedCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                        ),
                      ),
                      value: 'contacts_except',
                      groupValue: _privacyMode,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _privacyMode = val);
                          setState(() => _privacyMode = val);
                        }
                      },
                    ),

                    // 3. Hanya Bagikan Dengan...
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Expanded(
                            child: Text('Hanya Bagikan Dengan...', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              final result = await Navigator.push<Set<String>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StatusPrivacyContactPickerScreen(
                                    mode: PrivacyPickerMode.include,
                                    initialSelectedIds: _onlyShareContactIds,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setSheetState(() => _onlyShareContactIds = result);
                                setState(() => _onlyShareContactIds = result);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    onlyShareCount > 0 ? '$onlyShareCount dipilih' : 'Pilih',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        onlyShareCount > 0 ? 'Hanya dibagikan ke $onlyShareCount kontak' : 'Bagikan hanya ke kontak tertentu',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      value: 'only_share',
                      groupValue: _privacyMode,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _privacyMode = val);
                          setState(() => _privacyMode = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTextOverlayEditor() {
    final textEditController = TextEditingController(text: _photoText ?? '');
    Color selectedColor = _photoTextColor;
    bool hasBg = _photoTextHasBackground;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tambah Teks pada Foto',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textEditController,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      color: selectedColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ketik teks di sini...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: hasBg ? Colors.black54 : Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: selectedColor.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          hasBg ? Icons.format_color_fill_rounded : Icons.format_color_text_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Latar Belakang Teks',
                        onPressed: () {
                          setModalState(() => hasBg = !hasBg);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Colors.white,
                              Colors.black,
                              const Color(0xFFFBBF24), // Yellow
                              const Color(0xFF34D399), // Emerald
                              const Color(0xFF38BDF8), // Sky Blue
                              const Color(0xFFEC4899), // Pink
                              const Color(0xFFEF4444), // Red
                            ].map((color) {
                              final isSel = selectedColor == color;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedColor = color),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSel ? Colors.white : Colors.white24,
                                      width: isSel ? 2.5 : 1,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_photoText != null && _photoText!.isNotEmpty)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _photoText = null;
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Hapus Teks', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                      if (_photoText != null && _photoText!.isNotEmpty)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            final val = textEditController.text.trim();
                            setState(() {
                              _photoText = val.isNotEmpty ? val : null;
                              _photoTextColor = selectedColor;
                              _photoTextHasBackground = hasBg;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCropToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.rotate_90_degrees_cw_rounded, color: Colors.white, size: 22),
            tooltip: 'Putar 90°',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _rotationTurns = (_rotationTurns + 1) % 4;
              });
            },
          ),
          Row(
            children: [
              _buildAspectChip('Bebas', null),
              _buildAspectChip('1:1', 1.0),
              _buildAspectChip('4:5', 4 / 5),
              _buildAspectChip('9:16', 9 / 16),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 24),
            tooltip: 'Terapkan Potongan',
            onPressed: () {
              setState(() => _isCropMode = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAspectChip(String label, double? ratio) {
    final isSel = _cropAspectRatio == ratio;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _cropAspectRatio = ratio);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _sendStory() async {
    if (_capturedFilePath == null || !File(_capturedFilePath!).existsSync()) {
      LajuToast.error(context, 'Silakan ambil foto terlebih dahulu');
      return;
    }
    HapticFeedback.mediumImpact();

    String finalImagePath = _capturedFilePath!;

    // If photo was rotated, cropped, or has text overlay, bake it into a rendered image file
    final bool hasEdits = _rotationTurns != 0 ||
        _cropAspectRatio != null ||
        (_photoText != null && _photoText!.trim().isNotEmpty);

    if (hasEdits) {
      try {
        final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final uiImage = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final directory = File(_capturedFilePath!).parent;
            final editedFile = File('${directory.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
            await editedFile.writeAsBytes(byteData.buffer.asUint8List());
            finalImagePath = editedFile.path;
          }
        }
      } catch (e) {
        debugPrint('[CameraStatusScreen] Error baking edited photo: $e');
      }
    }

    final caption = _captionController.text.trim();

    if (widget.isForChatAttachment) {
      Navigator.pop(context, finalImagePath);
      return;
    }

    final story = StatusStoryItem(
      text: caption.isNotEmpty
          ? caption
          : (_photoText?.isNotEmpty == true ? _photoText! : '📷 Foto Kamera'),
      time: 'Baru saja',
      backgroundColor: Colors.black,
      isPhoto: true,
      imageAsset: finalImagePath,
    );

    Navigator.pop(context, story);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isCaptured ? _buildPreviewView() : _buildViewfinderView(),
      ),
    );
  }

  // ==========================================
  // 1. WhatsApp / Modern Camera Viewfinder
  // ==========================================
  Widget _buildViewfinderView() {
    final lensGradient = _selectedMode == 'MALAM' ? _nightLensGrad : _normalLensGrad;

    return Stack(
      children: [
        // Camera Viewport & Tap-to-Focus Area
        Positioned.fill(
          child: GestureDetector(
            onTapDown: _onTapViewfinder,
            onDoubleTap: _onDoubleTap,
            child: AnimatedBuilder(
              animation: _flipAnimController,
              builder: (context, child) {
                final angle = _flipAnimController.value * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: child,
                );
              },
              child: AnimatedScale(
                scale: _zoomLevel,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        lensGradient[1].withValues(alpha: 0.85),
                        lensGradient[0],
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Rule of Thirds Grid Lines (Subtle Framing)
                      Positioned.fill(
                        child: Column(
                          children: [
                            const Spacer(),
                            Container(height: 0.6, color: Colors.white.withValues(alpha: 0.15)),
                            const Spacer(),
                            Container(height: 0.6, color: Colors.white.withValues(alpha: 0.15)),
                            const Spacer(),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: Row(
                          children: [
                            const Spacer(),
                            Container(width: 0.6, color: Colors.white.withValues(alpha: 0.15)),
                            const Spacer(),
                            Container(width: 0.6, color: Colors.white.withValues(alpha: 0.15)),
                            const Spacer(),
                          ],
                        ),
                      ),

                      // Center Crosshair / Viewfinder Reticle
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Front Camera Mirror / Selfie Indicator
                      if (_isFrontCamera)
                        Positioned(
                          top: 100,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.face_retouching_natural_rounded, size: 14, color: AppColors.primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Kamera Depan • Natural Tone',
                                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Animated Tap-to-Focus Reticle
                      if (_showFocusReticle && _focusOffset != null)
                        Positioned(
                          left: _focusOffset!.dx - 36,
                          top: _focusOffset!.dy - 36,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 1.35, end: 1.0).animate(
                              CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOutBack),
                            ),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.amberAccent, width: 1.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 2),
                                      child: Icon(Icons.wb_sunny_rounded, size: 14, color: Colors.amberAccent.withValues(alpha: 0.8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Top Controls: Close, Flash, Native Camera Trigger, Night Mode
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),

              // Middle: Open Device System Camera quick pill
              InkWell(
                onTap: _openSystemCamera,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Kamera HP',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Right: Flash Toggle & Flip
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _flashMode == 'off'
                          ? Icons.flash_off_rounded
                          : (_flashMode == 'on' ? Icons.flash_on_rounded : Icons.flash_auto_rounded),
                      color: _flashMode == 'off' ? Colors.white70 : Colors.amberAccent,
                      size: 26,
                    ),
                    onPressed: _toggleFlash,
                    tooltip: 'Flash',
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 26),
                    onPressed: _toggleCamera,
                    tooltip: 'Ganti Kamera',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Shutter Flash Animation Overlay (Flashes white when photo is taken)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _shutterFlashController,
              builder: (context, child) {
                return Opacity(
                  opacity: _shutterFlashController.value,
                  child: Container(color: Colors.white),
                );
              },
            ),
          ),
        ),

        // Bottom Controls: Zoom bar, Mode Bar, Shutter Button, Gallery
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Zoom Level Selector (0.5x, 1x, 2x, 5x)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [0.5, 1.0, 2.0, 5.0].map((zoom) {
                    final isSel = (_zoomLevel - zoom).abs() < 0.1;
                    return GestureDetector(
                      onTap: () => _setZoom(zoom),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          zoom == 0.5 ? '.5' : '${zoom.toInt()}x',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Camera Mode Selector (STATUS, FOTO, MALAM)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['STATUS', 'FOTO', 'MALAM'].map((mode) {
                  final isSel = _selectedMode == mode;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMode = mode);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text(
                        mode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? AppColors.primary : Colors.white60,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 3. Shutter Action Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gallery Thumbnail / Picker Button
                    InkWell(
                      onTap: _openGalleryPicker,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30, width: 1.5),
                        ),
                        child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                      ),
                    ),

                    // Big Circular Camera Shutter Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Flip Camera Button
                    InkWell(
                      onTap: _toggleCamera,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const Icon(Icons.flip_camera_android_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. Captured Photo Preview & Caption Editor
  // ==========================================
  Widget _buildPreviewView() {
    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 6, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Tutup',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                onPressed: _openSystemCamera,
                tooltip: 'Ambil Ulang Foto',
              ),
              const Spacer(),
              // Crop & Rotate Tool
              IconButton(
                icon: Icon(
                  Icons.crop_rotate_rounded,
                  color: _isCropMode ? AppColors.primary : Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isCropMode = !_isCropMode);
                },
                tooltip: 'Potong & Putar Foto',
              ),
              // Add Text Tool
              IconButton(
                icon: Icon(
                  Icons.title_rounded,
                  color: (_photoText != null && _photoText!.isNotEmpty) ? AppColors.primary : Colors.white,
                  size: 24,
                ),
                onPressed: _openTextOverlayEditor,
                tooltip: 'Tambahkan Teks pada Foto',
              ),
            ],
          ),
        ),

        // Crop Toolbar (Visible when Crop Mode is active)
        if (_isCropMode) _buildCropToolbar(),

        // Photo Preview Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: _capturedFilePath != null && File(_capturedFilePath!).existsSync()
                ? RepaintBoundary(
                    key: _previewKey,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        // Transformed Photo (Rotated & Aspect-Ratio Cropped)
                        Center(
                          child: RotatedBox(
                            quarterTurns: _rotationTurns,
                            child: _cropAspectRatio != null
                                ? AspectRatio(
                                    aspectRatio: _cropAspectRatio!,
                                    child: Image.file(
                                      File(_capturedFilePath!),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.file(
                                    File(_capturedFilePath!),
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),

                        // Draggable Text Overlay
                        if (_photoText != null && _photoText!.trim().isNotEmpty)
                          Positioned(
                            top: 80 + _textOffset.dy,
                            left: 20 + _textOffset.dx,
                            right: 20 - _textOffset.dx,
                            child: GestureDetector(
                              onTap: _openTextOverlayEditor,
                              onPanUpdate: (details) {
                                setState(() {
                                  _textOffset += details.delta;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _photoTextHasBackground
                                      ? Colors.black.withValues(alpha: 0.65)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _photoText!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _photoTextColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.8),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 56,
                          icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                          onPressed: _openSystemCamera,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ketuk untuk membuka kamera perangkat',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Bottom Caption Input & Send Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Caption Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan keterangan...',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Privacy Selector + Send FAB
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Proper Privacy Selector Pill without Lock Emoji
                  InkWell(
                    onTap: _showPrivacyBottomSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _privacyMode == 'contacts'
                                ? Icons.people_alt_outlined
                                : (_privacyMode == 'contacts_except'
                                    ? Icons.person_remove_outlined
                                    : Icons.lock_outline_rounded),
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getPrivacyLabel(),
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          if (!widget.isForChatAttachment) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white70),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Send FAB
                  FloatingActionButton(
                    heroTag: 'fab_send_cam_status',
                    backgroundColor: AppColors.primary,
                    onPressed: _sendStory,
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

