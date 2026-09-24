import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/status_service.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../messaging/domain/models/message_model.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';

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
  final String? avatarUrl;
  final List<StatusStoryItem> stories;
  final bool isMyStatus;
  final String? contactUserId;
  final VoidCallback? onStatusDeleted;

  const StatusViewScreen({
    super.key,
    required this.contactName,
    this.avatarUrl,
    required this.stories,
    this.isMyStatus = false,
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
      _animController.forward();
    }
  }

  void _markCurrentViewed() {
    if (_stories.isNotEmpty && _currentIndex < _stories.length) {
      final story = _stories[_currentIndex];
      if (story.id != null) {
        StatusService.instance.markStatusViewed(story.id!);
      }
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
      _animController.reset();
      _animController.forward();
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
      _animController.reset();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
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
                  leading: const Icon(Icons.share_outlined, color: Colors.white),
                  title: const Text(
                    'Teruskan Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    LajuToast.info(context, 'Fitur teruskan status siap');
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
          ? (story.text.isNotEmpty ? story.text : '📷 Foto')
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

  void _sendReplyMessage(String text, MessageModel quotedMsg) async {
    _isPopping = true;
    _animController.stop();

    final convId = await _resolveConversationId();

    await ConversationService.instance.sendMessage(
      conversationId: convId,
      text: text,
      replyTo: quotedMsg,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          title: widget.contactName,
          avatarUrl: widget.avatarUrl,
          contactUserId: widget.contactUserId,
        ),
      ),
    );
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
                                    ? (currentStory.text.isNotEmpty ? currentStory.text : '📷 Foto')
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final emoji = quickReactions[idx];
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(bottomCtx);
                          _sendReplyMessage(emoji, quotedMsg);
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
    if (path.startsWith('data:image')) {
      try {
        final b64 = path.contains(',') ? path.split(',').last : path;
        return Image.memory(base64Decode(b64), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.white54));
      } catch (_) {}
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.white54));
    }
    if (File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.white54));
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20, color: Colors.white54));
    }
    return Container(color: Colors.black26, child: const Icon(Icons.image, size: 20, color: Colors.white54));
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
          onLongPressStart: (_) => _animController.stop(),
          onLongPressEnd: (_) {
            if (!_isPopping) _animController.forward();
          },
          child: Stack(
            children: [
              // Photo Story Visual
              if (story.isPhoto)
                Positioned.fill(
                  child: _buildStoryImage(story),
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

              // Bottom smooth gradient scrim for photo caption & reply bar
              if (story.isPhoto)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 220,
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
              if (!story.isPhoto)
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

              // Photo Caption (WhatsApp-style: positioned smoothly at the bottom)
              if (story.isPhoto && story.text.isNotEmpty)
                Positioned(
                  bottom: widget.isMyStatus ? 48 : 82,
                  left: 20,
                  right: 20,
                  child: Text(
                    story.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16.5,
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
                      ],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
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
                            onPressed: _showMoreOptions,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Area
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: widget.isMyStatus
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Status Saya',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
