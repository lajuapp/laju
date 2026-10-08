import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/conversation_service.dart';
import '../widgets/conversation_tile.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/presentation/screens/group_chat_screen.dart';

class LockedChatsScreen extends StatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> {
  List<ConversationModel> _lockedConversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLockedChats();
  }

  Future<void> _loadLockedChats() async {
    final all = await LocalDatabase.instance.getConversations();
    if (mounted) {
      setState(() {
        _lockedConversations = all.where((c) => c.isLocked == true).toList();
        _isLoading = false;
      });
    }
  }

  void _openChat(ConversationModel conv) async {
    if (conv.unreadCount > 0) {
      ConversationService.instance.markConversationAsRead(conv.id);
    }
    if (conv.isGroup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(
            groupId: conv.id,
            groupName: conv.title,
            avatarUrl: conv.avatarUrl,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conv.id,
            title: conv.title,
            isGroup: conv.isGroup,
            avatarUrl: conv.avatarUrl,
            contactUserId: conv.participantUserId,
            contactPhone: conv.participantPhone,
            contactAbout: conv.participantAbout,
            contactTrustScore: conv.participantTrustScore,
          ),
        ),
      );
    }
    _loadLockedChats();
  }

  void _unlockChat(ConversationModel conv) async {
    final unlocked = conv.copyWith(isLocked: false);
    await ConversationService.instance.updateConversationLocally(unlocked);
    if (mounted) {
      LajuToast.success(context, 'Obrolan "${conv.title}" telah dipindahkan kembali ke daftar obrolan utama');
      _loadLockedChats();
    }
  }

  void _showUnlockDialog(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Buka Kunci Obrolan?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Obrolan "${conv.title}" akan dibuka kuncinya dan dipindahkan kembali ke daftar obrolan utama.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(dlgCtx);
              _unlockChat(conv);
            },
            child: const Text('Buka Kunci', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pesan Terkunci',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Terkunci secara biometrik / PIN',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lockedConversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.lock_open_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada obrolan terkunci',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Untuk mengunci obrolan, tahan pada obrolan di daftar utama lalu pilih "Kunci Chat".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _lockedConversations.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 82,
                    color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (context, index) {
                    final conv = _lockedConversations[index];
                    return ConversationTile(
                      conversation: conv,
                      onTap: () => _openChat(conv),
                      onLongPress: () => _showUnlockDialog(conv),
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 22),
                        tooltip: 'Buka Kunci Obrolan',
                        onPressed: () => _showUnlockDialog(conv),
                      ),
                    );
                  },
                ),
    );
  }
}
