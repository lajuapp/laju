import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/status_service.dart';

class StatusStoryItem {
  final String? id;
  final String text;
  final String time;
  final Color backgroundColor;
  final String? imageAsset;
  final bool isPhoto;

  const StatusStoryItem({
    this.id,
    required this.text,
    required this.time,
    this.backgroundColor = const Color(0xFF0F3E37),
    this.imageAsset,
    this.isPhoto = false,
  });
}

class StatusViewScreen extends StatefulWidget {
  final String contactName;
  final List<StatusStoryItem> stories;

  const StatusViewScreen({
    super.key,
    required this.contactName,
    required this.stories,
  });

  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _markCurrentViewed();
    _animController.forward();
  }

  void _markCurrentViewed() {
    if (_currentIndex < widget.stories.length) {
      final story = widget.stories[_currentIndex];
      if (story.id != null) {
        StatusService.instance.markStatusViewed(story.id!);
      }
    }
  }


  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _markCurrentViewed();
      _animController.reset();
      _animController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _markCurrentViewed();
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  Widget _buildStoryImage(StatusStoryItem story) {
    final asset = story.imageAsset;
    if (asset != null && asset.startsWith('data:image')) {
      try {
        final b64 = asset.contains(',') ? asset.split(',').last : asset;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    if (asset != null && (asset.startsWith('http://') || asset.startsWith('https://'))) {
      return Image.network(
        asset,
        fit: BoxFit.cover,
      );
    }
    if (asset != null && File(asset).existsSync()) {
      return Image.file(
        File(asset),
        fit: BoxFit.cover,
      );
    }
    if (asset != null && asset.startsWith('assets/')) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            story.backgroundColor,
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tangkapan Kamera Terenkripsi',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: story.backgroundColor,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth * 0.3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _animController.stop(),
        onLongPressEnd: (_) => _animController.forward(),
        child: Stack(
          children: [
            // Dark Gradient Scrim to ensure overlays and text are legible
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.25, 0.7, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),

            // Main Story Content (Photo with caption OR centered text)
              if (story.isPhoto) ...[
                // Photo Background Visual
                Positioned.fill(
                  child: _buildStoryImage(story),
                ),
                if (story.text.isNotEmpty)
                  Positioned(
                    bottom: 84,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        story.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                // Centered Text Story Content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      story.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.45,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Top Bar: Segmented Progress Bars & Contact Info
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented Story Bars (---- if multiple, _____ if 1)
                    Row(
                      children: List.generate(widget.stories.length, (idx) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: EdgeInsets.symmetric(
                              horizontal: widget.stories.length > 1 ? 2.5 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                double fillFactor = 0.0;
                                if (idx < _currentIndex) {
                                  fillFactor = 1.0;
                                } else if (idx == _currentIndex) {
                                  fillFactor = _animController.value;
                                } else {
                                  fillFactor = 0.0;
                                }

                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: fillFactor,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Contact Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        ModernAvatar(
                          name: widget.contactName,
                          radius: 19,
                          isVerified: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.contactName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                story.time,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Section: Reply Pill & Encryption Notice
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply capsule
                    GestureDetector(
                      onTap: () {
                        LajuToast.info(context, 'Replying to ${widget.contactName}...');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Security Label
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded, size: 12, color: Colors.white60),
                        SizedBox(width: 5),
                        Text(
                          'End-to-end encrypted',
                          style: TextStyle(fontSize: 11, color: Colors.white60, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
}
