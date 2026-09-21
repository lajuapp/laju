import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/account_controller.dart';
import 'biometric_settings_screen.dart';
import 'blocked_contacts_screen.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _readReceipts = true;
  String _lastSeen = 'My contacts';
  String _profilePhoto = 'My contacts';
  String _disappearingTimer = '24 hours';

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('privacyTitle'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
          children: [
            // Section 1: Visibility Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                context.tr('privacyTitle').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
                  _buildPrivacyRow(
                    context,
                    context.tr('lastSeenOnline'),
                    _lastSeen,
                    isFirst: true,
                    onTap: () {
                      _showSelectionDialog(
                        context.tr('lastSeenOnline'),
                        ['Everyone', 'My contacts', 'My contacts except...', 'Nobody'],
                        _lastSeen,
                        (val) => setState(() => _lastSeen = val),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildPrivacyRow(
                    context,
                    context.tr('profilePhoto'),
                    _profilePhoto,
                    onTap: () {
                      _showSelectionDialog(
                        context.tr('profilePhoto'),
                        ['Everyone', 'My contacts', 'Nobody'],
                        _profilePhoto,
                        (val) => setState(() => _profilePhoto = val),
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _buildPrivacyRow(
                    context,
                    context.tr('disappearingTimer'),
                    _disappearingTimer,
                    isLast: true,
                    onTap: () {
                      _showSelectionDialog(
                        context.tr('disappearingTimer'),
                        ['24 hours', '7 days', '90 days', 'Off'],
                        _disappearingTimer,
                        (val) => setState(() => _disappearingTimer = val),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Section 2: Messaging / Receipts
            LajuGlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 20,
              blurSigma: 16,
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  title: Text(
                    context.tr('readReceipts'),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  subtitle: Text(
                    context.tr('readReceiptsSub'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                  value: _readReceipts,
                  onChanged: (val) {
                    setState(() => _readReceipts = val);
                    LajuToast.info(context, 'Read receipts ${val ? 'enabled' : 'disabled'}');
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Section 3: Security & Restrictions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'SECURITY & LOCKS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
                  // App Lock (Biometric & PIN Settings)
                  ListenableBuilder(
                    listenable: AppLockController.instance,
                    builder: (context, _) {
                      final ctrl = AppLockController.instance;
                      String statusText;
                      if (!ctrl.isAppLockEnabled) {
                        statusText = 'Nonaktif (Disabled)';
                      } else if (ctrl.isBiometricEnabled) {
                        statusText = 'Aktif • Sidik Jari & PIN';
                      } else {
                        statusText = 'Aktif • PIN Default';
                      }

                      return Material(
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
                            child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 22),
                          ),
                          title: Text(
                            context.tr('appLock'),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
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
                              MaterialPageRoute(builder: (context) => const BiometricSettingsScreen()),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _buildDivider(isDark),

                  // Blocked Contacts
                  ListenableBuilder(
                    listenable: AccountController.instance,
                    builder: (context, _) {
                      final blockedCount = AccountController.instance.blockedContacts.length;

                      return Material(
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
                            child: const Icon(Icons.block_rounded, color: AppColors.danger, size: 22),
                          ),
                          title: Text(
                            context.tr('blockedContacts'),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$blockedCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 6),
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
                              MaterialPageRoute(builder: (context) => const BlockedContactsScreen()),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      endIndent: 16,
      color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildPrivacyRow(
    BuildContext context,
    String title,
    String currentVal, {
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          currentVal,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showSelectionDialog(String title, List<String> options, String selected, ValueChanged<String> onSelect) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        children: options.map((opt) {
          return RadioListTile<String>(
            title: Text(
              opt,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            value: opt,
            groupValue: selected,
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                onSelect(val);
                Navigator.pop(ctx);
                LajuToast.success(context, '$title set to $val');
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
