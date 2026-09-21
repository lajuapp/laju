import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import 'contact_support_screen.dart';

class FaqDef {
  final String categoryKey;
  final String questionKey;
  final String answerKey;
  final IconData icon;

  const FaqDef({
    required this.categoryKey,
    required this.questionKey,
    required this.answerKey,
    required this.icon,
  });
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategoryKey = 'faqCategoryAll';
  String _searchQuery = '';

  final List<String> _categoryKeys = const [
    'faqCategoryAll',
    'faqCategorySecurity',
    'faqCategoryChatCall',
    'faqCategoryAccount',
    'faqCategoryPrivacy',
  ];

  final List<FaqDef> _faqDefs = const [
    FaqDef(
      categoryKey: 'faqCategorySecurity',
      questionKey: 'faqQ1',
      answerKey: 'faqA1',
      icon: Icons.lock_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategorySecurity',
      questionKey: 'faqQ2',
      answerKey: 'faqA2',
      icon: Icons.fingerprint_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryAccount',
      questionKey: 'faqQ3',
      answerKey: 'faqA3',
      icon: Icons.vpn_key_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryAccount',
      questionKey: 'faqQ4',
      answerKey: 'faqA4',
      icon: Icons.verified_user_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryChatCall',
      questionKey: 'faqQ5',
      answerKey: 'faqA5',
      icon: Icons.phone_in_talk_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryChatCall',
      questionKey: 'faqQ6',
      answerKey: 'faqA6',
      icon: Icons.report_problem_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryPrivacy',
      questionKey: 'faqQ7',
      answerKey: 'faqA7',
      icon: Icons.visibility_off_rounded,
    ),
    FaqDef(
      categoryKey: 'faqCategoryAccount',
      questionKey: 'faqQ8',
      answerKey: 'faqA8',
      icon: Icons.phonelink_setup_rounded,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    final filtered = _faqDefs.where((item) {
      final matchesCategory = _selectedCategoryKey == 'faqCategoryAll' ||
          item.categoryKey == _selectedCategoryKey;
      final q = context.tr(item.questionKey).toLowerCase();
      final a = context.tr(item.answerKey).toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesQuery = query.isEmpty || q.contains(query) || a.contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

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
          context.tr('helpFaqTitle'),
          style: TextStyle(
            fontSize: 19,
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
            // Search Box Card
            LajuGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              borderRadius: 16,
              blurSigma: 16,
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  fontSize: 14.5,
                ),
                decoration: InputDecoration(
                  icon: Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                  ),
                  hintText: context.tr('faqSearchHint'),
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categoryKeys.map((catKey) {
                  final isSelected = _selectedCategoryKey == catKey;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        context.tr(catKey),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: isDark ? AppColors.primary : const Color(0xFF2563EB),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategoryKey = catKey;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // FAQs List
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${context.tr('faqNotFound')} "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              LajuGlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 20,
                blurSigma: 16,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 52,
                    endIndent: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            color: isDark ? AppColors.primary : const Color(0xFF2563EB),
                            size: 19,
                          ),
                        ),
                        title: Text(
                          context.tr(item.questionKey),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            context.tr(item.categoryKey),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.primary
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                context.tr(item.answerKey),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.5,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Still have questions card
            LajuGlassCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 20,
              blurSigma: 16,
              child: Column(
                children: [
                  const Icon(Icons.help_outline_rounded,
                      size: 36, color: AppColors.primary),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('faqStillNeedHelp'),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('faqStillNeedHelpSub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: Text(
                      context.tr('faqContactSupportBtn'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactSupportScreen(),
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
}
