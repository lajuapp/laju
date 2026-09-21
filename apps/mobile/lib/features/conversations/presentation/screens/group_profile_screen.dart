import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../calls/presentation/screens/active_call_screen.dart';
import '../../../calls/presentation/screens/active_group_call_screen.dart';
import '../../../messaging/presentation/screens/disappearing_messages_screen.dart';
import '../../../messaging/presentation/screens/chat_screen.dart';
import '../../domain/group_controller.dart';
import 'group_settings_screen.dart';
import 'user_profile_screen.dart';

class GroupProfileScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupDescription;

  const GroupProfileScreen({
    super.key,
    this.groupId = 'grp-1',
    this.groupName = 'Operations Team',
    this.groupDescription = 'Official tactical field coordination and dispatch channel.',
  });

  @override
  State<GroupProfileScreen> createState() => _GroupProfileScreenState();
}

class _GroupProfileScreenState extends State<GroupProfileScreen> {
  bool _isMuted = false;

  void _editGroupName(String currentName) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('changeGroupName'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: TextField(
          controller: textController,
          maxLength: 50,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: context.tr('groupSubject'),
            hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                GroupController.instance.updateGroupInfo(widget.groupId, name: newName);
                Navigator.pop(ctx);
                LajuToast.success(context, context.tr('groupInfoUpdated'));
              }
            },
            child: Text(context.tr('saveSettings')),
          ),
        ],
      ),
    );
  }

  void _editGroupDescription(String currentDesc) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textController = TextEditingController(text: currentDesc);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('changeGroupDesc'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: TextField(
          controller: textController,
          maxLines: 4,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: context.tr('groupDescriptionHint'),
            hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newDesc = textController.text.trim();
              GroupController.instance.updateGroupInfo(widget.groupId, description: newDesc);
              Navigator.pop(ctx);
              LajuToast.success(context, context.tr('groupInfoUpdated'));
            },
            child: Text(context.tr('saveSettings')),
          ),
        ],
      ),
    );
  }

  void _editGroupAvatar() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text(
                  context.tr('camera'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                onTap: () {
                  Navigator.pop(bCtx);
                  GroupController.instance.updateGroupInfo(widget.groupId, avatarPath: 'camera_photo_updated');
                  LajuToast.success(context, context.tr('photoUpdated'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
                title: Text(
                  context.tr('gallery'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                onTap: () {
                  Navigator.pop(bCtx);
                  GroupController.instance.updateGroupInfo(widget.groupId, avatarPath: 'gallery_photo_updated');
                  LajuToast.success(context, context.tr('photoUpdated'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text(
                  context.tr('removePhoto'),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(bCtx);
                  GroupController.instance.updateGroupInfo(widget.groupId, avatarPath: '');
                  LajuToast.info(context, context.tr('photoRemoved'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemoveMember(GroupMemberItem member) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${context.tr('removeFromGroup')} ${member.name}?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          '${member.name} ${context.tr('removeMemberConfirmDesc')}',
          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              GroupController.instance.removeMember(widget.groupId, member.id);
              LajuToast.info(context, '${member.name} ${context.tr('memberRemoved')}');
            },
            child: Text(context.tr('clear')),
          ),
        ],
      ),
    );
  }

  void _confirmExitGroup(String groupName) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari grup $groupName?',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Anda tidak akan dapat mengirim atau menerima pesan lagi di grup ini setelah keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.pop(context); // Exit group profile
              Navigator.pop(context); // Exit group chat screen back to home
              LajuToast.info(context, 'Anda telah keluar dari $groupName');
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMemberActions(GroupMemberItem member, bool isUserAdmin) {
    if (member.id == 'm-you') return;

    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: AppColors.primary),
                title: Text(
                  'Kirim pesan ke ${member.name}',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId: 'conv-${member.id}',
                        title: member.name,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: AppColors.cyan),
                title: Text(
                  'Lihat profil ${member.name}',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        contactName: member.name,
                        phone: member.phone,
                        status: member.role,
                        isOnline: member.isOnline,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_rounded, color: Colors.green),
                title: Text(
                  'Panggil ${member.name}',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveCallScreen(contactName: member.name),
                    ),
                  );
                },
              ),

              // Admin-only member actions
              if (isUserAdmin) ...[
                Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
                ListTile(
                  leading: Icon(
                    member.isAdmin ? Icons.remove_moderator_rounded : Icons.shield_rounded,
                    color: member.isAdmin ? Colors.orange : AppColors.primary,
                  ),
                  title: Text(
                    member.isAdmin ? context.tr('dismissAdmin') : context.tr('makeGroupAdmin'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: member.isAdmin ? Colors.orange : AppColors.primary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    GroupController.instance.toggleAdmin(widget.groupId, member.id);
                    LajuToast.info(
                      context,
                      member.isAdmin
                          ? '${member.name} ${context.tr('adminDismissed')}'
                          : '${member.name} ${context.tr('adminPromoted')}',
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                  title: Text(
                    '${context.tr('removeFromGroup')} ${member.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmRemoveMember(member);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return AnimatedBuilder(
      animation: GroupController.instance,
      builder: (context, _) {
        final group = GroupController.instance.getGroup(widget.groupId) ??
            GroupModel(
              id: widget.groupId,
              name: widget.groupName,
              description: widget.groupDescription,
              creatorId: 'm-you',
              createdAt: DateTime.now(),
              members: [],
            );

        final isUserAdmin = GroupController.instance.isCurrentUserAdmin(widget.groupId);
        final members = group.members;

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
              'Info Grup',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded, color: textPrimary),
                tooltip: 'Cari di Grup',
                onPressed: () {
                  LajuToast.info(context, 'Membuka pencarian pesan grup');
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: textPrimary),
                color: cardColor,
                onSelected: (val) {
                  if (val == 'exit') {
                    _confirmExitGroup(group.name);
                  } else if (val == 'settings') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupSettingsScreen(groupId: widget.groupId),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (isUserAdmin)
                    PopupMenuItem(
                      value: 'settings',
                      child: Text(context.tr('groupSettings'), style: TextStyle(color: textPrimary)),
                    ),
                  PopupMenuItem(
                    value: 'add',
                    child: Text('Tambah Anggota', style: TextStyle(color: textPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'exit',
                    child: const Text('Keluar dari Grup', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Group Header Card
                Container(
                  width: double.infinity,
                  color: cardColor,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: isUserAdmin ? _editGroupAvatar : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.groups_rounded,
                                size: 48,
                                color: AppColors.primary,
                              ),
                            ),
                            if (isUserAdmin)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Group Name with edit icon for admin
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              group.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (isUserAdmin) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editGroupName(group.name),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grup • ${members.length} anggota • Quantum Ratchet Active',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickAction(
                            icon: Icons.call_rounded,
                            label: 'Panggilan',
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveGroupCallScreen(
                                    groupName: group.name,
                                    initialParticipants: members
                                        .where((m) => m.id != 'm-you')
                                        .map((m) => m.name)
                                        .toList(),
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
                                  builder: (context) => ActiveGroupCallScreen(
                                    groupName: group.name,
                                    initialParticipants: members
                                        .where((m) => m.id != 'm-you')
                                        .map((m) => m.name)
                                        .toList(),
                                    isVideo: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildQuickAction(
                            icon: Icons.person_add_rounded,
                            label: 'Tambah',
                            isDark: isDark,
                            onTap: () {
                              LajuToast.info(context, 'Pilih kontak untuk ditambahkan ke grup');
                            },
                          ),
                          _buildQuickAction(
                            icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
                            label: _isMuted ? 'Muted' : 'Mute',
                            isDark: isDark,
                            isActive: _isMuted,
                            onTap: () {
                              setState(() => _isMuted = !_isMuted);
                              LajuToast.info(
                                context,
                                _isMuted ? 'Notifikasi grup dibisukan' : 'Notifikasi grup diaktifkan',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Group Description Card
                Container(
                  width: double.infinity,
                  color: cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Deskripsi Grup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (isUserAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _editGroupDescription(group.description),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        group.description.isNotEmpty
                            ? group.description
                            : 'Tambahkan deskripsi grup...',
                        style: TextStyle(
                          fontSize: 14.5,
                          color: group.description.isNotEmpty ? textPrimary : textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dibuat oleh Anda',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Group Settings Tile (Visible if User is Admin)
                if (isUserAdmin) ...[
                  Material(
                    color: cardColor,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        context.tr('groupSettings'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 15),
                      ),
                      subtitle: Text(
                        context.tr('groupSettingsSub'),
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupSettingsScreen(groupId: widget.groupId),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Encryption & Security Card
                Material(
                  color: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Enkripsi & Keamanan Grup',
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
                          child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          'Signal Group Protocol v2',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                        ),
                        subtitle: Text(
                          'Semua pesan, lampiran, dan metadata grup dienkripsi secara penuh dengan Double Ratchet per anggota.',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
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
                          group.disappearingSeconds != null
                              ? '${group.disappearingSeconds} detik'
                              : 'Mati • Ketuk untuk mengatur timer',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DisappearingMessagesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Media, Links & Docs Card
                Material(
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
                    subtitle: Text('38 Foto, 12 Dokumen, 5 Tautan', style: TextStyle(color: textSecondary, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('55', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      ],
                    ),
                    onTap: () {
                      LajuToast.info(context, 'Membuka galeri media grup');
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Members List Card
                Material(
                  color: cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${members.length} Peserta',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Add Participant action
                      if (group.canAddMembers || isUserAdmin)
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                          ),
                          title: Text(
                            'Tambah Peserta',
                            style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 15),
                          ),
                          onTap: () {
                            LajuToast.info(context, 'Pilih kontak untuk ditambahkan');
                          },
                        ),

                      // Invite via link
                      ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
                        ),
                        title: Text(
                          'Undang via Tautan',
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 15),
                        ),
                        onTap: () {
                          LajuToast.info(context, 'Tautan undangan disalin ke clipboard');
                        },
                      ),
                      const Divider(height: 8),

                      // Members list
                      ...members.map((member) {
                        return ListTile(
                          onTap: () => _showMemberActions(member, isUserAdmin),
                          leading: ModernAvatar(
                            name: member.name,
                            radius: 20,
                            isOnline: member.isOnline,
                            isVerified: true,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (member.isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Admin Grup',
                                    style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            member.role,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Danger Zone Card (Exit group / Report)
                Material(
                  color: cardColor,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.exit_to_app_rounded, color: AppColors.danger),
                        title: const Text(
                          'Keluar dari Grup',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                        ),
                        onTap: () => _confirmExitGroup(group.name),
                      ),
                      Divider(height: 1, indent: 56, color: isDark ? Colors.white10 : Colors.black12),
                      ListTile(
                        leading: const Icon(Icons.thumb_down_alt_rounded, color: AppColors.danger),
                        title: const Text(
                          'Laporkan Grup',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger, fontSize: 14.5),
                        ),
                        onTap: () {
                          LajuToast.info(context, 'Laporan grup telah dikirim ke tim keamanan');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
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
