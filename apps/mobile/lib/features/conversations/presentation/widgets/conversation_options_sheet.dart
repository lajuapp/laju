import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/modern_avatar.dart';
import '../../domain/models/conversation_model.dart';

enum ConversationActionType {
  togglePin,
  lockChat,
  toggleArchive,
  toggleMute,
  toggleRead,
  addLabel,
  clearChat,
  deleteChat,
  exitGroup,
  blockContact,
  reportContact,
}

class ConversationOptionsSheet {
  static Future<ConversationActionType?> show(
    BuildContext context, {
    required ConversationModel conversation,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return showModalBottomSheet<ConversationActionType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final surfaceBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleCol = isDark ? Colors.white : const Color(0xFF0F172A);
        final subCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final dividerCol = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

        return Container(
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Avatar & Details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        ModernAvatar(
                          name: conversation.title,
                          imagePath: conversation.avatarUrl,
                          radius: 24,
                          isOnline: conversation.isOnline,
                          isVerified: conversation.isKeyVerified,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      conversation.title,
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        color: titleCol,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (conversation.isGroup) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Grup',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                conversation.lastMessage,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: subCol,
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
                  const SizedBox(height: 14),
                  Divider(height: 1, color: dividerCol),
                  const SizedBox(height: 6),

                  // Action 1: Pin / Unpin
                  _buildOptionTile(
                    context: ctx,
                    icon: conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    iconColor: AppColors.primary,
                    title: conversation.isPinned ? 'Lepas Sematan (Unpin)' : 'Sematkan Chat (Pin)',
                    subtitle: conversation.isPinned
                        ? 'Hapus sematan dari daftar teratas'
                        : 'Sematkan chat ini di posisi paling atas',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.togglePin),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 2: Locked Chat (Kunci Chat)
                  _buildOptionTile(
                    context: ctx,
                    icon: conversation.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: conversation.isLocked ? 'Buka Kunci Chat (Unlock Chat)' : 'Kunci Chat (Locked Chat)',
                    subtitle: conversation.isLocked
                        ? 'Pindahkan kembali ke daftar obrolan utama'
                        : 'Amankan obrolan ini di folder terkunci dengan sidik jari/PIN',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.lockChat),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 3: Archive / Unarchive
                  _buildOptionTile(
                    context: ctx,
                    icon: conversation.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: conversation.isArchived ? 'Buka Arsip (Unarchive)' : 'Arsipkan Chat (Archive)',
                    subtitle: conversation.isArchived
                        ? 'Pindahkan kembali ke daftar obrolan utama'
                        : 'Sembunyikan obrolan ke folder arsip pesan',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.toggleArchive),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 4: Mute / Unmute
                  _buildOptionTile(
                    context: ctx,
                    icon: conversation.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                    iconColor: const Color(0xFF6366F1),
                    title: conversation.isMuted ? 'Bunyikan Notifikasi' : 'Bisukan Notifikasi (Mute)',
                    subtitle: conversation.isMuted
                        ? 'Aktifkan suara dan getar pesan masuk'
                        : 'Heningkan suara dan getar notifikasi pesan ini',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.toggleMute),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 5: Mark as Read / Unread
                  _buildOptionTile(
                    context: ctx,
                    icon: conversation.unreadCount > 0 ? Icons.mark_chat_read_outlined : Icons.mark_chat_unread_outlined,
                    iconColor: const Color(0xFF06B6D4),
                    title: conversation.unreadCount > 0 ? 'Tandai Sudah Dibaca' : 'Tandai Belum Dibaca',
                    subtitle: 'Ubah indikator status pesan obrolan ini',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.toggleRead),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 6: Tag / Label
                  _buildOptionTile(
                    context: ctx,
                    icon: Icons.label_outline_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Beri Label / Kategori',
                    subtitle: 'Kategorikan chat (Pribadi, Kerja, Prioritas, Bisnis)',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.addLabel),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  // Action 7: Clear Chat History
                  _buildOptionTile(
                    context: ctx,
                    icon: Icons.cleaning_services_outlined,
                    iconColor: const Color(0xFFEAB308),
                    title: 'Bersihkan Riwayat Pesan',
                    subtitle: 'Hapus seluruh isi pesan tanpa menghapus kontak',
                    onTap: () => Navigator.pop(ctx, ConversationActionType.clearChat),
                    titleCol: titleCol,
                    subCol: subCol,
                  ),

                  Divider(height: 1, color: dividerCol),
                  const SizedBox(height: 4),

                  // Action 8: Delete Chat (STRICTLY DISABLED / HIDDEN FOR GROUPS as requested)
                  if (!conversation.isGroup)
                    _buildOptionTile(
                      context: ctx,
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Hapus Chat',
                      subtitle: 'Hapus obrolan ini beserta riwayat pesannya secara permanen',
                      onTap: () => Navigator.pop(ctx, ConversationActionType.deleteChat),
                      titleCol: Colors.redAccent,
                      subCol: subCol,
                    )
                  else
                    _buildOptionTile(
                      context: ctx,
                      icon: Icons.exit_to_app_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Keluar dari Grup',
                      subtitle: 'Tinggalkan grup ini dan hentikan penerimaan pesan',
                      onTap: () => Navigator.pop(ctx, ConversationActionType.exitGroup),
                      titleCol: Colors.redAccent,
                      subCol: subCol,
                    ),

                  // Action 9: Block Contact (Personal chats only)
                  if (!conversation.isGroup) ...[
                    _buildOptionTile(
                      context: ctx,
                      icon: Icons.block_flipped,
                      iconColor: Colors.red.shade400,
                      title: 'Blokir Kontak',
                      subtitle: 'Blokir panggilan dan pesan masuk dari kontak ini',
                      onTap: () => Navigator.pop(ctx, ConversationActionType.blockContact),
                      titleCol: Colors.red.shade400,
                      subCol: subCol,
                    ),

                    // Action 10: Report Contact (Personal chats only)
                    _buildOptionTile(
                      context: ctx,
                      icon: Icons.flag_outlined,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Laporkan Kontak',
                      subtitle: 'Laporkan spam, penipuan, atau pelecehan dari kontak ini',
                      onTap: () => Navigator.pop(ctx, ConversationActionType.reportContact),
                      titleCol: const Color(0xFFEF4444),
                      subCol: subCol,
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color titleCol,
    required Color subCol,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleCol,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subCol,
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
