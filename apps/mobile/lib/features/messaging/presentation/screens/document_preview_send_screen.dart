import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class DocumentPreviewResult {
  final String filePath;
  final String fileName;
  final String fileSize;
  final String caption;

  const DocumentPreviewResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.caption,
  });
}

class DocumentPreviewSendScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String fileSize;
  final String recipientName;

  const DocumentPreviewSendScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.recipientName,
  });

  @override
  State<DocumentPreviewSendScreen> createState() => _DocumentPreviewSendScreenState();
}

class _DocumentPreviewSendScreenState extends State<DocumentPreviewSendScreen> {
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
      DocumentPreviewResult(
        filePath: widget.filePath,
        fileName: widget.fileName,
        fileSize: widget.fileSize,
        caption: _captionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileName;
    final parts = fileName.split('.');
    final ext = parts.length > 1 ? parts.last.toUpperCase() : 'FILE';

    Color iconBgColor;
    Color iconColor;
    IconData fileIcon;
    String docTypeLabel;

    switch (ext) {
      case 'PDF':
        iconBgColor = const Color(0xFF7F1D1D).withValues(alpha: 0.4);
        iconColor = const Color(0xFFEF4444);
        fileIcon = Icons.picture_as_pdf_rounded;
        docTypeLabel = 'Dokumen PDF';
        break;
      case 'DOC':
      case 'DOCX':
        iconBgColor = const Color(0xFF1E3A8A).withValues(alpha: 0.4);
        iconColor = const Color(0xFF3B82F6);
        fileIcon = Icons.description_rounded;
        docTypeLabel = 'Dokumen Word';
        break;
      case 'XLS':
      case 'XLSX':
      case 'CSV':
        iconBgColor = const Color(0xFF14532D).withValues(alpha: 0.4);
        iconColor = const Color(0xFF10B981);
        fileIcon = Icons.table_chart_rounded;
        docTypeLabel = 'Spreadsheet Excel';
        break;
      case 'PPT':
      case 'PPTX':
        iconBgColor = const Color(0xFF7C2D12).withValues(alpha: 0.4);
        iconColor = const Color(0xFFF97316);
        fileIcon = Icons.slideshow_rounded;
        docTypeLabel = 'Presentasi';
        break;
      case 'ZIP':
      case 'RAR':
      case '7Z':
        iconBgColor = const Color(0xFF78350F).withValues(alpha: 0.4);
        iconColor = const Color(0xFFF59E0B);
        fileIcon = Icons.folder_zip_rounded;
        docTypeLabel = 'Berkas Arsip';
        break;
      case 'TXT':
        iconBgColor = const Color(0xFF334155).withValues(alpha: 0.4);
        iconColor = const Color(0xFF94A3B8);
        fileIcon = Icons.text_snippet_rounded;
        docTypeLabel = 'Dokumen Teks';
        break;
      default:
        iconBgColor = AppColors.primary.withValues(alpha: 0.2);
        iconColor = AppColors.primary;
        fileIcon = Icons.insert_drive_file_rounded;
        docTypeLabel = 'Berkas Dokumen';
        break;
    }

    final sizeInfo = widget.fileSize.isNotEmpty ? '${widget.fileSize} • $ext' : ext;

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

            // Document Center Preview Card
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Large File Type Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1.5),
                          ),
                          child: Center(
                            child: Icon(fileIcon, color: iconColor, size: 44),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Document Name
                        Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Size and Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            sizeInfo,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Human-readable type label
                        Text(
                          docTypeLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
