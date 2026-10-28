import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/status_service.dart';
import '../screens/camera_status_screen.dart';
import '../screens/status_view_screen.dart';
import '../screens/text_status_composer_screen.dart';
import '../screens/video_status_composer_screen.dart';

sealed class _AddStatusAction {}

class _CameraAction extends _AddStatusAction {}

class _TextAction extends _AddStatusAction {}

class _MediaAction extends _AddStatusAction {
  final DeviceRecentMedia media;
  _MediaAction(this.media);
}

class _GalleryAction extends _AddStatusAction {}

class AddStatusSheet extends StatefulWidget {
  const AddStatusSheet({super.key});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(StatusStoryItem postedItem) onStatusPosted,
  }) async {
    final action = await showModalBottomSheet<_AddStatusAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddStatusSheet(),
    );

    if (action == null || !context.mounted) return;

    if (action is _CameraAction) {
      final result = await Navigator.push<StatusStoryItem>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraStatusScreen(),
        ),
      );
      if (result != null && context.mounted) {
        await onStatusPosted(result);
      }
    } else if (action is _TextAction) {
      final result = await Navigator.push<StatusStoryItem>(
        context,
        MaterialPageRoute(
          builder: (_) => const TextStatusComposerScreen(),
        ),
      );
      if (result != null && context.mounted) {
        await onStatusPosted(result);
      }
    } else if (action is _MediaAction) {
      final media = action.media;
      if (media.isVideo) {
        if (media.durationMs > 60000) {
          _showVideoDurationExceededDialog(context, (media.durationMs / 1000).round());
          return;
        }
        final result = await Navigator.push<StatusStoryItem>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoStatusComposerScreen(
              videoPath: media.path,
              durationMs: media.durationMs,
            ),
          ),
        );
        if (result != null && context.mounted) {
          await onStatusPosted(result);
        }
      } else {
        final result = await Navigator.push<StatusStoryItem>(
          context,
          MaterialPageRoute(
            builder: (_) => CameraStatusScreen(initialPhotoPath: media.path),
          ),
        );
        if (result != null && context.mounted) {
          final posted = await StatusService.instance.postStatus(
            type: 'IMAGE',
            content: result.imageAsset ?? media.path,
            caption: result.text,
            backgroundColor: result.backgroundColor,
          );
          if (posted != null && context.mounted) {
            await onStatusPosted(posted);
          }
        }
      }
    } else if (action is _GalleryAction) {
      final path = await DeviceMediaService.openGallery();
      if (path != null && File(path).existsSync() && context.mounted) {
        final result = await Navigator.push<StatusStoryItem>(
          context,
          MaterialPageRoute(
            builder: (_) => CameraStatusScreen(initialPhotoPath: path),
          ),
        );
        if (result != null && context.mounted) {
          final posted = await StatusService.instance.postStatus(
            type: 'IMAGE',
            content: result.imageAsset ?? path,
            caption: result.text,
            backgroundColor: result.backgroundColor,
          );
          if (posted != null && context.mounted) {
            await onStatusPosted(posted);
          }
        }
      }
    }
  }

  static void _showVideoDurationExceededDialog(BuildContext context, int durationSeconds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Durasi Terlalu Panjang',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Batas durasi video status maksimal adalah 1 menit (60 detik).\n\nVideo yang Anda pilih berdurasi $durationSeconds detik. Silakan potong atau pilih video lain dengan durasi ≤ 60 detik.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  State<AddStatusSheet> createState() => _AddStatusSheetState();
}

class _AddStatusSheetState extends State<AddStatusSheet> {
  List<DeviceRecentMedia> _mediaList = [];
  bool _isLoading = true;
  final String _selectedFilter = 'Recents';

  @override
  void initState() {
    super.initState();
    _loadRecentMedia();
  }

  Future<void> _loadRecentMedia() async {
    setState(() => _isLoading = true);
    try {
      final media = await DeviceMediaService.getRecentMedia(limit: 90);
      if (mounted) {
        setState(() {
          _mediaList = media;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleMediaSelection(DeviceRecentMedia media) {
    Navigator.pop(context, _MediaAction(media));
  }

  void _openCamera() {
    Navigator.pop(context, _CameraAction());
  }

  void _openTextStatus() {
    Navigator.pop(context, _TextAction());
  }

  void _openSystemGalleryFallback() {
    Navigator.pop(context, _GalleryAction());
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: screenHeight - topPadding - 16,
      decoration: const BoxDecoration(
        color: Color(0xFF10161D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag bar indicator
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Close Button and Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Add status',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close icon
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Top Quick Tools Row (Text only - Music & Voice removed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildToolButton(
                      icon: Icons.edit_rounded,
                      label: 'Text',
                      onTap: _openTextStatus,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category Header: "Recents" dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedFilter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Media Grid View
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 80),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _mediaList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // First Tile: Integrated Camera (WhatsApp style: tap = photo, hold = video)
                            return InkWell(
                              onTap: _openCamera,
                              child: Container(
                                color: const Color(0xFF18222D),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      color: AppColors.primary,
                                      size: 34,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Camera',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final media = _mediaList[index - 1];
                          return InkWell(
                            onTap: () => _handleMediaSelection(media),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(media.effectiveDisplayPath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 350,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.broken_image_rounded, color: Colors.white30),
                                  ),
                                ),
                                if (media.isVideo)
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.videocam_rounded,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            media.formattedDuration,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Floating Gallery / Album Icon Button on Bottom Right
          Positioned(
            bottom: 24,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openSystemGalleryFallback,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23303F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF222D3A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
