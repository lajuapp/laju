import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0..5 (Total 6 steps: 0: Language, 1: Theme, 2: Security 1, 3: Security 2, 4: Security 3 Hardware, 5: Terms & Privacy Agreement)
  static const int _totalSteps = 6;

  bool _hasReadTerms = false;
  bool _hasReadPrivacy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _handleFinalContinue();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skipToFinalStep() {
    _pageController.animateToPage(
      _totalSteps - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleFinalContinue() {
    if (!_hasReadTerms || !_hasReadPrivacy) {
      _showAgreementRequiredDialog(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  void _showTermsOfServiceSheet(BuildContext context, {VoidCallback? onAccepted}) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2433) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('termsModalTitle'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        isDark: isDark,
                        number: '1',
                        title: context.tr('termsSection1Title'),
                        body: context.tr('termsSection1Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '2',
                        title: context.tr('termsSection2Title'),
                        body: context.tr('termsSection2Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '3',
                        title: context.tr('termsSection3Title'),
                        body: context.tr('termsSection3Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '4',
                        title: context.tr('termsSection4Title'),
                        body: context.tr('termsSection4Body'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() => _hasReadTerms = true);
                    Navigator.pop(ctx);
                    onAccepted?.call();
                  },
                  child: Text(
                    context.tr('iUnderstandAndAgree'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyPolicySheet(BuildContext context, {VoidCallback? onAccepted}) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2433) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF06B6D4), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('privacyModalTitle'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPolicySection(
                        isDark: isDark,
                        number: '1',
                        title: context.tr('privacySection1Title'),
                        body: context.tr('privacySection1Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '2',
                        title: context.tr('privacySection2Title'),
                        body: context.tr('privacySection2Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '3',
                        title: context.tr('privacySection3Title'),
                        body: context.tr('privacySection3Body'),
                      ),
                      _buildPolicySection(
                        isDark: isDark,
                        number: '4',
                        title: context.tr('privacySection4Title'),
                        body: context.tr('privacySection4Body'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() => _hasReadPrivacy = true);
                    Navigator.pop(ctx);
                    onAccepted?.call();
                  },
                  child: Text(
                    context.tr('iUnderstandAndAgree'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicySection({
    required bool isDark,
    required String number,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAgreementRequiredDialog(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2433) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('agreementRequiredTitle'),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('agreementRequiredDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildAgreementCheckTile(
                    context: context,
                    isDark: isDark,
                    title: context.tr('termsOfService'),
                    isAccepted: _hasReadTerms,
                    icon: Icons.gavel_rounded,
                    accentColor: AppColors.primary,
                    onTap: () {
                      _showTermsOfServiceSheet(context, onAccepted: () {
                        setModalState(() {});
                        setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildAgreementCheckTile(
                    context: context,
                    isDark: isDark,
                    title: context.tr('privacyPolicy'),
                    isAccepted: _hasReadPrivacy,
                    icon: Icons.shield_rounded,
                    accentColor: const Color(0xFF06B6D4),
                    onTap: () {
                      _showPrivacyPolicySheet(context, onAccepted: () {
                        setModalState(() {});
                        setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_hasReadTerms && _hasReadPrivacy)
                            ? AppColors.primary
                            : (isDark ? Colors.white12 : Colors.black12),
                        foregroundColor: (_hasReadTerms && _hasReadPrivacy)
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.black38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: (_hasReadTerms && _hasReadPrivacy)
                          ? () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        context.tr('agreeAndContinue'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
      },
    );
  }

  Widget _buildAgreementCheckTile({
    required BuildContext context,
    required bool isDark,
    required String title,
    required bool isAccepted,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isAccepted
              ? accentColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF131722) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAccepted
                ? accentColor
                : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE5E7EB)),
            width: isAccepted ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAccepted
                        ? (title.contains('Privasi') || title.contains('Privacy')
                            ? context.tr('privacyAccepted')
                            : context.tr('termsAccepted'))
                        : context.tr('tapToReadAndAccept'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isAccepted ? accentColor : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                      fontWeight: isAccepted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isAccepted ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: isAccepted ? accentColor : (isDark ? Colors.white38 : Colors.black38),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeModeController.instance,
        LocaleController.instance,
      ]),
      builder: (context, _) {
        final isDark = ThemeModeController.instance.isDarkMode(context);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
          body: LajuGlassBackground(
            showOrbs: true,
            child: SafeArea(
              child: Column(
                children: [
              // Top Bar with Brand, Back / Logo, Skip Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        onPressed: _previousStep,
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),

                    const SizedBox(width: 4),
                    Image.asset(
                      'assets/images/logo_no_bg.png',
                      width: 28,
                      height: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LAJU',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),

                    // Skip button on security highlight pages (Steps 2 & 3)
                    if (_currentStep >= 2 && _currentStep < _totalSteps - 1)
                      TextButton(
                        onPressed: _skipToFinalStep,
                        child: Text(
                          context.tr('skip'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${context.tr('stepCounter')} ${_currentStep + 1}/$_totalSteps',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Step Progress Line (5 segment bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: List.generate(_totalSteps, (index) {
                    final isDone = index <= _currentStep;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.primary
                              : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Main Page View (5 distinct screens)
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() => _currentStep = idx);
                  },
                  children: [
                    _buildStep1Language(context),
                    _buildStep2Theme(context),
                    _buildSecurityHighlight1(context),
                    _buildSecurityHighlight2(context),
                    _buildSecurityHighlight3Hardware(context),
                    _buildStepAgreement(context),
                  ],
                ),
              ),

              // Bottom Navigation Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _nextStep,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == _totalSteps - 1
                                  ? context.tr('agreeAndContinue')
                                  : context.tr('next'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == _totalSteps - 1
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_currentStep == 0) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            context.tr('alreadyHaveAccount'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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

  // ================= STEP 1: PILIH BAHASA =================
  Widget _buildStep1Language(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final currentLang = LocaleController.instance.value.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 30),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              context.tr('stepLanguageTitle'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              context.tr('stepLanguageSub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                _buildLanguageOptionCard(context, 'id', 'Bahasa Indonesia', 'Indonesian', '🇮🇩', currentLang == 'id'),
                _buildLanguageOptionCard(context, 'en', 'English', 'English (United States)', '🇺🇸', currentLang == 'en'),
                _buildLanguageOptionCard(context, 'ru', 'Русский', 'Russian', '🇷🇺', currentLang == 'ru'),
                _buildLanguageOptionCard(context, 'zh', '中文 (简体)', 'Chinese Simplified', '🇨🇳', currentLang == 'zh'),
                _buildLanguageOptionCard(context, 'ja', '日本語', 'Japanese', '🇯🇵', currentLang == 'ja'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard(
    BuildContext context,
    String code,
    String title,
    String subtitle,
    String flag,
    bool isSelected,
  ) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: LajuGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: isSelected ? AppColors.primary : null,
        borderWidth: isSelected ? 1.8 : 1.0,
        onTap: () {
          LocaleController.instance.setLocale(Locale(code));
          setState(() {});
        },
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : const Color(0xFF111827)),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white38 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ================= STEP 2: PILIH TEMA =================
  Widget _buildStep2Theme(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final currentThemeMode = ThemeModeController.instance.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.palette_outlined, color: Color(0xFF06B6D4), size: 30),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              context.tr('stepThemeTitle'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              context.tr('stepThemeSub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildThemeCard(
            context: context,
            title: context.tr('themeDark'),
            subtitle: context.tr('themeDarkDesc'),
            icon: Icons.dark_mode_rounded,
            isSelected: currentThemeMode == ThemeMode.dark,
            onTap: () {
              ThemeModeController.instance.setThemeMode(ThemeMode.dark);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildThemeCard(
            context: context,
            title: context.tr('themeLight'),
            subtitle: context.tr('themeLightDesc'),
            icon: Icons.light_mode_rounded,
            isSelected: currentThemeMode == ThemeMode.light,
            onTap: () {
              ThemeModeController.instance.setThemeMode(ThemeMode.light);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildThemeCard(
            context: context,
            title: context.tr('themeSystem'),
            subtitle: context.tr('themeSystemDesc'),
            icon: Icons.brightness_auto_rounded,
            isSelected: currentThemeMode == ThemeMode.system,
            onTap: () {
              ThemeModeController.instance.setThemeMode(ThemeMode.system);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return LajuGlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: isSelected ? AppColors.primary : null,
      borderWidth: isSelected ? 1.8 : 1.0,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white : const Color(0xFF111827)),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white38 : Colors.black26),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ],
      ),
    );
  }

  // ================= STEP 3: SECURITY HIGHLIGHT 1 =================
  // "Your Conversations Stay Yours" (Uploaded Phone + Shield 3D Asset)
  Widget _buildSecurityHighlight1(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: '${context.tr('securityPage1Title1')}\n',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: context.tr('securityPage1Title2'),
                  style: const TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('securityPage1Sub'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),

          // Central Visual Graphic: 3D Phone with Emerald Shield Image
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/onboarding/security_phone.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom Feature Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('securityPage1BadgeTitle'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('securityPage1BadgeDesc'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF047857),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ================= STEP 4: SECURITY HIGHLIGHT 2 =================
  // "Powered by Signal Protocol" (Uploaded Double Ratchet 3D Shield Stack Asset)
  Widget _buildSecurityHighlight2(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: '${context.tr('securityPage2Title1')}\n',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: context.tr('securityPage2Title2'),
                  style: const TextStyle(
                    color: Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('securityPage2Sub'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),

          // Central Visual Graphic: 3D Signal Protocol / Double Ratchet Image
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/onboarding/security_signal.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom Feature Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14222E) : const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: Color(0xFF06B6D4), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('securityPage2BadgeTitle'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0E7490),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('securityPage2BadgeDesc'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF155E75),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ================= STEP 5: SECURITY HIGHLIGHT 3 (HARDWARE PROTECTION) =================
  // "Hardware-Backed Protection" (Full 3D Hardware Chip Asset + Minimal Banner)
  Widget _buildSecurityHighlight3Hardware(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: '${context.tr('securityPage3Title1')}\n',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: context.tr('securityPage3Title2'),
                  style: const TextStyle(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('securityPage3Sub'),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),

          // Central Visual Graphic: 3D Hardware Enclave Graphic displayed in full height & glory
          Expanded(
            child: Center(
              child: Image.asset(
                'assets/images/onboarding/security_hardware.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom Feature Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.memory_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('securityPage3BadgeTitle'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('securityPage3BadgeDesc'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF047857),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ================= STEP 6: TERMS OF SERVICE & PRIVACY POLICY =================
  // Dedicated, super clean agreement screen before continuing to register
  Widget _buildStepAgreement(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '${context.tr('agreementPageTitle1')} ',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: context.tr('agreementPageTitle2'),
                    style: const TextStyle(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              context.tr('agreementPageSub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Mandatory Agreement Tiles
          _buildAgreementTile(
            context: context,
            isDark: isDark,
            title: context.tr('termsOfService'),
            isAccepted: _hasReadTerms,
            icon: Icons.gavel_rounded,
            accentColor: AppColors.primary,
            onTap: () => _showTermsOfServiceSheet(context),
          ),
          const SizedBox(height: 12),
          _buildAgreementTile(
            context: context,
            isDark: isDark,
            title: context.tr('privacyPolicy'),
            isAccepted: _hasReadPrivacy,
            icon: Icons.shield_rounded,
            accentColor: const Color(0xFF06B6D4),
            onTap: () => _showPrivacyPolicySheet(context),
          ),
          const SizedBox(height: 20),

          // Security Trust Assurance Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F30) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('agreementMandatoryBadge'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('agreementMandatoryBadgeSub'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAgreementTile({
    required BuildContext context,
    required bool isDark,
    required String title,
    required bool isAccepted,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isAccepted
              ? accentColor.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF131722) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isAccepted
                ? accentColor
                : (isDark ? const Color(0xFF2E384D) : const Color(0xFFE5E7EB)),
            width: isAccepted ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isAccepted
                        ? (title.contains('Privasi') || title.contains('Privacy')
                            ? context.tr('privacyAccepted')
                            : context.tr('termsAccepted'))
                        : context.tr('tapToReadAndAccept'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isAccepted ? accentColor : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280)),
                      fontWeight: isAccepted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isAccepted ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: isAccepted ? accentColor : (isDark ? Colors.white38 : Colors.black38),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
