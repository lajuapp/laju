import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../domain/account_controller.dart';

class SecurityNotificationsScreen extends StatelessWidget {
  const SecurityNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return ListenableBuilder(
      listenable: AccountController.instance,
      builder: (context, _) {
        final ctrl = AccountController.instance;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: LajuGlassAppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('securityNotifications'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  const SizedBox(height: 8),
                  // Security Shield Hero Glass Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 2),
                          ),
                          child: const Icon(Icons.lock_person_rounded, color: AppColors.primary, size: 34),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'End-to-End Encrypted',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('securityNotificationsDesc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Protected Items Glass Card
                  LajuGlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildFeatureRow(isDark, Icons.chat_bubble_outline_rounded, 'Text & voice messages'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(isDark, Icons.phone_in_talk_rounded, 'Audio & video calls'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(isDark, Icons.image_outlined, 'Photos, videos & documents'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(isDark, Icons.location_on_outlined, 'Location sharing'),
                        const SizedBox(height: 12),
                        _buildFeatureRow(isDark, Icons.motion_photos_on_rounded, 'Status updates'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Toggle Setting Glass Card
                  LajuGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                        value: ctrl.securityNotificationsEnabled,
                        onChanged: (val) {
                          ctrl.setSecurityNotifications(val);
                          LajuToast.info(
                            context,
                            val
                                ? 'Security notifications enabled'
                                : 'Security notifications disabled',
                          );
                        },
                        title: Text(
                          context.tr('showSecurityNotifications'),
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr('showSecurityNotificationsSub'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        LajuToast.info(context, 'High-Assurance Signal Double-Ratchet Protocol v3');
                      },
                      child: Text(
                        context.tr('learnMore'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _buildFeatureRow(bool isDark, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
      ],
    );
  }
}
