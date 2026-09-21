import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/data_storage_controller.dart';

class NetworkUsageScreen extends StatelessWidget {
  const NetworkUsageScreen({super.key});

  void _showResetDialog(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final controller = DataStorageController.instance;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('resetStats'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Text(
          context.tr('resetStatsConfirmDesc'),
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
            onPressed: () {
              Navigator.pop(ctx);
              controller.resetNetworkStats();
              LajuToast.success(context, context.tr('statsResetToast'));
            },
            child: Text(context.tr('reset')),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final controller = DataStorageController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final totalSent = controller.totalNetworkSent;
        final totalReceived = controller.totalNetworkReceived;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            title: Text(context.tr('networkUsage')),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Hero Summary Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Sent
                        Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_upward_rounded, color: Color(0xFF34D399), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('totalSent'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DataStorageController.formatBytes(totalSent),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        ),
                        // Received
                        Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_downward_rounded, color: Color(0xFF60A5FA), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('totalReceived'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DataStorageController.formatBytes(totalReceived),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Detailed stats breakdown card
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _buildStatTile(
                          isDark: isDark,
                          icon: Icons.call_outlined,
                          iconColor: Colors.blueAccent,
                          title: context.tr('callsUsage'),
                          subtitle: '${controller.callsCount} ${context.tr('callsCount')}',
                          sentBytes: controller.callsBytesSent,
                          receivedBytes: controller.callsBytesReceived,
                          context: context,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        _buildStatTile(
                          isDark: isDark,
                          icon: Icons.photo_library_outlined,
                          iconColor: Colors.purpleAccent,
                          title: context.tr('mediaUsage'),
                          subtitle: context.tr('mediaUsageSub'),
                          sentBytes: controller.mediaBytesSent,
                          receivedBytes: controller.mediaBytesReceived,
                          context: context,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        _buildStatTile(
                          isDark: isDark,
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: Colors.teal,
                          title: context.tr('messagesUsage'),
                          subtitle: '${controller.messagesCountSent} sent • ${controller.messagesCountReceived} received',
                          sentBytes: controller.messagesBytesSent,
                          receivedBytes: controller.messagesBytesReceived,
                          context: context,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        _buildStatTile(
                          isDark: isDark,
                          icon: Icons.amp_stories_outlined,
                          iconColor: Colors.amber[700]!,
                          title: context.tr('statusUsage'),
                          subtitle: context.tr('statusUsageSub'),
                          sentBytes: controller.statusBytesSent,
                          receivedBytes: controller.statusBytesReceived,
                          context: context,
                        ),
                        Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                        _buildStatTile(
                          isDark: isDark,
                          icon: Icons.travel_explore_rounded,
                          iconColor: Colors.indigoAccent,
                          title: context.tr('roamingUsage'),
                          subtitle: context.tr('roamingUsageSub'),
                          sentBytes: controller.roamingBytesSent,
                          receivedBytes: controller.roamingBytesReceived,
                          context: context,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reset Statistics Card
                  LajuGlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restart_alt_rounded, color: AppColors.error, size: 22),
                        ),
                        title: Text(
                          context.tr('resetStats'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${context.tr('sinceDate')} ${_formatDate(controller.networkStatsResetDate)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                        onTap: () => _showResetDialog(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int sentBytes,
    required int receivedBytes,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 2),
                  Text(
                    DataStorageController.formatBytes(sentBytes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 2),
                  Text(
                    DataStorageController.formatBytes(receivedBytes),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
