import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../../security/presentation/screens/key_verification_screen.dart';
import '../../../messaging/presentation/screens/disappearing_messages_screen.dart';
import '../../../messaging/domain/models/message_model.dart';
import '../../domain/conversation_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String contactName;
  final String? userId;
  final String? conversationId;
  final String? phone;
  final String? status;
  final bool isOnline;
  final bool isVerified;
  final String? safetyNumber;
  final String? avatarUrl;
  final int? trustScore;

  const UserProfileScreen({
    super.key,
    required this.contactName,
    this.userId,
    this.conversationId,
    this.phone,
    this.status,
    this.isOnline = true,
    this.isVerified = true,
    this.safetyNumber,
    this.avatarUrl,
    this.trustScore,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isMuted = false;
  bool _isLoading = false;

  String? _resolvedUserId;
  String? _resolvedPhone;
  String? _resolvedStatus;
  String? _resolvedAvatarUrl;
  int _resolvedTrustScore = 100;
  late String _resolvedSafetyNumber;

  int _photoCount = 0;
  int _docCount = 0;
  int _linkCount = 0;
  List<MessageModel> _conversationMediaMessages = [];

  @override
  void initState() {
    super.initState();
    _resolvedUserId = widget.userId;
    _resolvedPhone = widget.phone;
    _resolvedStatus = widget.status;
    _resolvedAvatarUrl = widget.avatarUrl;
    _resolvedTrustScore = widget.trustScore ?? 100;

    // Derive deterministic safety number
    final myId = ApiClient.instance.userId ?? 'me';
    final otherId = _resolvedUserId ?? widget.contactName;
    _resolvedSafetyNumber = widget.safetyNumber ??
        SafetyNumberHelper.deriveSafetyNumber(
          widget.conversationId ?? 'direct',
          '$myId:$otherId',
        );

    _loadConversationMedia();
    _fetchLiveUserProfile();
  }

  Future<void> _loadConversationMedia() async {
    final convId = widget.conversationId;
    if (convId == null || convId.isEmpty) return;

    List<MessageModel> messages =
        ConversationService.instance.getMemoryMessages(convId) ?? [];

    if (messages.isEmpty) {
      messages = await LocalDatabase.instance.getMessages(convId);
    }

    int photos = 0;
    int docs = 0;
    int links = 0;
    final mediaList = <MessageModel>[];

    for (final m in messages) {
      final isPhoto = m.content.startsWith('data:image') ||
          (m.attachmentPath != null &&
              (m.attachmentPath!.endsWith('.png') ||
                  m.attachmentPath!.endsWith('.jpg') ||
                  m.attachmentPath!.endsWith('.jpeg') ||
                  m.attachmentPath!.endsWith('.webp')));
      final isAudio = m.contentType == MessageContentType.voiceNote ||
          m.content.startsWith('data:audio');
      final isDoc = (m.contentType == MessageContentType.attachment && !isPhoto) ||
          m.attachmentName != null ||
          m.content.startsWith('📄') ||
          (m.content.startsWith('data:') && !isPhoto && !isAudio);
      final isLink = m.content.contains('http://') || m.content.contains('https://');

      if (isPhoto || isAudio || isDoc || isLink) {
        mediaList.add(m);
      }
      if (isPhoto) photos++;
      if (isDoc) docs++;
      if (isLink) links++;
    }

    if (mounted) {
      setState(() {
        _photoCount = photos;
        _docCount = docs;
        _linkCount = links;
        _conversationMediaMessages = mediaList;
      });
    }
  }

  Future<void> _fetchLiveUserProfile() async {
    final queryId = _resolvedUserId ?? widget.contactName;
    if (queryId.isEmpty) return;

    // If profile info is already fully known, don't show spinner
    final needsFetch = _resolvedPhone == null ||
        _resolvedPhone!.isEmpty ||
        _resolvedStatus == null ||
        _resolvedStatus!.isEmpty;

    if (needsFetch) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await ConversationService.instance.fetchUserProfile(queryId);
      if (data != null && mounted) {
        setState(() {
          if (data['id'] is String) _resolvedUserId = data['id'];
          if (data['phoneNumber'] is String && (data['phoneNumber'] as String).isNotEmpty) {
            _resolvedPhone = data['phoneNumber'];
          }
          if (data['about'] is String && (data['about'] as String).isNotEmpty) {
            _resolvedStatus = data['about'];
          } else if (data['status'] is String && (data['status'] as String).isNotEmpty) {
            _resolvedStatus = data['status'];
          }
          if (data['avatarUrl'] is String && (data['avatarUrl'] as String).isNotEmpty) {
            _resolvedAvatarUrl = data['avatarUrl'];
          }
          if (data['trustScore'] is num) {
            _resolvedTrustScore = (data['trustScore'] as num).toInt();
          }

          // Re-derive safety number with resolved user ID
          final myId = ApiClient.instance.userId ?? 'me';
          final target = _resolvedUserId ?? queryId;
          _resolvedSafetyNumber = widget.safetyNumber ??
              SafetyNumberHelper.deriveSafetyNumber(
                widget.conversationId ?? 'direct',
                '$myId:$target',
              );
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] _fetchLiveUserProfile error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmBlock() {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Blokir ${widget.contactName}?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Kontak yang diblokir tidak akan dapat memanggil Anda atau mengirim pesan kepada Anda.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final targetId = _resolvedUserId ?? widget.contactName;
              await ConversationService.instance.blockUser(targetId);
              if (mounted) {
                LajuToast.info(context, '${widget.contactName} telah diblokir');
              }
            },
            child: const Text('Blokir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmReport() {
    final targetId = _resolvedUserId ?? widget.userId ?? widget.contactName;
    showReportUserSheet(
      context,
      reportedUserId: targetId,
      reportedUserName: widget.contactName,
      avatarPath: _resolvedAvatarUrl,
    );
  }

  void _showMediaGallerySheet() {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.perm_media_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Media Percakapan (${_conversationMediaMessages.length})',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _conversationMediaMessages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada media dibagikan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Foto, dokumen, dan tautan yang dikirim dalam obrolan ini akan muncul di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _conversationMediaMessages.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          itemBuilder: (context, index) {
                            final m = _conversationMediaMessages[index];
                            final isImage = m.content.startsWith('data:image') ||
                                (m.attachmentPath != null &&
                                    (m.attachmentPath!.endsWith('.png') ||
                                        m.attachmentPath!.endsWith('.jpg') ||
                                        m.attachmentPath!.endsWith('.jpeg') ||
                                        m.attachmentPath!.endsWith('.webp')));
                            final isLink = m.content.contains('http://') || m.content.contains('https://');

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isImage
                                      ? Colors.purple.withValues(alpha: 0.15)
                                      : isLink
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isImage
                                      ? Icons.image_rounded
                                      : isLink
                                          ? Icons.link_rounded
                                          : Icons.insert_drive_file_rounded,
                                  color: isImage
                                      ? Colors.purpleAccent
                                      : isLink
                                          ? Colors.blueAccent
                                          : Colors.orange,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                isImage
                                    ? 'Foto / Gambar'
                                    : (m.attachmentName ?? (isLink ? m.content : 'Dokumen')),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                DateHelper.formatChatDivider(m.timestamp),
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
                              onTap: () {
                                if (isImage) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LajuImageViewer(
                                        imagePath: m.attachmentPath ?? m.content,
                                        title: 'Media ${widget.contactName}',
                                      ),
                                    ),
                                  );
                                } else {
                                  Clipboard.setData(ClipboardData(text: m.content));
                                  LajuToast.info(context, 'Tautan/isi disalin ke clipboard');
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final displayPhone = (_resolvedPhone != null && _resolvedPhone!.trim().isNotEmpty)
        ? _resolvedPhone!.trim()
        : null;
    final displayStatus = (_resolvedStatus != null && _resolvedStatus!.trim().isNotEmpty)
        ? _resolvedStatus!.trim()
        : 'Ada di Laju';

    final totalMedia = _photoCount + _docCount + _linkCount;
    final mediaSubtitle = totalMedia > 0
        ? '$_photoCount Media, $_docCount Dokumen, $_linkCount Tautan'
        : 'Belum ada media dibagikan';

    // Trust score badge color
    Color trustColor;
    String trustStatusLabel;
    if (_resolvedTrustScore >= 90) {
      trustColor = const Color(0xFF10B981);
      trustStatusLabel = context.tr('reportAccountClean');
    } else if (_resolvedTrustScore >= 70) {
      trustColor = const Color(0xFFF59E0B);
      trustStatusLabel = 'Cukup Terpercaya';
    } else {
      trustColor = const Color(0xFFEF4444);
      trustStatusLabel = 'Perlu Diwaspadai';
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Info Kontak',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: textPrimary),
            tooltip: 'Bagikan Kontak',
            onPressed: () {
              final shareText = displayPhone != null
                  ? '${widget.contactName} ($displayPhone)'
                  : '${widget.contactName} (@${widget.contactName})';
              Clipboard.setData(ClipboardData(text: shareText));
              LajuToast.info(context, 'Detail kontak disalin ke clipboard');
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            color: cardColor,
            onSelected: (val) {
              if (val == 'verify') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KeyVerificationScreen(
                      contactName: widget.contactName,
                      safetyNumber: _resolvedSafetyNumber,
                    ),
                  ),
                );
              } else if (val == 'block') {
                _confirmBlock();
              } else if (val == 'report') {
                _confirmReport();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'verify',
                child: Text('Verifikasi Kunci Keamanan', style: TextStyle(color: textPrimary)),
              ),
              PopupMenuItem(
                value: 'block',
                child: const Text('Blokir Kontak', style: TextStyle(color: AppColors.danger)),
              ),
              PopupMenuItem(
                value: 'report',
                child: const Text('Laporkan Akun', style: TextStyle(color: Color(0xFFEF4444))),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // User Header Profile Card
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      children: [
                        ModernAvatar(
                          name: widget.contactName,
                          imagePath: _resolvedAvatarUrl,
                          radius: 46,
                          isOnline: widget.isOnline,
                          isVerified: widget.isVerified,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.contactName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            if (widget.isVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 20, color: AppColors.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayPhone ?? 'Nomor ponsel tersembunyi',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Trust Score Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: trustColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: trustColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 14, color: trustColor),
                              const SizedBox(width: 5),
                              Text(
                                '${context.tr('reportTrustScore')}: $_resolvedTrustScore/100 • $trustStatusLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: trustColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Quick Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickAction(
                              icon: Icons.call_rounded,
                              label: 'Audio',
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ActiveCallScreen(
                                      contactName: widget.contactName,
                                      calleeUserId: _resolvedUserId ?? widget.userId,
                                      contactPhone: _resolvedPhone ?? widget.phone,
                                      isVideo: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.videocam_rounded,
                              label: 'Video',
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ActiveCallScreen(
                                      contactName: widget.contactName,
                                      calleeUserId: _resolvedUserId ?? widget.userId,
                                      contactPhone: _resolvedPhone ?? widget.phone,
                                      isVideo: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildQuickAction(
                              icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
                              label: _isMuted ? 'Muted' : 'Mute',
                              isDark: isDark,
                              isActive: _isMuted,
                              onTap: () async {
                                final newMuted = !_isMuted;
                                setState(() => _isMuted = newMuted);
                                if (widget.conversationId != null) {
                                  await ConversationService.instance.toggleMute(
                                    widget.conversationId!,
                                    newMuted,
                                  );
                                }
                                if (mounted) {
                                  LajuToast.info(
                                    context,
                                    newMuted
                                        ? 'Notifikasi dari ${widget.contactName} dibisukan'
                                        : 'Notifikasi dari ${widget.contactName} diaktifkan',
                                  );
                                }
                              },
                            ),
                            _buildQuickAction(
                              icon: Icons.search_rounded,
                              label: 'Cari',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context, 'search');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bio / Status Card
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Info & Nomor Telepon',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayStatus,
                          style: TextStyle(fontSize: 15, color: textPrimary, height: 1.4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status bio profil',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const Divider(height: 24),
                        InkWell(
                          onTap: () {
                            if (displayPhone != null) {
                              Clipboard.setData(ClipboardData(text: displayPhone));
                              LajuToast.info(context, 'Nomor disalin ke clipboard');
                            } else {
                              LajuToast.info(context, 'Pengguna tidak mencantumkan nomor telepon');
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayPhone ?? 'Tidak ada nomor telepon',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: displayPhone != null ? textPrimary : textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      displayPhone != null
                                          ? 'Ponsel • Ketuk untuk salin'
                                          : 'Ponsel • Nomor tidak dibagikan',
                                      style: TextStyle(fontSize: 12, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (displayPhone != null)
                                const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Security & Encryption Card
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Enkripsi & Keamanan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            'Enkripsi End-to-End',
                            style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            'Pesan dan panggilan dienkripsi secara end-to-end. Ketuk untuk verifikasi nomor keamanan.',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KeyVerificationScreen(
                                  contactName: widget.contactName,
                                  safetyNumber: _resolvedSafetyNumber,
                                ),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 64, color: isDark ? Colors.white10 : Colors.black12),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 20),
                          ),
                          title: Text(
                            'Pesan Sementara',
                            style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                          ),
                          subtitle: Text(
                            'Mati • Pesan baru otomatis dihapus sesuai waktu',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DisappearingMessagesScreen(initialTimer: 'Off'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Media, Links & Docs Card
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.perm_media_rounded, color: Colors.purpleAccent, size: 20),
                      ),
                      title: Text(
                        'Media, Tautan, dan Dokumen',
                        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        mediaSubtitle,
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$totalMedia', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                      onTap: _showMediaGallerySheet,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notification Settings Card
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 20),
                      ),
                      title: Text(
                        'Bisukan Notifikasi',
                        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        _isMuted ? 'Notifikasi saat ini dibisukan' : 'Notifikasi aktif normal',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      value: _isMuted,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        setState(() => _isMuted = val);
                        if (widget.conversationId != null) {
                          await ConversationService.instance.toggleMute(
                            widget.conversationId!,
                            val,
                          );
                        }
                        if (mounted) {
                          LajuToast.info(
                            context,
                            val
                                ? 'Notifikasi dari ${widget.contactName} dibisukan'
                                : 'Notifikasi dari ${widget.contactName} diaktifkan',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Danger Zone Card (Block / Report)
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.block_rounded, color: AppColors.danger),
                          title: Text(
                            'Blokir ${widget.contactName}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                          ),
                          onTap: _confirmBlock,
                        ),
                        Divider(height: 1, indent: 56, color: isDark ? Colors.white10 : Colors.black12),
                        ListTile(
                          leading: const Icon(Icons.thumb_down_alt_rounded, color: AppColors.danger),
                          title: Text(
                            'Laporkan ${widget.contactName}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                          ),
                          onTap: _confirmReport,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppColors.danger
                      : isDark
                          ? Colors.white12
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.danger : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.danger
                    : isDark
                        ? Colors.white70
                        : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
