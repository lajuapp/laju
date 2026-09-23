import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ImagePreviewResult {
  final String imagePath;
  final String caption;

  const ImagePreviewResult({
    required this.imagePath,
    required this.caption,
  });
}

class ImagePreviewSendScreen extends StatefulWidget {
  final String imagePath;
  final String recipientName;

  const ImagePreviewSendScreen({
    super.key,
    required this.imagePath,
    required this.recipientName,
  });

  @override
  State<ImagePreviewSendScreen> createState() => _ImagePreviewSendScreenState();
}

class _ImagePreviewSendScreenState extends State<ImagePreviewSendScreen> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  void _handleSend() {
    Navigator.pop(
      context,
      ImagePreviewResult(
        imagePath: widget.imagePath,
        caption: _captionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kirim ke',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        Text(
                          widget.recipientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Image Preview (Interactive Viewer with Pan & Zoom)
            Expanded(
              child: Center(
                child: file.existsSync()
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.5,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
              ),
            ),

            // Bottom Caption Bar & Send Action
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: Colors.black.withValues(alpha: 0.75),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Caption Input Field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _captionFocus,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Tambah keterangan...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send Button
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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
