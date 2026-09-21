// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../settings/domain/account_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../domain/status_service.dart';
import 'status_view_screen.dart';
import 'status_privacy_contact_picker_screen.dart';
import 'text_status_composer_screen.dart';
import 'camera_status_screen.dart';


class StatusContactGroup {
  final String name;
  final String time;
  final int storyCount;
  final Color storyColor;
  final List<StatusStoryItem> stories;
  final bool isViewed;

  const StatusContactGroup({
    required this.name,
    required this.time,
    required this.storyCount,
    required this.storyColor,
    required this.stories,
    this.isViewed = false,
  });
}

class StatusScreen extends StatefulWidget {
  static final GlobalKey<StatusScreenState> statusKey = GlobalKey<StatusScreenState>();

  const StatusScreen({super.key});

  @override
  StatusScreenState createState() => StatusScreenState();
}

class StatusScreenState extends State<StatusScreen> {
  void showMediaPicker() {
    _showMediaPickerSheet();
  }

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _selectedPrivacy = 'contacts'; // 'contacts', 'contacts_except', 'only_share'
  final List<StatusStoryItem> _myStories = [];
  final List<StatusContactGroup> _recentUpdates = [];
  final List<StatusContactGroup> _viewedUpdates = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    // Background polling every 8 seconds for live updates from contacts
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadStatuses());
  }

  Future<void> _loadStatuses() async {
    try {
      final myStatuses = await StatusService.instance.getMyStatuses();
      final contactGroups = await StatusService.instance.getContactsStatuses();

      if (!mounted) return;
      setState(() {
        _myStories
          ..clear()
          ..addAll(myStatuses);

        _recentUpdates.clear();
        _viewedUpdates.clear();
        for (final group in contactGroups) {
          if (group.isViewed) {
            _viewedUpdates.add(group);
          } else {
            _recentUpdates.add(group);
          }
        }
      });
    } catch (e) {
      debugPrint('[StatusScreen] _loadStatuses error: $e');
    }
  }

  Future<void> _openTextStatusComposer() async {
    final result = await Navigator.push<StatusStoryItem>(
      context,
      MaterialPageRoute(builder: (_) => const TextStatusComposerScreen()),
    );
    if (result != null) {
      final posted = await StatusService.instance.postStatus(
        type: 'TEXT',
        content: result.text,
        backgroundColor: result.backgroundColor,
      );
      if (mounted) {
        setState(() {
          _myStories.insert(0, posted ?? result);
        });
        LajuToast.success(context, 'Status teks berhasil dibagikan');
        _loadStatuses();
      }
    }
  }

  Future<void> _openCameraStatus() async {
    // Open the real device hardware camera directly (native OS permission handled automatically)
    final path = await DeviceMediaService.openCamera();
    if (path != null && mounted && File(path).existsSync()) {
      // Open editor with captured device photo so user can add caption and send
      final result = await Navigator.push<StatusStoryItem>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraStatusScreen(initialPhotoPath: path),
        ),
      );
      if (result != null && mounted) {
        final posted = await StatusService.instance.postStatus(
          type: 'IMAGE',
          content: result.imageAsset ?? path,
          caption: result.text,
          backgroundColor: result.backgroundColor,
        );
        setState(() {
          _myStories.insert(0, posted ?? result);
        });
        LajuToast.success(context, 'Status foto berhasil dibagikan');
        _loadStatuses();
      }
    }
  }

  Future<void> _openGalleryStatus() async {
    final path = await DeviceMediaService.openGallery();
    if (path != null && mounted && File(path).existsSync()) {
      final result = await Navigator.push<StatusStoryItem>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraStatusScreen(initialPhotoPath: path),
        ),
      );
      if (result != null && mounted) {
        final posted = await StatusService.instance.postStatus(
          type: 'IMAGE',
          content: result.imageAsset ?? path,
          caption: result.text,
          backgroundColor: result.backgroundColor,
        );
        setState(() {
          _myStories.insert(0, posted ?? result);
        });
        LajuToast.success(context, 'Status foto berhasil dibagikan');
        _loadStatuses();
      }
    }
  }

  Future<void> _openStorageStatus() async {
    final granted = await AppPermissionService.requestPermission(
      context,
      type: AppPermissionType.storage,
    );
    if (!granted || !mounted) return;

    final path = await DeviceMediaService.openGallery();
    if (path != null && mounted && File(path).existsSync()) {
      final result = await Navigator.push<StatusStoryItem>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraStatusScreen(initialPhotoPath: path),
        ),
      );
      if (result != null && mounted) {
        final posted = await StatusService.instance.postStatus(
          type: 'IMAGE',
          content: result.imageAsset ?? path,
          caption: result.text,
          backgroundColor: result.backgroundColor,
        );
        setState(() {
          _myStories.insert(0, posted ?? result);
        });
        LajuToast.success(context, 'Status foto berhasil dibagikan');
        _loadStatuses();
      }
    }
  }

  void _showMediaPickerSheet() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pilih Media Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ambil foto baru atau pilih dari galeri untuk status Anda',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMediaPickerOption(
                      icon: Icons.camera_alt_rounded,
                      iconBg: AppColors.primary,
                      title: 'Kamera',
                      subtitle: 'Ambil foto langsung',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCameraStatus();
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMediaPickerOption(
                      icon: Icons.photo_library_rounded,
                      iconBg: const Color(0xFFEC4899),
                      title: 'Galeri',
                      subtitle: 'Pilih dari galeri HP',
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openGalleryStatus();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openTextStatusComposer();
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                  label: Text(
                    'Buat Status Teks',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPickerOption({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.05 : 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.06),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconBg, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyStatusActions() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary),
              title: Text('Lihat Status Saya', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatusViewScreen(
                      contactName: 'My Status (You)',
                      stories: _myStories,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFEC4899)),
              title: Text('Buka Galeri Foto HP', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827))),
              onTap: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _openGalleryStatus();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.green),
              title: Text('Tambah Status Kamera', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827))),
              onTap: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _openCameraStatus();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
              title: Text('Tambah Status Teks', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827))),
              onTap: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _openTextStatusComposer();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_shared_outlined, color: Color(0xFF8B5CF6)),
              title: Text('Pilih Berkas dari Penyimpanan', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827))),
              onTap: () async {
                Navigator.pop(ctx);
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  _openStorageStatus();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Hapus Semua Status', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                final storiesToDelete = List<StatusStoryItem>.from(_myStories);
                setState(() => _myStories.clear());
                for (final story in storiesToDelete) {
                  if (story.id != null) {
                    await StatusService.instance.deleteStatus(story.id!);
                  }
                }
                if (mounted) {
                  LajuToast.info(context, 'Status saya telah dihapus');
                  _loadStatuses();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Set<String> _excludedContactIds = {};
  Set<String> _onlyShareContactIds = {};

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openContactPicker(
    BuildContext context,
    PrivacyPickerMode mode,
    StateSetter setSheetState,
  ) async {
    final currentSelection = mode == PrivacyPickerMode.exclude
        ? _excludedContactIds
        : _onlyShareContactIds;

    final result = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StatusPrivacyContactPickerScreen(
          mode: mode,
          initialSelectedIds: currentSelection,
        ),
      ),
    );

    if (result != null) {
      setSheetState(() {
        if (mode == PrivacyPickerMode.exclude) {
          _excludedContactIds = result;
          _selectedPrivacy = 'contacts_except';
        } else {
          _onlyShareContactIds = result;
          _selectedPrivacy = 'only_share';
        }
      });
      setState(() {});
    }
  }

  void _showStatusPrivacyBottomSheet() {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final excludedCount = _excludedContactIds.length;
            final onlyShareCount = _onlyShareContactIds.length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status privacy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Who can see my status updates',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option 1: My contacts
                    RadioListTile<String>(
                      title: const Text('My contacts', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('All your verified contacts on LAJU', style: TextStyle(fontSize: 12.5)),
                      value: 'contacts',
                      groupValue: _selectedPrivacy,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => _selectedPrivacy = val);
                          setState(() => _selectedPrivacy = val);
                        }
                      },
                    ),

                    // Option 2: My contacts except... (Select Contacts to Exclude)
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'My contacts except...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openContactPicker(context, PrivacyPickerMode.exclude, setSheetState),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    excludedCount > 0 ? '$excludedCount excluded' : 'Select',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: excludedCount > 0 ? const Color(0xFFDC2626) : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        excludedCount > 0 ? '$excludedCount contacts excluded' : 'Tap to exclude contacts',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: excludedCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280),
                        ),
                      ),
                      value: 'contacts_except',
                      groupValue: _selectedPrivacy,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        setSheetState(() => _selectedPrivacy = 'contacts_except');
                        setState(() => _selectedPrivacy = 'contacts_except');
                        await _openContactPicker(context, PrivacyPickerMode.exclude, setSheetState);
                      },
                    ),

                    // Option 3: Only share with... (Select Contacts to Include)
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Only share with...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openContactPicker(context, PrivacyPickerMode.include, setSheetState),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    onlyShareCount > 0 ? '$onlyShareCount selected' : 'Select',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        onlyShareCount > 0 ? '$onlyShareCount contacts selected' : 'Tap to select contacts',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: onlyShareCount > 0 ? AppColors.primary : const Color(0xFF6B7280),
                        ),
                      ),
                      value: 'only_share',
                      groupValue: _selectedPrivacy,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        setSheetState(() => _selectedPrivacy = 'only_share');
                        setState(() => _selectedPrivacy = 'only_share');
                        await _openContactPicker(context, PrivacyPickerMode.include, setSheetState);
                      },
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Changes to your privacy settings won\'t affect status updates that you\'ve sent already.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          LajuToast.success(context, 'Status privacy updated successfully');
                        },
                        child: const Text(
                          'Save Privacy',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();

    final filteredRecent = query.isEmpty
        ? _recentUpdates
        : _recentUpdates.where((item) {
            return item.name.toLowerCase().contains(query) ||
                item.time.toLowerCase().contains(query) ||
                item.stories.any((s) => s.text.toLowerCase().contains(query));
          }).toList();

    final filteredViewed = query.isEmpty
        ? _viewedUpdates
        : _viewedUpdates.where((item) {
            return item.name.toLowerCase().contains(query) ||
                item.time.toLowerCase().contains(query) ||
                item.stories.any((s) => s.text.toLowerCase().contains(query));
          }).toList();

    final hasResults = filteredRecent.isNotEmpty || filteredViewed.isNotEmpty || query.isEmpty;

    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: LajuGlassAppBar(
        titleSpacing: 16,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search status updates...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                    fontSize: 15,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                'Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
            tooltip: _isSearching ? 'Close' : 'Search',
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
              icon: Icon(
                Icons.more_vert_rounded,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'privacy', child: Text('Status privacy')),
                PopupMenuItem(value: 'settings', child: Text('Settings')),
              ],
              onSelected: (val) {
                if (val == 'privacy') {
                  _showStatusPrivacyBottomSheet();
                } else if (val == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              },
            ),
        ],
      ),
      body: LajuGlassBackground(
        child: RefreshIndicator(
          onRefresh: _loadStatuses,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
          children: [
            // My Status Tile (only shown when not filtering or when empty query)
            if (!_isSearching || query.isEmpty) ...[
              LajuGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (_myStories.isEmpty) {
                      _showMediaPickerSheet();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatusViewScreen(
                            contactName: 'My Status (You)',
                            stories: _myStories,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      _myStories.isEmpty
                          ? Stack(
                              children: [
                                ModernAvatar(
                                  name: AccountController.instance.userName,
                                  radius: 25,
                                  isVerified: true,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF34D399), AppColors.primary, Color(0xFF06B6D4)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ModernAvatar(
                                name: AccountController.instance.userName,
                                radius: 23,
                                isVerified: true,
                              ),
                            ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Status',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _myStories.isEmpty
                                  ? 'Tap to add status update'
                                  : '${_myStories.first.time} • ${_myStories.length} ${_myStories.length > 1 ? 'updates' : 'update'}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _myStories.isEmpty
                                    ? (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280))
                                    : AppColors.primary,
                                fontWeight: _myStories.isEmpty ? FontWeight.normal : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_myStories.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              size: 20,
                            ),
                            onPressed: _showMyStatusActions,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: isDark ? 0.08 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.primary),
                                onPressed: _showMediaPickerSheet,
                                tooltip: 'Kamera / Galeri',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
                                onPressed: _openTextStatusComposer,
                                tooltip: 'Text',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (filteredRecent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Recent updates',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${filteredRecent.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LajuGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(filteredRecent.length, (index) {
                    final item = filteredRecent[index];
                    final isLast = index == filteredRecent.length - 1;
                    return Column(
                      children: [
                        _buildStatusTile(
                          context: context,
                          isDark: isDark,
                          name: item.name,
                          time: item.time,
                          storyCount: item.storyCount,
                          storyColor: item.storyColor,
                          stories: item.stories,
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 68,
                            endIndent: 16,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (filteredViewed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Viewed updates',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${filteredViewed.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              LajuGlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: List.generate(filteredViewed.length, (index) {
                    final item = filteredViewed[index];
                    final isLast = index == filteredViewed.length - 1;
                    return Column(
                      children: [
                        _buildStatusTile(
                          context: context,
                          isDark: isDark,
                          name: item.name,
                          time: item.time,
                          storyCount: item.storyCount,
                          storyColor: item.storyColor,
                          stories: item.stories,
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 68,
                            endIndent: 16,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ],

            if (filteredRecent.isEmpty && filteredViewed.isEmpty && query.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.donut_large_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Pembaruan Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pembaruan status dari kontak Anda yang terenkripsi akan ditampilkan di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (!hasResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade500),
                      const SizedBox(height: 12),
                      Text(
                        'No status updates found for "$query"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
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

  Widget _buildStatusTile({
    required BuildContext context,
    required bool isDark,
    required String name,
    required String time,
    required int storyCount,
    required Color storyColor,
    required List<StatusStoryItem> stories,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: storyColor, width: 2.2),
          boxShadow: [
            if (storyColor != const Color(0xFFD1D5DB) && storyColor != const Color(0xFF475569))
              BoxShadow(
                color: storyColor.withValues(alpha: 0.35),
                blurRadius: 6,
              ),
          ],
        ),
        child: ModernAvatar(
          name: name,
          radius: 22,
          isVerified: true,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        '$time • $storyCount ${storyCount > 1 ? 'updates' : 'update'}',
        style: TextStyle(
          fontSize: 12.5,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StatusViewScreen(
              contactName: name,
              stories: stories,
            ),
          ),
        );
      },
    );
  }
}
