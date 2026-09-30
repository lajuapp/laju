import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _killPinController = TextEditingController();

  String? _avatarPath;
  String? _selectedWallpaperId;
  bool _enableEmergencyWipe = false;
  bool _obscureKillPin = true;
  final Set<String> _authorizedWipeMemberIds = <String>{};

  bool _canEditGroupInfo = true;
  bool _canSendMessages = true;
  bool _canAddMembers = true;
  bool _requireApproval = false;
  int? _disappearingSeconds;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    ChatAppearanceController.instance.fetchRemoteWallpapers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _killPinController.dispose();
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
                onTap: () async {
                  Navigator.pop(bCtx);
                  final path = await DeviceMediaService.openCamera();
                  if (path != null && path.isNotEmpty) {
                    final savedPath = await DeviceMediaService.savePermanentAvatar(path);
                    if (mounted) {
                      setState(() => _avatarPath = savedPath);
                      LajuToast.success(context, context.tr('photoUpdated'));
                    }
                  }
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
                onTap: () async {
                  Navigator.pop(bCtx);
                  final path = await DeviceMediaService.openGallery();
                  if (path != null && path.isNotEmpty) {
                    final savedPath = await DeviceMediaService.savePermanentAvatar(path);
                    if (mounted) {
                      setState(() => _avatarPath = savedPath);
                      LajuToast.success(context, context.tr('photoUpdated'));
                    }
                  }
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

  Widget _buildWallpaperMiniPreview(String? wallpaperId, bool isDark) {
    final wp = ChatAppearanceController.instance.findWallpaper(wallpaperId);
    if (wp == null || wallpaperId == null || wallpaperId == 'none') {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.format_color_reset_rounded,
          size: 16,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: wp.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (wp.category == 'GRADIENT')
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    wp.backgroundColor,
                    wp.backgroundColor.withValues(alpha: 0.75),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          if (wp.hasRemoteImage)
            LajuCachedImage(
              imageUrlOrPath: wp.remoteImageUrl,
              fit: BoxFit.cover,
              cacheWidth: 64,
              cacheHeight: 64,
              placeholder: const SizedBox(),
              errorWidget: const SizedBox(),
            ),
        ],
      ),
    );
  }

  void _showWallpaperPicker() {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final langCode = LocaleController.instance.value.languageCode;
    const plainOption = WallpaperOption(
      id: 'none',
      nameEn: 'Default (Plain)',
      nameId: 'Default (Polos)',
      backgroundColor: Color(0xFF0F172A),
      category: 'POLOS',
      isDefault: true,
      isRemote: false,
    );

    // Refresh remote wallpapers from backoffice
    ChatAppearanceController.instance.fetchRemoteWallpapers();

    String activePreviewId = _selectedWallpaperId ?? 'none';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (bCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ListenableBuilder(
              listenable: ChatAppearanceController.instance,
              builder: (context, _) {
                final allWallpapers = [plainOption, ...ChatAppearanceController.instance.allWallpapers];
                final activeWallpaper = allWallpapers.firstWhere(
                  (w) => w.id == activePreviewId,
                  orElse: () => plainOption,
                );

                return SafeArea(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              langCode == 'id' ? 'Pilih Wallpaper Obrolan Grup' : 'Select Group Chat Wallpaper',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 22),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.pop(bCtx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Live Preview Mockup Card with Group Chat Bubbles
                        Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              // Background
                              if (activeWallpaper.id == 'none')
                                Positioned.fill(
                                  child: Container(
                                    color: isDark ? const Color(0xFF0B141A) : const Color(0xFFF1F5F9),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.format_color_reset_rounded,
                                            size: 28,
                                            color: isDark ? Colors.white24 : Colors.black26,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            langCode == 'id' ? 'Default Polos' : 'Default Plain',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: activeWallpaper.backgroundColor,
                                      gradient: activeWallpaper.category == 'GRADIENT'
                                          ? LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                activeWallpaper.backgroundColor,
                                                activeWallpaper.backgroundColor.withValues(alpha: 0.75),
                                                const Color(0xFF0F172A),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (activeWallpaper.hasRemoteImage)
                                  Positioned.fill(
                                    child: LajuCachedImage(
                                      imageUrlOrPath: activeWallpaper.remoteImageUrl,
                                      fit: BoxFit.cover,
                                      cacheWidth: 600,
                                      cacheHeight: 400,
                                      placeholder: Container(
                                        color: activeWallpaper.backgroundColor,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                          ),
                                        ),
                                      ),
                                      errorWidget: Container(color: activeWallpaper.backgroundColor),
                                    ),
                                  ),
                              ],

                              // Sample Group Chat Bubbles Overlay
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Budi Santoso',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              langCode == 'id'
                                                  ? 'Halo semua! Selamat datang di grup baru 👋'
                                                  : 'Hello everyone! Welcome to the new group 👋',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF065F46) : const Color(0xFFD6F8EC),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          langCode == 'id'
                                              ? 'Wallpaper obrolan grup siap digunakan! ✨'
                                              : 'Group wallpaper preview ready! ✨',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF064E3B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Active Wallpaper Name Pill (top-left)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.60),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      Text(
                                        activeWallpaper.id == 'none'
                                            ? (langCode == 'id' ? 'Default Polos' : 'Default Plain')
                                            : activeWallpaper.getName(langCode),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section Title
                        Text(
                          langCode == 'id' ? 'Pilih Tema Wallpaper' : 'Select Wallpaper Theme',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Grid Picker
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.45,
                            ),
                            itemCount: allWallpapers.length,
                            itemBuilder: (context, index) {
                              final item = allWallpapers[index];
                              final isSelected = activePreviewId == item.id;

                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  setSheetState(() {
                                    activePreviewId = item.id;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: item.backgroundColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      if (item.id == 'none')
                                        Positioned.fill(
                                          child: Container(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.block_rounded,
                                                    size: 22,
                                                    color: isDark ? Colors.white54 : Colors.black45,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Polos',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white70 : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      else ...[
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: item.backgroundColor,
                                              gradient: item.category == 'GRADIENT'
                                                  ? LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        item.backgroundColor,
                                                        item.backgroundColor.withValues(alpha: 0.75),
                                                        const Color(0xFF0F172A),
                                                      ],
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (item.hasRemoteImage)
                                          Positioned.fill(
                                            child: LajuCachedImage(
                                              imageUrlOrPath: item.remoteImageUrl,
                                              fit: BoxFit.cover,
                                              cacheWidth: 200,
                                              cacheHeight: 300,
                                              placeholder: const SizedBox(),
                                              errorWidget: const SizedBox(),
                                            ),
                                          ),
                                      ],

                                      // Label pill at bottom
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.75),
                                              ],
                                            ),
                                          ),
                                          child: Text(
                                            item.id == 'none'
                                                ? (langCode == 'id' ? 'Default Polos' : 'Default Plain')
                                                : item.getName(langCode),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),

                                      // Selected Check Indicator
                                      if (isSelected)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Apply Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedWallpaperId = activePreviewId == 'none' ? null : activePreviewId;
                              });
                              Navigator.pop(bCtx);
                            },
                            child: Text(
                              langCode == 'id' ? 'Gunakan Wallpaper Ini' : 'Use This Wallpaper',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      LajuToast.error(context, context.tr('enterGroupName'));
      return;
    }

    if (_enableEmergencyWipe) {
      final pin = _killPinController.text.trim();
      if (pin.length < 4 || pin.length > 6) {
        LajuToast.error(context, 'Sandi darurat harus berupa 4-6 digit angka');
        return;
      }
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
      wallpaperId: _selectedWallpaperId,
      killPin: _enableEmergencyWipe ? _killPinController.text.trim() : null,
      authorizedWipeUserIds: _enableEmergencyWipe ? _authorizedWipeMemberIds.toList() : const [],
    );

    if (_selectedWallpaperId != null && _selectedWallpaperId != 'none') {
      await ChatAppearanceController.instance.setChatWallpaper(newGroup.id, _selectedWallpaperId);
    }

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
        avatarUrl: newGroup.avatarPath,
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
                      if (_avatarPath != null && _avatarPath!.isNotEmpty)
                        ModernAvatar(
                          name: _nameController.text.trim().isEmpty ? 'Grup' : _nameController.text.trim(),
                          imagePath: _avatarPath,
                          radius: 30,
                        )
                      else
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: textSecondary,
                            size: 26,
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
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

          // Chat Wallpaper & Disappearing Messages
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
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.wallpaper_rounded, color: Colors.purpleAccent, size: 20),
                  ),
                  title: const Text(
                    'Wallpaper Obrolan Grup',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    _selectedWallpaperId == null || _selectedWallpaperId == 'none'
                        ? 'Default (Polos)'
                        : (ChatAppearanceController.instance.findWallpaper(_selectedWallpaperId)?.getName(LocaleController.instance.value.languageCode) ?? _selectedWallpaperId!),
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWallpaperMiniPreview(_selectedWallpaperId, isDark),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                  onTap: _showWallpaperPicker,
                ),
                Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
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

          const SizedBox(height: 16),

          // Emergency Destruction / Kill Passcode Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _enableEmergencyWipe
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : (isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
                width: _enableEmergencyWipe ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.security_rounded, color: AppColors.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sandi Darurat (Emergency Wipe)',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Hapus riwayat permanen untuk semua',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enableEmergencyWipe,
                      activeColor: AppColors.danger,
                      onChanged: (val) {
                        setState(() {
                          _enableEmergencyWipe = val;
                          if (val && _authorizedWipeMemberIds.isEmpty && widget.selectedMembers.isNotEmpty) {
                            _authorizedWipeMemberIds.addAll(widget.selectedMembers.map((m) => m.id));
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_enableEmergencyWipe) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jika dipicu oleh anggota yang diizinkan, seluruh riwayat chat grup akan dihapus permanen dari server dan semua perangkat anggota.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _killPinController,
                    keyboardType: TextInputType.number,
                    obscureText: _obscureKillPin,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4.0,
                    ),
                    decoration: InputDecoration(
                      labelText: 'PIN Darurat (4-6 Digit Angka)',
                      labelStyle: TextStyle(color: textSecondary, letterSpacing: 0),
                      prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.danger),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKillPin ? Icons.visibility_off : Icons.visibility,
                          color: textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscureKillPin = !_obscureKillPin);
                        },
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Anggota yang Berhak Menghapus',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      if (widget.selectedMembers.isNotEmpty)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_authorizedWipeMemberIds.length == widget.selectedMembers.length) {
                                _authorizedWipeMemberIds.clear();
                              } else {
                                _authorizedWipeMemberIds.addAll(widget.selectedMembers.map((m) => m.id));
                              }
                            });
                          },
                          child: Text(
                            _authorizedWipeMemberIds.length == widget.selectedMembers.length
                                ? 'Batal Semua'
                                : 'Pilih Semua',
                            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Anda (Pembuat Grup) otomatis memiliki hak sandi. Centang anggota lain yang diizinkan:',
                    style: TextStyle(fontSize: 11.5, color: textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  if (widget.selectedMembers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Belum ada anggota lain yang dipilih. Hanya Anda yang dapat menggunakan sandi ini.',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    )
                  else
                    ...widget.selectedMembers.map((m) {
                      final isAuthorized = _authorizedWipeMemberIds.contains(m.id);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.danger,
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(m.phone, style: TextStyle(fontSize: 11.5, color: textSecondary)),
                        value: isAuthorized,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _authorizedWipeMemberIds.add(m.id);
                            } else {
                              _authorizedWipeMemberIds.remove(m.id);
                            }
                          });
                        },
                      );
                    }),
                ],
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
