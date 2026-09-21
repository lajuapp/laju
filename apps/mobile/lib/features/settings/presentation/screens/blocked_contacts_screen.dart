import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/account_controller.dart';
import '../../../conversations/domain/conversation_service.dart';

class BlockedContactsScreen extends StatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  State<BlockedContactsScreen> createState() => _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends State<BlockedContactsScreen> {
  void _showAddBlockModal(BuildContext context) async {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final users = await ConversationService.instance.searchUsers('');
    final customController = TextEditingController();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final candidates = users.map((u) => '${u.username} (${u.phoneNumber ?? u.email ?? u.id})').toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      context.tr('selectContactToBlock'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customController,
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Ketik nama / nomor telepon...',
                              hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final text = customController.text.trim();
                            if (text.isNotEmpty) {
                              Navigator.pop(ctx);
                              AccountController.instance.addBlockedContact(text);
                              LajuToast.info(context, '$text ${context.tr('addToBlocked')}');
                            }
                          },
                          child: const Text('Blokir'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (candidates.isNotEmpty) ...[
                      const Text(
                        'Pilih dari kontak terdaftar:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView(
                          shrinkWrap: true,
                          children: candidates.map((contact) {
                            final isAlreadyBlocked = AccountController.instance.blockedContacts.contains(contact);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                                child: Text(
                                  contact[0].toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              title: Text(
                                contact,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              trailing: isAlreadyBlocked
                                  ? const Text(
                                      'Blocked',
                                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                                    )
                                  : const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                              onTap: isAlreadyBlocked
                                  ? null
                                  : () {
                                      Navigator.pop(ctx);
                                      AccountController.instance.addBlockedContact(contact);
                                      LajuToast.info(context, '$contact ${context.tr('addToBlocked')}');
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmUnblock(BuildContext context, String contact) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          '${context.tr('unblockConfirmTitle')} ($contact)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          context.tr('unblockConfirmDesc'),
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AccountController.instance.removeBlockedContact(contact);
              LajuToast.success(context, '$contact unblocked');
            },
            child: Text(context.tr('unblock'), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('blockedContacts'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_disabled_outlined),
            color: isDark ? Colors.white : const Color(0xFF111827),
            onPressed: () => _showAddBlockModal(context),
          ),
        ],
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: AccountController.instance,
            builder: (context, _) {
              final blocked = AccountController.instance.blockedContacts;

              if (blocked.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LajuGlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person_off_outlined,
                              size: 34,
                              color: isDark ? Colors.white54 : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            context.tr('noBlockedContacts'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('noBlockedContactsDesc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: Text(context.tr('addToBlocked'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => _showAddBlockModal(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  LajuGlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: List.generate(blocked.length, (index) {
                        final contact = blocked[index];
                        return Column(
                          children: [
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: 56,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                              ),
                            Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                  child: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                                ),
                                title: Text(
                                  contact,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                subtitle: Text(
                                  context.tr('tapToUnblock'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                  ),
                                ),
                                trailing: TextButton(
                                  onPressed: () => _confirmUnblock(context, contact),
                                  child: Text(
                                    context.tr('unblock'),
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                onTap: () => _confirmUnblock(context, contact),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
