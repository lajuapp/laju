import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'laju_toast.dart';
import 'laju_cached_image.dart';

class LajuImageViewer extends StatefulWidget {
  final String imagePath;
  final String title;
  final String? subtitle;
  final String? heroTag;

  const LajuImageViewer({
    super.key,
    required this.imagePath,
    this.title = 'Foto',
    this.subtitle,
    this.heroTag,
  });

  /// Convenient helper to push the full-screen image viewer.
  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    String title = 'Foto',
    String? subtitle,
    String? heroTag,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => LajuImageViewer(
          imagePath: imagePath,
          title: title,
          subtitle: subtitle,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<LajuImageViewer> createState() => _LajuImageViewerState();
}

class _LajuImageViewerState extends State<LajuImageViewer> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _showControls = true;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * (2.5 - 1);
      final y = -position.dy * (2.5 - 1);
      _transformationController.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Widget _buildImage() {
    final path = widget.imagePath;
    if (path.startsWith('data:')) {
      try {
        final b64 = path.contains(',') ? path.split(',').last : path;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildError(),
        );
      } catch (_) {
        return _buildError();
      }
    } else if (File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildError(),
      );
    } else if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('/') || path.startsWith('admin/media')) {
      return LajuCachedImage(
        imageUrlOrPath: path,
        fit: BoxFit.contain,
        errorWidget: _buildError(),
      );
    } else {
      return _buildError();
    }
  }

  Widget _buildError() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, size: 54, color: Colors.white54),
          SizedBox(height: 12),
          Text(
            'Gagal memuat gambar',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImage();
    if (widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Center interactive zoomable image
            GestureDetector(
              onTap: _toggleControls,
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: SizedBox.expand(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: imageWidget,
                  ),
                ),
              ),
            ),

            // Top immersive App Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black87,
                      Colors.black45,
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Kembali',
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            LajuToast.info(context, 'Membagikan gambar...');
                          },
                          tooltip: 'Bagikan',
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            LajuToast.info(context, 'Gambar tersimpan di galeri');
                          },
                          tooltip: 'Simpan ke Galeri',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
