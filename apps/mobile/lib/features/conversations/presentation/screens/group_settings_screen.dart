import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/group_controller.dart';

class GroupSettingsScreen extends StatelessWidget {
  final String groupId;

  const GroupSettingsScreen({super.key, required this.groupId});

  void _showPermissionDialog({
    required BuildContext context,
    required String title,
    required bool currentValue,
    required ValueChanged<bool> onSelected,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(
              activeColor: AppColors.primary,
              title: Text(
                context.tr('allMembers'),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
              ),
              value: true,
              groupValue: currentValue,
              onChanged: (val) {
                if (val != null) {
                  onSelected(val);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<bool>(
              activeColor: AppColors.primary,
              title: Text(
                context.tr('onlyAdmins'),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
              ),
              value: false,
              groupValue: currentValue,
              onChanged: (val) {
                if (val != null) {
                  onSelected(val);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAdminsSheet(BuildContext context, GroupModel group) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  context.tr('editGroupAdmins'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Text(
                  context.tr('selectAdminsDesc'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: group.members.length,
                  itemBuilder: (context, index) {
                    final member = group.members[index];
                    final isOwner = member.id == 'm-you';

                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      value: member.isAdmin,
                      title: Text(
                        member.name + (isOwner ? ' (Owner)' : ''),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        member.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                        ),
                      ),
                      onChanged: isOwner
                          ? null // Owner is permanently admin
                          : (val) {
                              GroupController.instance.toggleAdmin(groupId, member.id);
                              LajuToast.info(
                                context,
                                member.isAdmin
                                    ? '${member.name} ${context.tr('adminDismissed')}'
                                    : '${member.name} ${context.tr('adminPromoted')}',
                              );
                              Navigator.pop(bCtx);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isDark ? AppColors.darkBackground : Colors.grey[50];
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return AnimatedBuilder(
      animation: GroupController.instance,
      builder: (context, _) {
        final group = GroupController.instance.getGroup(groupId);
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.tr('groupSettings'))),
            body: Center(child: Text(context.tr('noChatsFound'))),
          );
        }

        final adminCount = group.members.where((m) => m.isAdmin).length;

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
              context.tr('groupSettings'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('adminOnlyNotice'),
                        style: TextStyle(fontSize: 12.5, color: textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Permissions Section
              Material(
                color: cardColor,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        context.tr('editGroupInfo'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        group.canEditGroupInfo ? context.tr('allMembers') : context.tr('onlyAdmins'),
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () {
                        _showPermissionDialog(
                          context: context,
                          title: context.tr('editGroupInfo'),
                          currentValue: group.canEditGroupInfo,
                          onSelected: (val) {
                            GroupController.instance.updatePermissions(groupId, canEditGroupInfo: val);
                            LajuToast.info(context, context.tr('permissionsUpdated'));
                          },
                        );
                      },
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent, size: 20),
                      ),
                      title: Text(
                        context.tr('sendMessages'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        group.canSendMessages ? context.tr('allMembers') : context.tr('onlyAdmins'),
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () {
                        _showPermissionDialog(
                          context: context,
                          title: context.tr('sendMessages'),
                          currentValue: group.canSendMessages,
                          onSelected: (val) {
                            GroupController.instance.updatePermissions(groupId, canSendMessages: val);
                            LajuToast.info(context, context.tr('permissionsUpdated'));
                          },
                        );
                      },
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.group_add_outlined, color: Colors.purpleAccent, size: 20),
                      ),
                      title: Text(
                        context.tr('addOtherMembers'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        group.canAddMembers ? context.tr('allMembers') : context.tr('onlyAdmins'),
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () {
                        _showPermissionDialog(
                          context: context,
                          title: context.tr('addOtherMembers'),
                          currentValue: group.canAddMembers,
                          onSelected: (val) {
                            GroupController.instance.updatePermissions(groupId, canAddMembers: val);
                            LajuToast.info(context, context.tr('permissionsUpdated'));
                          },
                        );
                      },
                    ),
                    Divider(height: 1, color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFF3F4F6)),
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_user_outlined, color: Colors.amber, size: 20),
                      ),
                      title: Text(
                        context.tr('approveNewMembers'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        context.tr('approveNewMembersSub'),
                        style: TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                      activeColor: AppColors.primary,
                      value: group.requireApprovalToJoin,
                      onChanged: (val) {
                        GroupController.instance.updatePermissions(groupId, requireApprovalToJoin: val);
                        LajuToast.info(
                          context,
                          val ? context.tr('approvalEnabled') : context.tr('approvalDisabled'),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Admins Management Section
              Material(
                color: cardColor,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.darkSurfaceBorder : const Color(0xFFE5E7EB),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    context.tr('editGroupAdmins'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '$adminCount ${context.tr('adminsCount')}',
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () => _showEditAdminsSheet(context, group),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
