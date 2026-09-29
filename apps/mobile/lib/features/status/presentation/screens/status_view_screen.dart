import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../../core/widgets/native_video_player_widget.dart';
import '../../domain/status_service.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../messaging/domain/models/message_model.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';

class StatusViewerItem {
  final String userId;
  final String username;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime viewedAt;
  final String? reaction;

  const StatusViewerItem({
    required this.userId,
    required this.username,
    this.phoneNumber,
    this.avatarUrl,
    required this.viewedAt,
    this.reaction,
  });

  factory StatusViewerItem.fromJson(Map<String, dynamic> json) {
    final viewerUser = json['viewer'] as Map<String, dynamic>? ?? {};
    DateTime vTime = DateTime.now();
    if (json['viewedAt'] != null) {
      try {
        vTime = DateHelper.parseUtc(json['viewedAt'] as String);
      } catch (_) {}
    }
    return StatusViewerItem(
      userId: (json['viewerId'] ?? viewerUser['id'] ?? '') as String,
      username: (viewerUser['username'] ?? 'Pengguna') as String,
      phoneNumber: viewerUser['phoneNumber'] as String?,
      avatarUrl: (viewerUser['avatarUrl'] ?? json['avatarUrl']) as String?,
      viewedAt: vTime,
      reaction: json['reaction'] as String?,
    );
  }
}

class StatusStoryItem {
  final String? id;
  final String text;
  final String time;
  final Color backgroundColor;
  final String? imageAsset;
  final bool isPhoto;
  final bool isVideo;
  final String? videoUrl;
  final List<StatusViewerItem> viewers;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? actionTitle;
  final String? actionUrl;
  final bool isOfficial;

  const StatusStoryItem({
    this.id,
    required this.text,
    required this.time,
    this.backgroundColor = const Color(0xFF0F3E37),
    this.imageAsset,
    this.isPhoto = false,
    this.isVideo = false,
    this.videoUrl,
    this.viewers = const [],
    this.createdAt,
    this.expiresAt,
    this.actionTitle,
    this.actionUrl,
    this.isOfficial = false,
  });

  bool get isExpired {
    if (expiresAt != null) {
      return DateTime.now().isAfter(expiresAt!);
    }
    if (createdAt != null) {
      return DateTime.now().difference(createdAt!).inHours >= 24;
    }
    return false;
  }
}

class StatusViewScreen extends StatefulWidget {
  final String contactName;
  final String? avatarUrl;
  final List<StatusStoryItem> stories;
  final bool isMyStatus;
  final bool isOfficial;
  final String? contactUserId;
  final VoidCallback? onStatusDeleted;

  const StatusViewScreen({
    super.key,
    required this.contactName,
    this.avatarUrl,
    required this.stories,
    this.isMyStatus = false,
    this.isOfficial = false,
    this.contactUserId,
    this.onStatusDeleted,
  });

  @override
  State<StatusViewScreen> createState() => _StatusViewScreenState();
}

