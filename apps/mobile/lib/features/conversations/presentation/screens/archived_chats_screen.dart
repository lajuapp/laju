import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/conversation_service.dart';
import '../../domain/models/conversation_model.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/conversation_options_sheet.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../../messaging/presentation/screens/group_chat_screen.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  List<ConversationModel> _archivedConversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchivedChats();
  }

  Future<void> _loadArchivedChats() async {
    final all = await LocalDatabase.instance.getConversations();
    if (mounted) {
      setState(() {
        _archivedConversations = all.where((c) => c.isArchived == true).toList();
        _isLoading = false;
      });
    }
  }

  void _openChat(ConversationModel conv) async {
    if (conv.isGroup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(
            groupId: conv.id,
            groupName: conv.title,
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
    _loadArchivedChats();
  }

  Future<void> _unarchiveChat(ConversationModel conv) async {
    final unarchived = conv.copyWith(isArchived: false);
    await ConversationService.instance.updateConversationLocally(unarchived);
    if (mounted) {
      LajuToast.info(context, 'Chat "${conv.title}" dibuka dari arsip');
      _loadArchivedChats();
    }
  }

  void _handleOptions(ConversationModel conv) async {
    final action = await ConversationOptionsSheet.show(context, conversation: conv);
    if (action == null || !mounted) return;

    if (action == ConversationActionType.toggleArchive) {
      await _unarchiveChat(conv);
    } else if (action == ConversationActionType.deleteChat) {
      _showDeleteChatConfirmation(conv);
    } else {
      _loadArchivedChats();
    }
  }

  void _showDeleteChatConfirmation(ConversationModel conv) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Hapus Chat?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Riwayat pesan dan media dengan "${conv.title}" akan dihapus secara permanen dari perangkat ini.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ConversationService.instance.deleteConversation(conv.id);
              await LocalDatabase.instance.deleteConversation(conv.id);
              if (mounted) {
                LajuToast.info(context, 'Obrolan telah dihapus');
                _loadArchivedChats();
              }
            },
            child: const Text('Hapus Chat'),
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
              'Obrolan Diarsipkan',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_archivedConversations.length} obrolan tersimpan di arsip',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedConversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.archive_outlined,
                          size: 36,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada obrolan yang diarsipkan',
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
                          'Untuk mengarsipkan obrolan, tekan tahan pada obrolan di daftar utama lalu pilih "Arsipkan Chat".',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _archivedConversations.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 82,
                    color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (context, index) {
                    final conv = _archivedConversations[index];
                    return ConversationTile(
                      conversation: conv,
                      onTap: () => _openChat(conv),
                      onLongPress: () => _handleOptions(conv),
                    );
                  },
                ),
    );
  }
}
