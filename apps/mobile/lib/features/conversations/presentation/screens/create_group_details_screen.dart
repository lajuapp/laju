import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../messaging/presentation/screens/group_chat_screen.dart';
import '../../domain/group_controller.dart';
import '../../domain/conversation_service.dart';
import '../../domain/models/conversation_model.dart';

class CreateGroupDetailsScreen extends StatefulWidget {
  final List<GroupMemberItem> selectedMembers;

  const CreateGroupDetailsScreen({
    super.key,
    required this.selectedMembers,
  });

  @override
  State<CreateGroupDetailsScreen> createState() => _CreateGroupDetailsScreenState();
}

class _CreateGroupDetailsScreenState extends State<CreateGroupDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _avatarPath;
  bool _canEditGroupInfo = true;
  bool _canSendMessages = true;
  bool _canAddMembers = true;
  bool _requireApproval = false;
  int? _disappearingSeconds;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickAvatar() async {
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
                  setState(() => _avatarPath = 'camera_photo_picked');
                  LajuToast.info(context, context.tr('photoUpdated'));
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
                  setState(() => _avatarPath = 'gallery_photo_picked');
                  LajuToast.info(context, context.tr('photoUpdated'));
                },
              ),
              if (_avatarPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  title: Text(
                    context.tr('removePhoto'),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.pop(bCtx);
                    setState(() => _avatarPath = null);
                    LajuToast.info(context, context.tr('photoRemoved'));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisappearingMessagesPicker() {
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
                title: Text(
                  'Off',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                trailing: _disappearingSeconds == null ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _disappearingSeconds = null);
                  Navigator.pop(bCtx);
                },
              ),
              ListTile(
                title: Text(
                  '24 hours',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                trailing: _disappearingSeconds == 86400 ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _disappearingSeconds = 86400);
                  Navigator.pop(bCtx);
                },
              ),
              ListTile(
                title: Text(
                  '7 days',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                trailing: _disappearingSeconds == 604800 ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _disappearingSeconds = 604800);
                  Navigator.pop(bCtx);
                },
              ),
              ListTile(
                title: Text(
                  '90 days',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                trailing: _disappearingSeconds == 7776000 ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _disappearingSeconds = 7776000);
                  Navigator.pop(bCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      LajuToast.error(context, context.tr('enterGroupName'));
      return;
    }

    setState(() => _isCreating = true);

    final newGroup = await GroupController.instance.createGroupAsync(
      name: name,
      description: _descriptionController.text.trim(),
      avatarPath: _avatarPath,
      members: widget.selectedMembers,
      disappearingSeconds: _disappearingSeconds,
      canEditGroupInfo: _canEditGroupInfo,
      canSendMessages: _canSendMessages,
      canAddMembers: _canAddMembers,
      requireApprovalToJoin: _requireApproval,
    );

    // Save to local SQLite database so group appears in home screen immediately
    await LocalDatabase.instance.upsertConversations([
      ConversationModel(
        id: newGroup.id,
        title: newGroup.name,
        lastMessage: 'Grup dibuat',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isGroup: true,
        isOnline: true,
        isKeyVerified: true,
      ),
    ]);

    // Sync conversations list in background so all home listeners update immediately
    ConversationService.instance.fetchConversations().catchError((_) => <ConversationModel>[]);

    if (!mounted) return;

    LajuToast.success(context, '${context.tr('groupCreated')} "$name"');

    // Navigate to the newly created group chat
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          groupId: newGroup.id,
          groupName: newGroup.name,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  String _formatDisappearingLabel() {
    if (_disappearingSeconds == null) return 'Off';
    if (_disappearingSeconds == 86400) return '24 hours';
    if (_disappearingSeconds == 604800) return '7 days';
    if (_disappearingSeconds == 7776000) return '90 days';
    return '$_disappearingSeconds s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? AppColors.darkBackground : Colors.grey[50];
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
        title: Text(
          context.tr('newGroup'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_confirm_create_group',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _isCreating ? null : _handleCreateGroup,
        child: _isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.check_rounded, size: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Name and Avatar Row Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _avatarPath != null ? Icons.image_rounded : Icons.camera_alt_rounded,
                          color: _avatarPath != null ? AppColors.primary : textSecondary,
                          size: 26,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 50,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('groupSubject'),
                      hintStyle: TextStyle(color: textSecondary),
                      counterText: '',
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Group Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('groupDescription'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: context.tr('groupDescriptionHint'),
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Disappearing Messages & Permissions
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppColors.cyan, size: 20),
                  ),
                  title: Text(
                    context.tr('disappearingMessages'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _formatDisappearingLabel(),
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                  onTap: _showDisappearingMessagesPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Selected Members Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.selectedMembers.length + 1} ${context.tr('members')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  context.tr('youAreAdmin'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                // You
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const ModernAvatar(name: 'Anda', radius: 20, isVerified: true),
                  title: Text(
                    'Anda (You)',
                    style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                  ),
                  subtitle: Text('+62 812-0000-1111', style: TextStyle(fontSize: 12, color: textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Admin / Owner',
                      style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                ...widget.selectedMembers.map((m) {
                  return Column(
                    children: [
                      Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ModernAvatar(name: m.name, radius: 20, isVerified: true),
                        title: Text(
                          m.name,
                          style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14.5),
                        ),
                        subtitle: Text(m.phone, style: TextStyle(fontSize: 12, color: textSecondary)),
                        trailing: Text(
                          context.tr('memberRole'),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
