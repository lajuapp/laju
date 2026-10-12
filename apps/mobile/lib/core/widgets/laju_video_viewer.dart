import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'laju_toast.dart';
import 'native_video_player_widget.dart';

class LajuVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? subtitle;
  final DateTime? expiresAt;

  const LajuVideoViewer({
    super.key,
    required this.videoUrl,
    this.title = 'Video',
    this.subtitle,
    this.expiresAt,
  });

  /// Convenient helper to push the full-screen video viewer.
  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String title = 'Video',
    String? subtitle,
    DateTime? expiresAt,
  }) {
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      LajuToast.info(context, 'Status ini sudah kadaluarsa dan tidak dapat diputar lagi.');
      return Future.value();
    }

    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, _, __) => LajuVideoViewer(
          videoUrl: videoUrl,
          title: title,
          subtitle: subtitle,
          expiresAt: expiresAt,
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
  State<LajuVideoViewer> createState() => _LajuVideoViewerState();
}

class _LajuVideoViewerState extends State<LajuVideoViewer> {
  final NativeVideoPlayerController _controller = NativeVideoPlayerController();
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showControls = true;
  bool _hasError = false;

  bool get _isExpired {
    if (widget.expiresAt == null) return false;
    return DateTime.now().isAfter(widget.expiresAt!);
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setMuted(_isMuted);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpired) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'Status Telah Kadaluarsa',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Status video ini telah melewati batas waktu 24 jam dan sudah tidak tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Native Video Player
          GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: Center(
              child: _hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image_rounded, size: 54, color: Colors.white54),
                        SizedBox(height: 12),
                        Text(
                          'Gagal memutar video status',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    )
                  : NativeVideoPlayerWidget(
                      videoUrl: widget.videoUrl,
                      autoPlay: true,
                      loop: true,
                      muted: _isMuted,
                      controller: _controller,
                      onError: (_) {
                        if (mounted) setState(() => _hasError = true);
                      },
                    ),
            ),
          ),

          // Play/Pause Overlay Button
          if (_showControls && !_hasError)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),

          // Top Header Bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC000000),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
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
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  widget.subtitle!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _toggleMute,
                          tooltip: _isMuted ? 'Nyalakan Suara' : 'Bisukan Suara',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
