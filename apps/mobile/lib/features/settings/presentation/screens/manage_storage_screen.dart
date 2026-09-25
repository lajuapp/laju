import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/data_storage_controller.dart';

class ManageStorageScreen extends StatefulWidget {
  const ManageStorageScreen({super.key});

  @override
  State<ManageStorageScreen> createState() => _ManageStorageScreenState();
}

class _ManageStorageScreenState extends State<ManageStorageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataStorageController.instance.calculateActualStorage();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showClearCacheDialog() {
    final controller = DataStorageController.instance;
    final isDark = ThemeModeController.instance.isDarkMode(context);

    if (controller.lajuCacheBytes == 0) {
      LajuToast.info(context, context.tr('cacheAlreadyEmpty'));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('clearCache'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          context.tr('clearCacheConfirmDesc'),
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.clearCache();
              if (mounted) {
                LajuToast.success(context, context.tr('cacheCleared'));
              }
            },
            child: Text(context.tr('clear')),
          ),
        ],
      ),
    );
  }

  void _showChatStorageDetails(ChatStorageItem item) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final controller = DataStorageController.instance;

    bool deletePhotos = true;
    bool deleteVideos = true;
    bool deleteAudio = true;
    bool deleteDocs = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) {
        return StatefulBuilder(
          builder: (mCtx, setModalState) {
            final totalSelected = (deletePhotos ? item.photosBytes : 0) +
                (deleteVideos ? item.videosBytes : 0) +
                (deleteAudio ? item.audioBytes : 0) +
                (deleteDocs ? item.docsBytes : 0);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ModernAvatar(
                          name: item.name,
                          size: 46,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${context.tr('storageTotal')}: ${DataStorageController.formatBytes(item.totalBytes)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: isDark ? AppColors.darkSurfaceBorder : null),
                    const SizedBox(height: 8),

                    // Media items
                    _buildMediaCheckbox(
                      isDark: isDark,
                      title: context.tr('photos'),
                      sizeBytes: item.photosBytes,
                      icon: Icons.photo_outlined,
                      color: Colors.blueAccent,
                      value: deletePhotos,
                      onChanged: item.photosBytes > 0
                          ? (v) => setModalState(() => deletePhotos = v ?? false)
                          : null,
                    ),
                    _buildMediaCheckbox(
                      isDark: isDark,
                      title: context.tr('videos'),
                      sizeBytes: item.videosBytes,
                      icon: Icons.videocam_outlined,
                      color: Colors.deepPurpleAccent,
                      value: deleteVideos,
                      onChanged: item.videosBytes > 0
                          ? (v) => setModalState(() => deleteVideos = v ?? false)
                          : null,
                    ),
                    _buildMediaCheckbox(
                      isDark: isDark,
                      title: context.tr('audio'),
                      sizeBytes: item.audioBytes,
                      icon: Icons.headphones_outlined,
                      color: Colors.orangeAccent,
                      value: deleteAudio,
                      onChanged: item.audioBytes > 0
                          ? (v) => setModalState(() => deleteAudio = v ?? false)
                          : null,
                    ),
                    _buildMediaCheckbox(
                      isDark: isDark,
                      title: context.tr('documents'),
                      sizeBytes: item.docsBytes,
                      icon: Icons.insert_drive_file_outlined,
                      color: Colors.teal,
                      value: deleteDocs,
                      onChanged: item.docsBytes > 0
                          ? (v) => setModalState(() => deleteDocs = v ?? false)
                          : null,
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: totalSelected > 0 ? AppColors.error : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: totalSelected > 0
                            ? () async {
                                final msg = '${context.tr('mediaDeleted')} (${DataStorageController.formatBytes(totalSelected)})';
                                Navigator.pop(bContext);
                                await controller.clearChatMedia(
                                  item.id,
                                  photos: deletePhotos,
                                  videos: deleteVideos,
                                  audio: deleteAudio,
                                  docs: deleteDocs,
                                );
                                if (mounted) {
                                  LajuToast.success(context, msg);
                                }
                              }
                            : null,
                        child: Text(
                          '${context.tr('deleteSelectedMedia')} (${DataStorageController.formatBytes(totalSelected)})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
  }

  Widget _buildMediaCheckbox({
    required bool isDark,
    required String title,
    required int sizeBytes,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  DataStorageController.formatBytes(sizeBytes),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            activeColor: AppColors.primary,
            value: sizeBytes > 0 ? value : false,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final controller = DataStorageController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final totalDevice = controller.totalDeviceBytes;
        final lajuTotal = controller.lajuTotalBytes;
        final otherApps = controller.otherAppsBytes;
        final free = controller.freeBytes;

        // Proportions for bar
        final lajuFraction = lajuTotal / totalDevice;
        final otherAppsFraction = otherApps / totalDevice;
        final freeFraction = free / totalDevice;

        final filteredChats = controller.chatStorageList.where((chat) {
          if (_searchQuery.trim().isEmpty) return true;
          return chat.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            title: Text(context.tr('manageStorage')),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () => controller.calculateActualStorage(),
                color: AppColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                  // Top Bar Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('deviceStorage'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              '${DataStorageController.formatBytes(lajuTotal + otherApps)} / ${DataStorageController.formatBytes(totalDevice)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 12,
                            child: Row(
                              children: [
                                Flexible(
                                  flex: (lajuFraction * 1000).toInt().clamp(1, 1000),
                                  child: Container(color: AppColors.primary),
                                ),
                                Flexible(
                                  flex: (otherAppsFraction * 1000).toInt().clamp(1, 1000),
                                  child: Container(color: Colors.amber[700]),
                                ),
                                Flexible(
                                  flex: (freeFraction * 1000).toInt().clamp(1, 1000),
                                  child: Container(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildLegendItem(
                              color: AppColors.primary,
                              label: 'LAJU',
                              sizeStr: DataStorageController.formatBytes(lajuTotal),
                              isDark: isDark,
                            ),
                            _buildLegendItem(
                              color: Colors.amber[700]!,
                              label: context.tr('otherApps'),
                              sizeStr: DataStorageController.formatBytes(otherApps),
                              isDark: isDark,
                            ),
                            _buildLegendItem(
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                              label: context.tr('freeSpace'),
                              sizeStr: DataStorageController.formatBytes(free),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Categories Breakdown
                  LajuGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 20),
                            ),
                            title: Text(
                              context.tr('encryptedMedia'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            trailing: Text(
                              DataStorageController.formatBytes(controller.lajuMediaBytes),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.dns_outlined, color: Colors.purple, size: 20),
                            ),
                            title: Text(
                              context.tr('databaseAndKeys'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            trailing: Text(
                              DataStorageController.formatBytes(controller.lajuDatabaseBytes),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.cleaning_services_outlined, color: Colors.orange, size: 20),
                            ),
                            title: Text(
                              context.tr('cachedData'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              DataStorageController.formatBytes(controller.lajuCacheBytes),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: _showClearCacheDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              child: Text(
                                context.tr('clearCache'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Chats Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('chatsStorage'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${controller.chatStorageList.length} ${context.tr('chatsCount')}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Box
                  LajuGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                        hintText: context.tr('searchChats'),
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Chat list
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: filteredChats.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                context.tr('noChatsFound'),
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredChats.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6),
                            ),
                            itemBuilder: (context, index) {
                              final chat = filteredChats[index];
                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: ModernAvatar(
                                    name: chat.name,
                                    size: 40,
                                  ),
                                  title: Text(
                                    chat.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  subtitle: Text(
                                    chat.isGroup ? context.tr('groupChat') : context.tr('directChat'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DataStorageController.formatBytes(chat.totalBytes),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showChatStorageDetails(chat),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String sizeStr,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              ),
            ),
            Text(
              sizeStr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
