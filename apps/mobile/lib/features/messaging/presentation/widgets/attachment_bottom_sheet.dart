import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../location/presentation/screens/share_location_screen.dart';

enum AttachmentType {
  document,
  camera,
  gallery,
  audio,
  location,
  contact,
  sticker,
}

class AttachmentResult {
  final AttachmentType type;
  final String title;
  final String? subtitle;
  final String? fileSize;
  final dynamic data;

  AttachmentResult({
    required this.type,
    required this.title,
    this.subtitle,
    this.fileSize,
    this.data,
  });
}

class AttachmentBottomSheet extends StatelessWidget {
  const AttachmentBottomSheet({super.key});

  static Future<AttachmentResult?> show(BuildContext context) {
    return showModalBottomSheet<AttachmentResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const AttachmentBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF374151);
    final handleColor = isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE5E7EB);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attach Content',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Attachment Action Grid (6 modern options)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    bgColor: const Color(0xFF6366F1),
                    labelColor: labelColor,
                    onTap: () => _handleDocumentPick(context),
                  ),
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    bgColor: const Color(0xFFEC4899),
                    labelColor: labelColor,
                    onTap: () => _handleCameraPick(context),
                  ),
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    bgColor: const Color(0xFF8B5CF6),
                    labelColor: labelColor,
                    onTap: () => _handleGalleryPick(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.headphones_rounded,
                    label: 'Audio',
                    bgColor: const Color(0xFFF59E0B),
                    labelColor: labelColor,
                    onTap: () => _handleAudioPick(context),
                  ),
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    bgColor: AppColors.primary,
                    labelColor: labelColor,
                    onTap: () => _handleLocationPick(context),
                  ),
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.person_rounded,
                    label: 'Contact',
                    bgColor: const Color(0xFF0284C7),
                    labelColor: labelColor,
                    onTap: () => _handleContactPick(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentOption(
                    context: context,
                    icon: Icons.emoji_emotions_rounded,
                    label: 'Sticker',
                    bgColor: const Color(0xFF10B981),
                    labelColor: labelColor,
                    onTap: () {
                      Navigator.pop(
                        context,
                        AttachmentResult(
                          type: AttachmentType.sticker,
                          title: 'Stiker',
                        ),
                      );
                    },
                  ),
                  const Opacity(
                    opacity: 0.0,
                    child: IgnorePointer(
                      child: SizedBox(width: 76, height: 86),
                    ),
                  ),
                  const Opacity(
                    opacity: 0.0,
                    child: IgnorePointer(
                      child: SizedBox(width: 76, height: 86),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDocumentPick(BuildContext context) async {
    final doc = await DeviceMediaService.openDocument();
    if (doc != null && context.mounted) {
      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.document,
          title: doc.name,
          fileSize: doc.formattedSize,
          subtitle: 'Berkas Dokumen Asli (${doc.formattedSize})',
          data: doc.path,
        ),
      );
    }
  }

  Future<void> _handleCameraPick(BuildContext context) async {
    // Open real device hardware camera directly (native OS permission handled automatically)
    final path = await DeviceMediaService.openCamera();
    if (path != null && context.mounted && File(path).existsSync()) {
      final file = File(path);
      final bytes = file.lengthSync();
      final sizeStr = bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      final fileName = path.split('/').last;

      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.camera,
          title: fileName,
          fileSize: sizeStr,
          subtitle: 'Foto Kamera Perangkat',
          data: path,
        ),
      );
    }
  }

  Future<void> _handleGalleryPick(BuildContext context) async {
    // Open real phone gallery
    final path = await DeviceMediaService.openGallery();
    if (path != null && context.mounted) {
      final file = File(path);
      final bytes = file.existsSync() ? file.lengthSync() : 0;
      final sizeStr = bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      final fileName = path.split('/').last;

      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.gallery,
          title: fileName,
          fileSize: sizeStr,
          subtitle: 'Foto Galeri HP Terenkripsi',
          data: path,
        ),
      );
    }
  }

  Future<void> _handleAudioPick(BuildContext context) async {
    final aud = await DeviceMediaService.openAudio();
    if (aud != null && context.mounted) {
      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.audio,
          title: aud.name,
          fileSize: aud.formattedSize,
          subtitle: 'Berkas Audio Asli (${aud.formattedSize})',
          data: aud.path,
        ),
      );
    }
  }

  Future<void> _handleLocationPick(BuildContext context) async {
    final granted = await AppPermissionService.requestPermission(
      context,
      type: AppPermissionType.location,
    );
    if (!granted || !context.mounted) return;

    final locResult = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(builder: (context) => const ShareLocationScreen()),
    );
    if (locResult != null && context.mounted) {
      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.location,
          title: locResult.name,
          subtitle: locResult.address,
          data: locResult,
        ),
      );
    }
  }

  Future<void> _handleContactPick(BuildContext context) async {
    final contact = await DeviceMediaService.openContact();
    if (contact != null && context.mounted) {
      final phone = contact.phoneNumber.isNotEmpty ? ' (${contact.phoneNumber})' : '';
      Navigator.pop(
        context,
        AttachmentResult(
          type: AttachmentType.contact,
          title: 'Kontak: ${contact.name}$phone',
          subtitle: 'Kontak Perangkat HP',
          data: contact.phoneNumber,
        ),
      );
    }
  }
}
