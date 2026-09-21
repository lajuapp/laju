import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/models/conversation_model.dart';
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
          ),
        ),
      );
    }
    _loadLockedChats();
  }

  void _unlockChat(ConversationModel conv) async {
    final unlocked = conv.copyWith(isLocked: false);
    await LocalDatabase.instance.upsertConversations([unlocked]);
    if (mounted) {
      LajuToast.success(context, 'Obrolan "${conv.title}" telah dibuka dari Locked Chats');
      _loadLockedChats();
    }
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
              'Locked Chats 🔒',
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
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: cardColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (bCtx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.lock_open_rounded, color: AppColors.primary),
                                    title: Text(
                                      'Buka Kunci Obrolan',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                                    ),
                                    subtitle: const Text('Pindahkan kembali ke daftar obrolan utama'),
                                    onTap: () {
                                      Navigator.pop(bCtx);
                                      _unlockChat(conv);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
