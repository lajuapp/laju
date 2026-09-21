import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        ThemeModeController.instance,
      ]),
      builder: (context, _) {
        final currentLang = LocaleController.instance.value.languageCode;
        final isDark = ThemeModeController.instance.isDarkMode(context);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
          appBar: LajuGlassAppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              context.tr('language'),
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
                // Header Glass Hero Card
                LajuGlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  blurSigma: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.language_rounded, color: Colors.black, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('selectLanguage'),
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.tr('languageSubtitle'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

              // Language options list
              _buildLanguageCard(
                context: context,
                title: 'English',
                subtitle: context.tr('englishSub'),
                isSelected: currentLang == 'en',
                nativeScript: 'Hello • Secure Enterprise Chat',
                onTap: () {
                  if (currentLang != 'en') {
                    LocaleController.instance.setLocale(const Locale('en'));
                    LajuToast.success(context, context.tr('languageChanged'));
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildLanguageCard(
                context: context,
                title: 'Bahasa Indonesia',
                subtitle: context.tr('indonesianSub'),
                isSelected: currentLang == 'id',
                nativeScript: 'Halo • Komunikasi Kriptografis Aman',
                onTap: () {
                  if (currentLang != 'id') {
                    LocaleController.instance.setLocale(const Locale('id'));
                    LajuToast.success(context, context.tr('languageChanged'));
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildLanguageCard(
                context: context,
                title: 'Русский',
                subtitle: context.tr('russianSub'),
                isSelected: currentLang == 'ru',
                nativeScript: 'Привет • Зашифрованный защищенный мессенджер',
                onTap: () {
                  if (currentLang != 'ru') {
                    LocaleController.instance.setLocale(const Locale('ru'));
                    LajuToast.success(context, context.tr('languageChanged'));
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildLanguageCard(
                context: context,
                title: '中文 (简体)',
                subtitle: context.tr('chineseSub'),
                isSelected: currentLang == 'zh',
                nativeScript: '你好 • 端到端量子安全即时通信',
                onTap: () {
                  if (currentLang != 'zh') {
                    LocaleController.instance.setLocale(const Locale('zh'));
                    LajuToast.success(context, context.tr('languageChanged'));
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildLanguageCard(
                context: context,
                title: '日本語',
                subtitle: context.tr('japaneseSub'),
                isSelected: currentLang == 'ja',
                nativeScript: 'こんにちは • 量子耐性エンドツーエンド暗号化',
                onTap: () {
                  if (currentLang != 'ja') {
                    LocaleController.instance.setLocale(const Locale('ja'));
                    LajuToast.success(context, context.tr('languageChanged'));
                  }
                },
              ),

              const SizedBox(height: 24),

              // Device Note
              LajuGlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 14,
                blurSigma: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentLang == 'id'
                            ? 'Bahasa aplikasi akan langsung diterapkan di seluruh obrolan, status, enkripsi, dan pengaturan tanpa perlu memulai ulang aplikasi.'
                            : 'App language is applied instantly across all chats, status, encryption controls, and settings without restarting the application.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String nativeScript,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LajuGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 18,
        blurSigma: 16,
        borderColor: isSelected ? AppColors.primary : null,
        borderWidth: isSelected ? 1.8 : 1.0,
        customShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
        onTap: onTap,
        child: Material(
          color: isSelected
              ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight.withValues(alpha: 0.5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF6EE7B7) : AppColors.primaryDark)
                                  : (isDark ? Colors.white : const Color(0xFF111827)),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFFA7F3D0)
                                  : AppColors.primaryDark.withValues(alpha: 0.85))
                              : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nativeScript,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isSelected
                              ? (isDark
                                  ? AppColors.primaryLight.withValues(alpha: 0.8)
                                  : AppColors.primaryDark.withValues(alpha: 0.7))
                              : (isDark
                                  ? AppColors.darkTextSecondary.withValues(alpha: 0.7)
                                  : const Color(0xFF9CA3AF)),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
