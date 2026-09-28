import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/media_url_resolver.dart';
import '../../../../core/services/local_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/widgets/laju_image_viewer.dart';
import '../../../../core/widgets/laju_toast.dart';
import '../../domain/models/message_model.dart';
import '../widgets/voice_note_player.dart';

class ChatLinkItem {
  final String url;
  final MessageModel message;
  final String senderName;
  final DateTime timestamp;

  ChatLinkItem({
    required this.url,
    required this.message,
    required this.senderName,
    required this.timestamp,
  });
}

class ChatMediaGalleryScreen extends StatefulWidget {
  final String chatTitle;
  final String conversationId;
  final List<MessageModel> messages;

  const ChatMediaGalleryScreen({
    super.key,
    required this.chatTitle,
    required this.conversationId,
    this.messages = const [],
  });

  @override
  State<ChatMediaGalleryScreen> createState() => _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends State<ChatMediaGalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  List<MessageModel> _allMessages = [];
  List<MessageModel> _mediaList = [];
  List<MessageModel> _docList = [];
  List<MessageModel> _audioList = [];
  List<ChatLinkItem> _linkList = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistoricalMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoricalMedia() async {
    // Combine widget messages with local SQLite messages to get complete history
    final cached = await LocalDatabase.instance.getMessages(widget.conversationId);
    final combined = <MessageModel>[...widget.messages, ...cached];
    final deduplicated = MessageModel.deduplicate(combined);

    // Sort descending (newest first for media gallery)
    deduplicated.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final media = <MessageModel>[];
    final docs = <MessageModel>[];
    final audios = <MessageModel>[];
    final links = <ChatLinkItem>[];

    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    for (final m in deduplicated) {
      final isImg = _isImageMessage(m);
      final isAud = _isAudioMessage(m);

      if (isImg) {
        media.add(m);
      } else if (isAud) {
        audios.add(m);
      } else if (m.contentType == MessageContentType.attachment ||
          (m.attachmentName != null && m.attachmentName!.isNotEmpty)) {
        docs.add(m);
      }

      // Extract links from content
      final matches = urlRegex.allMatches(m.content);
      for (final match in matches) {
        final url = match.group(0);
        if (url != null && url.isNotEmpty) {
          links.add(
            ChatLinkItem(
              url: url,
              message: m,
              senderName: m.isOutgoing ? 'Anda' : m.senderName,
              timestamp: m.timestamp,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _allMessages = deduplicated;
        _mediaList = media;
        _docList = docs;
        _audioList = audios;
        _linkList = links;
        _isLoading = false;
      });
    }
  }

  static bool _isImageMessage(MessageModel m) {
    if (m.contentType == MessageContentType.sticker) return false;
    final path = (m.attachmentPath ?? '').trim().toLowerCase();
    final name = (m.attachmentName ?? '').trim().toLowerCase();

    if (path.startsWith('data:image')) return true;
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp')) return true;

    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.gif') ||
        name.endsWith('.bmp')) return true;

    if (m.content.startsWith('data:image')) return true;
    return false;
  }

  static bool _isAudioMessage(MessageModel m) {
    if (m.contentType == MessageContentType.voiceNote) return true;
    final path = (m.attachmentPath ?? '').trim().toLowerCase();
    final name = (m.attachmentName ?? '').trim().toLowerCase();
    if (path.startsWith('data:audio')) return true;
    if (path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.ogg')) return true;
    if (name.endsWith('.m4a') ||
        name.endsWith('.aac') ||
        name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.ogg')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textPrimary),
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Cari berkas atau tautan...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media & Lampiran',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  Text(
                    widget.chatTitle,
                    style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Cari',
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: 'Media (${_mediaList.length})'),
            Tab(text: 'Dokumen (${_docList.length})'),
            Tab(text: 'Audio (${_audioList.length})'),
            Tab(text: 'Tautan (${_linkList.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaTab(isDark, cardColor, textPrimary, textSecondary),
                _buildDocsTab(isDark, cardColor, textPrimary, textSecondary),
                _buildAudioTab(isDark, cardColor, textPrimary, textSecondary),
                _buildLinksTab(isDark, cardColor, textPrimary, textSecondary),
              ],
            ),
    );
  }

