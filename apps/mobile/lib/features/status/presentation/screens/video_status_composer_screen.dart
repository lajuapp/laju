import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../../core/widgets/native_video_player_widget.dart';
import '../../domain/status_service.dart';
import 'status_view_screen.dart';

class VideoStatusComposerScreen extends StatefulWidget {
  final String videoPath;
  final int durationMs;

  const VideoStatusComposerScreen({
    super.key,
    required this.videoPath,
    required this.durationMs,
  });

  @override
  State<VideoStatusComposerScreen> createState() => _VideoStatusComposerScreenState();
}

class _VideoStatusComposerScreenState extends State<VideoStatusComposerScreen> {
  final TextEditingController _captionController = TextEditingController();
  final NativeVideoPlayerController _videoController = NativeVideoPlayerController();
  bool _isMuted = false;
  bool _isUploading = false;
  int _actualDurationMs = 0;

  @override
  void initState() {
    super.initState();
    _actualDurationMs = widget.durationMs;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSend() async {
    if (_isUploading) return;
    HapticFeedback.mediumImpact();
    setState(() => _isUploading = true);

    try {
      final caption = _captionController.text.trim();
      final posted = await StatusService.instance.postStatus(
        type: 'VIDEO',
        content: widget.videoPath,
        caption: caption.isNotEmpty ? caption : null,
      );

      if (!mounted) return;
      if (posted != null) {
        Navigator.pop(context, posted);
      } else {
        // Fallback local story item if offline or created locally
        final localStory = StatusStoryItem(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          text: caption,
          time: 'Baru saja',
          imageAsset: widget.videoPath,
          videoUrl: widget.videoPath,
          isPhoto: true,
          isVideo: true,
          createdAt: DateTime.now(),
        );
        Navigator.pop(context, localStory);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        LajuToast.error(context, 'Gagal mengunggah video status: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDuration = _formatDuration(_actualDurationMs);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Native Video Player Preview
          Positioned.fill(
            child: NativeVideoPlayerWidget(
              videoUrl: widget.videoPath,
              autoPlay: true,
              loop: true,
              muted: _isMuted,
              controller: _videoController,
              onPrepared: (d) {
                if (mounted && d > 0) {
                  setState(() => _actualDurationMs = d);
                }
              },
            ),
          ),

          // Top Gradient Scrim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top Header Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    // Video duration chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$formattedDuration / 1:00',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Mute/Unmute Toggle
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isMuted = !_isMuted);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Caption & Send Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Tambah keterangan status video...',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _isUploading ? null : _handleSend,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
