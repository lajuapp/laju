import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class TermsPrivacyScreen extends StatefulWidget {
  final int initialTabIndex;
  const TermsPrivacyScreen({super.key, this.initialTabIndex = 0});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('termsPrivacyTitle'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark ? AppColors.primary : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: isDark ? Colors.black : Colors.white,
              unselectedLabelColor:
                  isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              tabs: [
                Tab(text: context.tr('tabPrivacyPolicy')),
                Tab(text: context.tr('tabTermsOfService')),
              ],
            ),
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPrivacyTab(context, isDark),
            _buildTermsTab(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        _buildNoticeHeader(
          isDark,
          title: context.tr('privacyHeaderTitle'),
          subtitle: context.tr('privacyHeaderSub'),
          icon: Icons.shield_rounded,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec1Title'),
          content: context.tr('privacySec1Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec2Title'),
          content: context.tr('privacySec2Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec3Title'),
          content: context.tr('privacySec3Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec4Title'),
          content: context.tr('privacySec4Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec5Title'),
          content: context.tr('privacySec5Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('privacySec6Title'),
          content: context.tr('privacySec6Body'),
        ),
      ],
    );
  }

  Widget _buildTermsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
      children: [
        _buildNoticeHeader(
          isDark,
          title: context.tr('termsHeaderTitle'),
          subtitle: context.tr('termsHeaderSub'),
          icon: Icons.gavel_rounded,
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec1Title'),
          content: context.tr('termsSec1Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec2Title'),
          content: context.tr('termsSec2Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec3Title'),
          content: context.tr('termsSec3Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec4Title'),
          content: context.tr('termsSec4Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec5Title'),
          content: context.tr('termsSec5Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec6Title'),
          content: context.tr('termsSec6Body'),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          isDark,
          title: context.tr('termsSec7Title'),
          content: context.tr('termsSec7Body'),
        ),
      ],
    );
  }

  Widget _buildNoticeHeader(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return LajuGlassCard(
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
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    bool isDark, {
    required String title,
    required String content,
  }) {
    return LajuGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      blurSigma: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: isDark
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
