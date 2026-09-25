import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/data_storage_controller.dart';
import 'manage_storage_screen.dart';
import 'network_usage_screen.dart';
import 'proxy_settings_screen.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataStorageController.instance.calculateActualStorage();
    });
  }

  String _formatAutoDownloadSummary(BuildContext context, Set<String> types) {
    if (types.isEmpty) {
      return context.tr('noMedia');
    }
    const all = {'photos', 'audio', 'videos', 'documents'};
    if (types.containsAll(all)) {
      return context.tr('allMedia');
    }
    final labels = <String>[];
    if (types.contains('photos')) labels.add(context.tr('photos'));
    if (types.contains('audio')) labels.add(context.tr('audio'));
    if (types.contains('videos')) labels.add(context.tr('videos'));
    if (types.contains('documents')) labels.add(context.tr('documents'));
    return labels.join(', ');
  }

  void _showAutoDownloadSheet({
    required BuildContext context,
    required String title,
    required Set<String> initialTypes,
    required ValueChanged<Set<String>> onSave,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final selected = Set<String>.from(initialTypes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildCheckboxTile(
                      isDark: isDark,
                      title: context.tr('photos'),
                      icon: Icons.photo_outlined,
                      value: selected.contains('photos'),
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            selected.add('photos');
                          } else {
                            selected.remove('photos');
                          }
                        });
                      },
                    ),
                    _buildCheckboxTile(
                      isDark: isDark,
                      title: context.tr('audio'),
                      icon: Icons.headphones_outlined,
                      value: selected.contains('audio'),
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            selected.add('audio');
                          } else {
                            selected.remove('audio');
                          }
                        });
                      },
                    ),
                    _buildCheckboxTile(
                      isDark: isDark,
                      title: context.tr('videos'),
                      icon: Icons.videocam_outlined,
                      value: selected.contains('videos'),
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            selected.add('videos');
                          } else {
                            selected.remove('videos');
                          }
                        });
                      },
                    ),
                    _buildCheckboxTile(
                      isDark: isDark,
                      title: context.tr('documents'),
                      icon: Icons.insert_drive_file_outlined,
                      value: selected.contains('documents'),
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true) {
                            selected.add('documents');
                          } else {
                            selected.remove('documents');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(bContext),
                            child: Text(
                              context.tr('cancel'),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              onSave(selected);
                              Navigator.pop(bContext);
                            },
                            child: Text(context.tr('saveSettings')),
                          ),
                        ),
                      ],
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

  Widget _buildCheckboxTile({
    required bool isDark,
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
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
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
          appBar: LajuGlassAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('storageTitle'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: RefreshIndicator(
              onRefresh: () => controller.calculateActualStorage(),
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
                children: [
                // Storage & Network section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'STORAGE & NETWORK',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                LajuGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.folder_outlined, color: isDark ? AppColors.primary : const Color(0xFF2563EB), size: 20),
                          ),
                          title: Text(
                            context.tr('manageStorage'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            '${DataStorageController.formatBytes(controller.lajuTotalBytes)} ${context.tr('storageTotal').toLowerCase()} • ${DataStorageController.formatBytes(controller.freeBytes)} ${context.tr('freeSpace').toLowerCase()}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ManageStorageScreen()),
                            );
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 56,
                        endIndent: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.data_usage_rounded, color: AppColors.cyan, size: 20),
                          ),
                          title: Text(
                            context.tr('networkUsage'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            '${DataStorageController.formatBytes(controller.totalNetworkSent)} ${context.tr('totalSent').toLowerCase()} • ${DataStorageController.formatBytes(controller.totalNetworkReceived)} ${context.tr('totalReceived').toLowerCase()}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NetworkUsageScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Media Auto-Download Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    context.tr('mediaAutoDownload').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                LajuGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            context.tr('whenUsingMobileData'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            _formatAutoDownloadSummary(context, controller.mobileDataTypes),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            _showAutoDownloadSheet(
                              context: context,
                              title: context.tr('whenUsingMobileData'),
                              initialTypes: controller.mobileDataTypes,
                              onSave: controller.setMobileDataTypes,
                            );
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            context.tr('whenConnectedWifi'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            _formatAutoDownloadSummary(context, controller.wifiTypes),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            _showAutoDownloadSheet(
                              context: context,
                              title: context.tr('whenConnectedWifi'),
                              initialTypes: controller.wifiTypes,
                              onSave: controller.setWifiTypes,
                            );
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(
                            context.tr('whenRoaming'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            _formatAutoDownloadSummary(context, controller.roamingTypes),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                          onTap: () {
                            _showAutoDownloadSheet(
                              context: context,
                              title: context.tr('whenRoaming'),
                              initialTypes: controller.roamingTypes,
                              onSave: controller.setRoamingTypes,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Proxy Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    context.tr('proxy').toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                LajuGlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          color: controller.useProxy
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : const Color(0xFF374151)),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        context.tr('proxy'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        controller.useProxy
                            ? '${context.tr('connectedStatus')} (${controller.proxyHost})'
                            : context.tr('proxySub'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                            value: controller.useProxy,
                            onChanged: (v) {
                              controller.setUseProxy(v);
                              LajuToast.info(
                                context,
                                v ? context.tr('proxyEnabledToast') : context.tr('proxyDisabledToast'),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProxySettingsScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}