  // ── Tab 1: Media (Foto & Gambar) ──────────────────────────────────────────
  Widget _buildMediaTab(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final filtered = _searchQuery.isEmpty
        ? _mediaList
        : _mediaList.where((m) {
            final name = (m.attachmentName ?? '').toLowerCase();
            final content = m.content.toLowerCase();
            final sender = m.senderName.toLowerCase();
            return name.contains(_searchQuery) || content.contains(_searchQuery) || sender.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: _searchQuery.isEmpty ? 'Belum Ada Media' : 'Tidak Ditemukan',
        subtitle: _searchQuery.isEmpty
            ? 'Foto dan gambar yang dibagikan dalam obrolan ini akan tersimpan rapi di sini.'
            : 'Tidak ada foto yang cocok dengan pencarian "$_searchQuery".',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final path = item.attachmentPath ?? item.content;

        Widget imgWidget;
        if (path.startsWith('data:')) {
          try {
            final b64 = path.contains(',') ? path.split(',').last : path;
            imgWidget = Image.memory(base64Decode(b64), fit: BoxFit.cover);
          } catch (_) {
            imgWidget = Container(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            );
          }
        } else if (File(path).existsSync()) {
          imgWidget = Image.file(File(path), fit: BoxFit.cover);
        } else {
          final resolved = resolveMediaUrl(path);
          imgWidget = Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            ),
          );
        }

        return InkWell(
          onTap: () {
            LajuImageViewer.show(
              context,
              imagePath: path,
              title: item.isOutgoing ? 'Anda' : item.senderName,
              subtitle: DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal()),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: imgWidget,
              ),
              // Subtle gradient at bottom showing timestamp
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(item.timestamp.toLocal()),
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      if (item.isOutgoing)
                        const Icon(Icons.done_all_rounded, size: 12, color: Colors.lightBlueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 2: Dokumen (Berkas) ───────────────────────────────────────────────
  Widget _buildDocsTab(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final filtered = _searchQuery.isEmpty
        ? _docList
        : _docList.where((m) {
            final name = (m.attachmentName ?? m.content).toLowerCase();
            return name.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: _searchQuery.isEmpty ? 'Belum Ada Dokumen' : 'Tidak Ditemukan',
        subtitle: _searchQuery.isEmpty
            ? 'Dokumen PDF, Word, Excel, ZIP, dan berkas lainnya akan muncul di sini.'
            : 'Tidak ada dokumen yang cocok dengan pencarian "$_searchQuery".',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final fileName = item.attachmentName ?? (item.content.isNotEmpty ? item.content : 'Dokumen');
        final parts = fileName.split('.');
        final ext = parts.length > 1 ? parts.last.toUpperCase() : 'DOC';

        Color badgeColor;
        Color iconColor;
        IconData badgeIcon;

        switch (ext) {
          case 'PDF':
            badgeColor = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2);
            iconColor = const Color(0xFFEF4444);
            badgeIcon = Icons.picture_as_pdf_rounded;
            break;
          case 'DOC':
          case 'DOCX':
            badgeColor = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE);
            iconColor = const Color(0xFF3B82F6);
            badgeIcon = Icons.description_rounded;
            break;
          case 'XLS':
          case 'XLSX':
          case 'CSV':
            badgeColor = isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
            iconColor = const Color(0xFF16A34A);
            badgeIcon = Icons.table_chart_rounded;
            break;
          case 'ZIP':
          case 'RAR':
          case '7Z':
            badgeColor = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
            iconColor = const Color(0xFFF59E0B);
            badgeIcon = Icons.folder_zip_rounded;
            break;
          default:
            badgeColor = isDark ? const Color(0xFF134E4A).withValues(alpha: 0.4) : AppColors.primaryLight;
            iconColor = AppColors.primaryDark;
            badgeIcon = Icons.insert_drive_file_rounded;
            break;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(badgeIcon, color: iconColor, size: 24),
          ),
          title: Text(
            fileName,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.attachmentSize ?? ext} • ${item.isOutgoing ? 'Anda' : item.senderName} • ${DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal())}',
            style: TextStyle(fontSize: 11.5, color: textSecondary),
          ),
          trailing: IconButton(
            icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
            onPressed: () => _showDocumentActions(context, item, fileName, isDark),
          ),
          onTap: () => _showDocumentActions(context, item, fileName, isDark),
        );
      },
    );
  }

  // ── Tab 3: Audio & Voice Note ─────────────────────────────────────────────
  Widget _buildAudioTab(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final filtered = _searchQuery.isEmpty
        ? _audioList
        : _audioList.where((m) {
            final name = (m.attachmentName ?? m.content).toLowerCase();
            final sender = m.senderName.toLowerCase();
            return name.contains(_searchQuery) || sender.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mic_none_rounded,
        title: _searchQuery.isEmpty ? 'Belum Ada Audio' : 'Tidak Ditemukan',
        subtitle: _searchQuery.isEmpty
            ? 'Pesan suara (voice note) dan file audio yang dibagikan akan tersedia di sini.'
            : 'Tidak ada audio yang cocok dengan pencarian "$_searchQuery".',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final audioPath = item.attachmentPath ?? item.content;
        final durationLabel = item.attachmentSize ?? '0:00';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.attachmentName ?? 'Pesan Suara',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                  Text(
                    '${item.isOutgoing ? 'Anda' : item.senderName} • ${DateFormat('dd MMM, HH:mm').format(item.timestamp.toLocal())}',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: VoiceNotePlayer(
                  filePath: audioPath,
                  durationLabel: durationLabel,
                  isOutgoing: item.isOutgoing,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 4: Tautan (Links) ──────────────────────────────────────────────────
  Widget _buildLinksTab(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final filtered = _searchQuery.isEmpty
        ? _linkList
        : _linkList.where((l) {
            final url = l.url.toLowerCase();
            final content = l.message.content.toLowerCase();
            return url.contains(_searchQuery) || content.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_rounded,
        title: _searchQuery.isEmpty ? 'Belum Ada Tautan' : 'Tidak Ditemukan',
        subtitle: _searchQuery.isEmpty
            ? 'Tautan web yang dibagikan dalam obrolan ini akan dikumpulkan di sini.'
            : 'Tidak ada tautan yang cocok dengan pencarian "$_searchQuery".',
        textPrimary: textPrimary,
        textSecondary: textSecondary,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
      itemBuilder: (context, index) {
        final item = filtered[index];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 24),
          ),
          title: Text(
            item.url,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.message.content.trim() != item.url.trim()) ...[
                const SizedBox(height: 2),
                Text(
                  item.message.content.trim(),
                  style: TextStyle(fontSize: 12, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                '${item.senderName} • ${DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal())}',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: textSecondary,
            tooltip: 'Salin Tautan',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.url));
              LajuToast.info(context, 'Tautan berhasil disalin');
            },
          ),
          onTap: () {
            Clipboard.setData(ClipboardData(text: item.url));
            LajuToast.info(context, 'Tautan disalin ke clipboard');
          },
        );
      },
    );
  }

  // ── Document Action Modal Bottom Sheet ────────────────────────────────────
  void _showDocumentActions(BuildContext context, MessageModel item, String fileName, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.attachmentSize ?? 'Berkas'} • ${DateFormat('dd MMM yyyy, HH:mm').format(item.timestamp.toLocal())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  title: const Text('Salin Nama Berkas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: fileName));
                    LajuToast.info(context, 'Nama berkas disalin ke clipboard');
                  },
                ),
                if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.share_rounded, color: AppColors.primary),
                    title: const Text('Bagikan Lokasi Berkas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: item.attachmentPath!));
                      LajuToast.info(context, 'Tautan berkas disalin ke clipboard');
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Empty State Helper ────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.primary.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