class _StatusViewScreenState extends State<StatusViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<StatusStoryItem> _stories;
  int _currentIndex = 0;
  bool _isPopping = false;

  final NativeVideoPlayerController _videoPlayerController = NativeVideoPlayerController();
  bool _isVideoMuted = false;

  @override
  void initState() {
    super.initState();
    _stories = List<StatusStoryItem>.from(widget.stories);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isPopping && mounted) {
          _nextStory();
        }
      }
    });

    if (_stories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _safeClose());
    } else {
      _markCurrentViewed();
      _startStoryPlayback();
    }
  }

  void _startStoryPlayback() {
    if (_stories.isEmpty || _currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    _animController.reset();
    if (story.isVideo) {
      _animController.duration = const Duration(seconds: 15);
    } else {
      _animController.duration = const Duration(seconds: 5);
    }
    _animController.forward();
    _preloadUpcomingStories();
  }

  void _preloadUpcomingStories() {
    if (_currentIndex + 1 < _stories.length) {
      final next = _stories[_currentIndex + 1];
      if (next.isPhoto && next.imageAsset != null && next.imageAsset!.isNotEmpty) {
        LajuMediaCacheManager.instance.preload(next.imageAsset!);
      }
    }
  }

  void _onVideoPrepared(int durationMs) {
    if (!mounted || _stories.isEmpty || _currentIndex >= _stories.length) return;
    final story = _stories[_currentIndex];
    if (story.isVideo && durationMs > 0) {
      final safeMs = durationMs.clamp(1000, 60000);
      final currentProgress = _animController.value;
      _animController.duration = Duration(milliseconds: safeMs);
      _animController.forward(from: currentProgress);
    }
  }

  void _onVideoCompleted() {
    if (!_isPopping && mounted) {
      _nextStory();
    }
  }

  void _markCurrentViewed() {
    if (_stories.isNotEmpty && _currentIndex < _stories.length) {
      final story = _stories[_currentIndex];
      if (story.id != null) {
        if (widget.isOfficial || story.isOfficial) {
          StatusService.instance.markOfficialStatusViewed(story.id!);
        } else {
          StatusService.instance.markStatusViewed(story.id!);
        }
      }
    }
  }

  void _openActionUrl(String url) async {
    _animController.stop();
    _videoPlayerController.pause();
    try {
      await const MethodChannel('com.laju/device').invokeMethod('openUrl', {'url': url});
    } catch (e) {
      debugPrint('[StatusViewScreen] openUrl error: $e');
    }
    if (!_isPopping && mounted) {
      _animController.forward();
      _videoPlayerController.play();
    }
  }

  @override
  void dispose() {
    _isPopping = true;
    _animController.stop();
    _animController.dispose();
    super.dispose();
  }

  void _safeClose() {
    if (_isPopping) return;
    _isPopping = true;
    _animController.stop();
    _videoPlayerController.pause();
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _nextStory() {
    if (_isPopping || _stories.isEmpty) return;
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _markCurrentViewed();
      _startStoryPlayback();
    } else {
      _safeClose();
    }
  }

  void _previousStory() {
    if (_isPopping || _stories.isEmpty) return;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _markCurrentViewed();
      _startStoryPlayback();
    } else {
      _startStoryPlayback();
    }
  }

  void _showMoreOptions() {
    _animController.stop();

    if (widget.isMyStatus) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  title: const Text(
                    'Hapus Status',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteStatus();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded, color: Colors.white),
                  title: const Text(
                    'Teruskan Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_stories.isNotEmpty && _currentIndex < _stories.length) {
                      _forwardStatus(_stories[_currentIndex]);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ).then((_) {
        if (!_isPopping && mounted) {
          _animController.forward();
        }
      });
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.forward_rounded, color: Colors.white),
                  title: const Text(
                    'Teruskan Status',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (_stories.isNotEmpty && _currentIndex < _stories.length) {
                      _forwardStatus(_stories[_currentIndex]);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat_outlined, color: Colors.white),
                  title: Text(
                    'Kirim pesan ke ${widget.contactName}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openChatWithQuoted(null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.volume_off_outlined, color: Colors.white70),
                  title: Text(
                    'Bisukan status ${widget.contactName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    LajuToast.info(context, 'Pembaruan status dari ${widget.contactName} dibisukan');
                    if (!_isPopping && mounted) _animController.forward();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ).then((_) {
        if (!_isPopping && mounted) {
          _animController.forward();
        }
      });
    }
  }

  void _confirmDeleteStatus() {
    _animController.stop();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus pembaruan status ini?',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Pembaruan status ini juga akan dihapus untuk semua orang yang menerimanya.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              if (!_isPopping && mounted) _animController.forward();
            },
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await _performDeleteCurrentStatus();
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteCurrentStatus() async {
    if (_stories.isEmpty) return;
    final storyToDelete = _stories[_currentIndex];

    if (storyToDelete.id != null) {
      await StatusService.instance.deleteStatus(storyToDelete.id!);
      StatusService.instance.cachedMyStatuses.removeWhere((s) => s.id == storyToDelete.id);
    }
    widget.onStatusDeleted?.call();

    if (!mounted) return;

    setState(() {
      _stories.removeAt(_currentIndex);
      if (_currentIndex >= _stories.length) {
        _currentIndex = _stories.length - 1;
      }
    });

    if (_stories.isEmpty) {
      LajuToast.info(context, 'Status berhasil dihapus');
      _safeClose();
    } else {
      LajuToast.info(context, 'Status berhasil dihapus');
      _markCurrentViewed();
      _animController.reset();
      _animController.forward();
    }
  }

  MessageModel _buildQuotedStatusMessage(StatusStoryItem story) {
    return MessageModel(
      id: 'status-${story.id ?? DateTime.now().millisecondsSinceEpoch}',
      conversationId: 'status',
      senderName: 'Status • ${widget.contactName}',
      content: story.isPhoto
          ? (story.text.isNotEmpty ? story.text : 'Foto')
          : story.text,
      contentType: story.isPhoto ? MessageContentType.attachment : MessageContentType.text,
      attachmentPath: story.isPhoto ? story.imageAsset : null,
      attachmentName: story.isPhoto ? 'status_photo.jpg' : null,
      timestamp: DateTime.now(),
      isOutgoing: false,
    );
  }

  Future<String> _resolveConversationId() async {
    final convs = ConversationService.instance.conversationsNotifier.value;
    final match = convs.where((c) {
      if (c.isGroup) return false;
      if (widget.contactUserId != null && widget.contactUserId!.isNotEmpty && c.id.contains(widget.contactUserId!)) {
        return true;
      }
      return c.title.trim().toLowerCase() == widget.contactName.trim().toLowerCase();
    }).toList();

    if (match.isNotEmpty) {
      return match.first.id;
    }

    if (widget.contactUserId != null && widget.contactUserId!.isNotEmpty) {
      try {
        final backendId = await ConversationService.instance.createPersonalConversation(widget.contactUserId!);
        if (backendId != null && backendId.isNotEmpty) {
          return backendId;
        }
      } catch (_) {}
    }

    return 'conv-${widget.contactUserId ?? widget.contactName.toLowerCase().replaceAll(' ', '_')}';
  }

  void _openChatWithQuoted(MessageModel? quotedMsg) async {
    _isPopping = true;
    _animController.stop();

    final convId = await _resolveConversationId();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          title: widget.contactName,
          avatarUrl: widget.avatarUrl,
          contactUserId: widget.contactUserId,
          initialReplyTo: quotedMsg,
        ),
      ),
    );
  }

  String _formatViewerTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Hari ini $hour:$minute';
    }
    return 'Kemarin';
  }

  void _sendQuickReaction(String emoji, MessageModel quotedMsg, StatusStoryItem story) async {
    // 1. Record reaction to backend
    if (story.id != null) {
      StatusService.instance.reactToStatus(story.id!, emoji);
    }

    // 2. Send background chat message to contact's conversation
    try {
      final convId = await _resolveConversationId();
      await ConversationService.instance.sendMessage(
        conversationId: convId,
        text: emoji,
        replyTo: quotedMsg,
      );
    } catch (_) {}

    // 3. Show feedback and resume playback
    if (mounted) {
      LajuToast.success(context, 'Reaksi $emoji terkirim');
      if (!_isPopping) {
        _animController.forward();
      }
    }
  }

  void _sendReplyMessage(String text, MessageModel quotedMsg) async {
    try {
      final convId = await _resolveConversationId();
      await ConversationService.instance.sendMessage(
        conversationId: convId,
        text: text,
        replyTo: quotedMsg,
      );
    } catch (_) {}

    if (mounted) {
      LajuToast.success(context, 'Balasan terkirim');
      if (!_isPopping) {
        _animController.forward();
      }
    }
  }

  void _showViewersSheet(StatusStoryItem story) async {
    _animController.stop();

    List<StatusViewerItem> currentViewers = List<StatusViewerItem>.from(story.viewers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Lazy load latest viewers from server
            if (story.id != null && currentViewers.isEmpty) {
              StatusService.instance.getStatusViewers(story.id!).then((fresh) {
                if (ctx.mounted && fresh.isNotEmpty) {
                  setSheetState(() {
                    currentViewers = fresh;
                  });
                }
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header with count & action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF00A884), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentViewers.isEmpty
                                  ? 'Belum ada pemirsa'
                                  : 'Dilihat oleh ${currentViewers.length} orang',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Quick Forward Button
                          IconButton(
                            icon: const Icon(Icons.forward_rounded, color: Colors.white, size: 22),
                            tooltip: 'Teruskan Status',
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              _forwardStatus(story);
                            },
                          ),
                          // Quick Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                            tooltip: 'Hapus',
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              _confirmDeleteStatus();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),

                    // Viewers list or empty state
                    Expanded(
                      child: currentViewers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.visibility_off_outlined,
                                      size: 42,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Belum ada yang melihat status ini',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 36),
                                    child: Text(
                                      'Kontak Anda yang membuka status ini akan tercatat di sini. Status akan otomatis kadaluarsa setelah 24 jam.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: currentViewers.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Colors.white10,
                                height: 1,
                                indent: 70,
                              ),
                              itemBuilder: (context, idx) {
                                final v = currentViewers[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                  leading: ModernAvatar(
                                    name: v.username,
                                    imagePath: v.avatarUrl,
                                    radius: 22,
                                  ),
                                  title: Text(
                                    v.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatViewerTime(v.viewedAt),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  trailing: v.reaction != null && v.reaction!.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            v.reaction!,
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (!_isPopping && mounted) {
        _animController.forward();
      }
    });
  }

  void _forwardStatus(StatusStoryItem story) {
    _animController.stop();

    final allConversations = ConversationService.instance.conversations;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setForwardState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? allConversations
                : allConversations
                    .where((c) => c.title.toLowerCase().contains(query))
                    .toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.forward_rounded, color: Color(0xFF00A884), size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Teruskan Status ke Obrolan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Search input
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                            hintText: 'Cari obrolan atau kontak...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                          ),
                          onChanged: (_) => setForwardState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),

                    // Conversations List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white38, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isEmpty
                                        ? 'Belum ada obrolan aktif'
                                        : 'Obrolan tidak ditemukan',
                                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Colors.white10,
                                height: 1,
                                indent: 70,
                              ),
                              itemBuilder: (context, idx) {
                                final conv = filtered[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: ModernAvatar(
                                    name: conv.title,
                                    imagePath: conv.avatarUrl,
                                    radius: 22,
                                  ),
                                  title: Text(
                                    conv.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    conv.isGroup
                                        ? 'Grup'
                                        : (conv.lastMessage.isNotEmpty ? conv.lastMessage : 'Ketuk untuk mengirim'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00A884),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(sheetCtx);
                                    if (story.isPhoto && story.imageAsset != null) {
                                      await ConversationService.instance.sendMessage(
                                        conversationId: conv.id,
                                        messageType: 'IMAGE',
                                        attachmentPath: story.imageAsset,
                                        text: story.text.isNotEmpty ? story.text : 'Diteruskan dari status',
                                      );
                                    } else {
                                      await ConversationService.instance.sendMessage(
                                        conversationId: conv.id,
                                        messageType: 'TEXT',
                                        text: '*Status:*\n${story.text}',
                                      );
                                    }
                                    if (mounted) {
                                      LajuToast.success(context, 'Status diteruskan ke ${conv.title}');
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (!_isPopping && mounted) {
        _animController.forward();
      }
    });
  }

  void _showReplyBottomSheet() {
    if (_stories.isEmpty) return;
    _animController.stop();

    final currentStory = _stories[_currentIndex];
    final quotedMsg = _buildQuotedStatusMessage(currentStory);
    final replyController = TextEditingController();

    const quickReactions = ['😂', '❤️', '😮', '😢', '🙏', '👍', '🔥', '👏'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomCtx).viewInsets.bottom,
            top: 10,
            left: 14,
            right: 14,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quoted status preview card (WhatsApp-style)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.pop(bottomCtx);
                    _openChatWithQuoted(quotedMsg);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                        left: BorderSide(color: Color(0xFF00A884), width: 3.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.reply_rounded, size: 12, color: Color(0xFF00A884)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Status • ${widget.contactName}',
                                    style: const TextStyle(
                                      color: Color(0xFF00A884),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentStory.isPhoto
                                    ? (currentStory.text.isNotEmpty ? currentStory.text : 'Foto')
                                    : currentStory.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (currentStory.isPhoto && currentStory.imageAsset != null) ...[
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: _buildStoryThumbnail(currentStory.imageAsset!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Reaction Emojis
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: quickReactions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final emoji = quickReactions[idx];
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(bottomCtx);
                          _sendQuickReaction(emoji, quotedMsg, currentStory);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Text Input Bar with Send Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: replyController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: 'Balas ke ${widget.contactName}...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              Navigator.pop(bottomCtx);
                              _sendReplyMessage(text.trim(), quotedMsg);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
                      tooltip: 'Buka Obrolan Lengkap',
                      onPressed: () {
                        Navigator.pop(bottomCtx);
                        _openChatWithQuoted(quotedMsg);
                      },
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () {
                        final text = replyController.text.trim();
                        if (text.isNotEmpty) {
                          Navigator.pop(bottomCtx);
                          _sendReplyMessage(text, quotedMsg);
                        } else {
                          Navigator.pop(bottomCtx);
                          _openChatWithQuoted(quotedMsg);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (!_isPopping && mounted) {
        _animController.forward();
      }
    });
  }

  Widget _buildStoryThumbnail(String path) {
    return LajuCachedImage(
      imageUrlOrPath: path,
      fit: BoxFit.cover,
      cacheWidth: 100,
      cacheHeight: 100,
      errorWidget: const Icon(Icons.image, size: 20, color: Colors.white54),
    );
  }

  Widget _buildStoryImage(StatusStoryItem story) {
    final asset = story.imageAsset;
    if (asset != null && asset.isNotEmpty) {
      return LajuCachedImage(
        imageUrlOrPath: asset,
        fit: BoxFit.cover,
        placeholder: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                story.backgroundColor ?? const Color(0xFF1E293B),
                story.backgroundColor?.withValues(alpha: 0.8) ?? const Color(0xFF0F172A),
              ],
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
            ),
          ),
        ),
        errorWidget: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                story.backgroundColor ?? const Color(0xFF1E293B),
                story.backgroundColor?.withValues(alpha: 0.8) ?? const Color(0xFF0F172A),
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white38),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            story.backgroundColor ?? const Color(0xFF1E293B),
            story.backgroundColor?.withValues(alpha: 0.8) ?? const Color(0xFF0F172A),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(StatusStoryItem story) {
    if (story.isVideo) {
      final videoSrc = story.videoUrl ?? story.imageAsset ?? '';
      return NativeVideoPlayerWidget(
        key: ValueKey('video_${story.id ?? story.time}_${story.hashCode}'),
        videoUrl: videoSrc,
        autoPlay: true,
        loop: false,
        muted: _isVideoMuted,
        controller: _videoPlayerController,
        onPrepared: _onVideoPrepared,
        onCompleted: _onVideoCompleted,
      );
    }
    return _buildStoryImage(story);
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final story = _stories[_currentIndex];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _isPopping = true;
        _animController.stop();
        _videoPlayerController.pause();
      },
      child: Scaffold(
        backgroundColor: story.backgroundColor,
        body: GestureDetector(
          onTapDown: (details) {
            if (_isPopping) return;
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth * 0.3) {
              _previousStory();
            } else {
              _nextStory();
            }
          },
          onLongPressStart: (_) {
            _animController.stop();
            _videoPlayerController.pause();
          },
          onLongPressEnd: (_) {
            if (!_isPopping) {
              _animController.forward();
              _videoPlayerController.play();
            }
          },
          onVerticalDragEnd: (details) {
            if (_isPopping) return;
            final vy = details.primaryVelocity ?? 0;
            if (vy < -200 && !widget.isMyStatus) {
              // Swipe up to reply (like WhatsApp)
              _showReplyBottomSheet();
            } else if (vy > 250) {
              // Swipe down to dismiss
              _safeClose();
            }
          },
          child: Stack(
            children: [
              // Media Story Visual (Photo or Video)
              if (story.isPhoto || story.isVideo)
                Positioned.fill(
                  child: _buildStoryContent(story),
                ),

              // Top dark gradient scrim for top controls
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom smooth gradient scrim for photo/video caption & reply bar
              if (story.isPhoto || story.isVideo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 280,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Text Story Content (Centered with large font)
              if (!story.isPhoto && !story.isVideo)
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

              // Top Bar: Progress Bars + Contact Header
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Story segmented bars
                      Row(
                        children: List.generate(_stories.length, (idx) {
                          return Expanded(
                            child: Container(
                              height: 3,
                              margin: EdgeInsets.symmetric(
                                horizontal: _stories.length > 1 ? 2.5 : 0,
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

                      // Contact Header Row
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                            onPressed: _safeClose,
                          ),
                          if (widget.isOfficial || story.isOfficial)
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              clipBehavior: Clip.antiAlias,
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/images/logo_no_bg.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shield_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 22,
                                ),
                              ),
                            )
                          else
                            ModernAvatar(
                              name: widget.contactName,
                              imagePath: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                                  ? widget.avatarUrl
                                  : (story.isPhoto && story.imageAsset != null && story.imageAsset!.isNotEmpty
                                      ? story.imageAsset
                                      : _stories.cast<StatusStoryItem?>().firstWhere(
                                          (s) => s != null && s.isPhoto && s.imageAsset != null && s.imageAsset!.isNotEmpty,
                                          orElse: () => null,
                                        )?.imageAsset),
                              radius: 19,
                              isVerified: true,
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.contactName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (widget.isOfficial || story.isOfficial) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        color: Color(0xFF38BDF8),
                                        size: 16,
                                      ),
                                    ],
                                  ],
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
                          if (story.isVideo)
                            IconButton(
                              icon: Icon(
                                _isVideoMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: _isVideoMuted ? 'Nyalakan Suara' : 'Bisukan Suara',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isVideoMuted = !_isVideoMuted;
                                });
                                _videoPlayerController.setMuted(_isVideoMuted);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                            onPressed: _showMoreOptions,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Unified Area: Photo Caption + Balas / My Status
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Media Caption (WhatsApp style - placed cleanly above Balas/Status button, never overlapping)
                        if ((story.isPhoto || story.isVideo) && story.text.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              story.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 1.35,
                                letterSpacing: 0.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 10,
                                    offset: Offset(0, 1.5),
                                  ),
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Balas Pill or My Status View
                        if (widget.isMyStatus)
                          Center(
                            child: GestureDetector(
                              onTap: () => _showViewersSheet(story),
                              onVerticalDragEnd: (details) {
                                if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                                  _showViewersSheet(story);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 17),
                                    const SizedBox(width: 7),
                                    Text(
                                      story.viewers.isEmpty ? '0 dilihat' : '${story.viewers.length} dilihat',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else if (widget.isOfficial || story.isOfficial)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (story.actionUrl != null && story.actionUrl!.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _openActionUrl(story.actionUrl!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          story.actionTitle?.isNotEmpty == true
                                              ? story.actionTitle!
                                              : 'Buka Tautan',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.open_in_new_rounded, color: Color(0xFF0F172A), size: 16),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Status Resmi LAJU',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_user_rounded, size: 11, color: Colors.white60),
                                  SizedBox(width: 5),
                                  Text(
                                    'Pembaruan resmi terverifikasi dari LAJU',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reply Pill (WhatsApp style)
                              GestureDetector(
                                onTap: _showReplyBottomSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.26),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 6),
                                      Text(
                                        'Balas',
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
                              const SizedBox(height: 10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_rounded, size: 11, color: Colors.white60),
                                  SizedBox(width: 5),
                                  Text(
                                    'End-to-end encrypted',
                                    style: TextStyle(fontSize: 10.5, color: Colors.white60, letterSpacing: 0.3),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
