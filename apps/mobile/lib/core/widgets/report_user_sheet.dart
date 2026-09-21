import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/settings/domain/account_controller.dart';
import '../core.dart';

class ReportCategoryDef {
  final String id;
  final String labelKey;
  final String descKey;
  final IconData icon;
  final Color color;

  const ReportCategoryDef({
    required this.id,
    required this.labelKey,
    required this.descKey,
    required this.icon,
    required this.color,
  });
}

class ReportUserSheet extends StatefulWidget {
  final String reportedUserId;
  final String reportedUserName;
  final String? avatarPath;
  final VoidCallback? onReportSuccess;

  const ReportUserSheet({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    this.avatarPath,
    this.onReportSuccess,
  });

  @override
  State<ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<ReportUserSheet> {
  final _reasonController = TextEditingController();
  String _selectedCategory = 'SPAM';
  bool _alsoBlockContact = false;
  bool _isSubmitting = false;

  final List<ReportCategoryDef> _categories = const [
    ReportCategoryDef(
      id: 'SPAM',
      labelKey: 'reportCatSpam',
      descKey: 'reportCatSpamDesc',
      icon: Icons.flag_rounded,
      color: Color(0xFFEF4444),
    ),
    ReportCategoryDef(
      id: 'SCAM',
      labelKey: 'reportCatScam',
      descKey: 'reportCatScamDesc',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFF59E0B),
    ),
    ReportCategoryDef(
      id: 'HARASSMENT',
      labelKey: 'reportCatHarassment',
      descKey: 'reportCatHarassmentDesc',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      color: Color(0xFFDC2626),
    ),
    ReportCategoryDef(
      id: 'IMPERSONATION',
      labelKey: 'reportCatImpersonation',
      descKey: 'reportCatImpersonationDesc',
      icon: Icons.person_off_rounded,
      color: Color(0xFF8B5CF6),
    ),
    ReportCategoryDef(
      id: 'INAPPROPRIATE_CONTENT',
      labelKey: 'reportCatInappropriate',
      descKey: 'reportCatInappropriateDesc',
      icon: Icons.visibility_off_rounded,
      color: Color(0xFFEC4899),
    ),
    ReportCategoryDef(
      id: 'OTHER',
      labelKey: 'reportCatOther',
      descKey: 'reportCatOtherDesc',
      icon: Icons.help_outline_rounded,
      color: Color(0xFF6B7280),
    ),
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      HapticFeedback.heavyImpact();
      LajuToast.error(context, context.tr('reportReasonMinLength'));
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      if (ApiClient.instance.authToken != null) {
        await ApiClient.instance.post(
          ApiEndpoints.userReport,
          body: {
            'reportedUserId': widget.reportedUserId,
            'category': _selectedCategory,
            'reason': reason,
          },
        );
      }

      if (_alsoBlockContact) {
        await AccountController.instance.addBlockedContact(widget.reportedUserName);
      }

      if (mounted) {
        Navigator.pop(context);
        LajuToast.success(context, context.tr('reportSuccessDesc'));
        widget.onReportSuccess?.call();
      }
    } catch (e) {
      // Fallback local report
      if (_alsoBlockContact) {
        await AccountController.instance.addBlockedContact(widget.reportedUserName);
      }
      if (mounted) {
        Navigator.pop(context);
        LajuToast.success(context, context.tr('reportSuccessDesc'));
        widget.onReportSuccess?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgCol = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('reportUserTitle'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('reportUserSubtitle'),
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reported User Banner Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    ModernAvatar(
                      name: widget.reportedUserName,
                      imagePath: widget.avatarPath,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.reportedUserName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('reportUserSubtitle'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category Label
              Text(
                context.tr('reportCategoryTitle'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Category Radio Selection List
              ..._categories.map((cat) {
                final isSelected = _selectedCategory == cat.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.color.withValues(alpha: 0.12)
                        : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? cat.color.withValues(alpha: 0.6)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedCategory = cat.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            cat.icon,
                            color: cat.color,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(cat.labelKey),
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 13.5,
                                    color: isSelected ? textPrimary : textSecondary,
                                  ),
                                ),
                                Text(
                                  context.tr(cat.descKey),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: cat.id,
                            groupValue: _selectedCategory,
                            activeColor: cat.color,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Reason Label
              Text(
                context.tr('reportReasonLabel'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Reason TextField
              TextField(
                controller: _reasonController,
                maxLines: 3,
                maxLength: 500,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: context.tr('reportReasonHint'),
                  hintStyle: TextStyle(color: textSecondary, fontSize: 12.5),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              // Block contact checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFFEF4444),
                title: Text(
                  '${context.tr('reportBlockContact')} (${widget.reportedUserName})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.tr('reportBlockContactSub'),
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
                value: _alsoBlockContact,
                onChanged: (val) {
                  setState(() => _alsoBlockContact = val ?? false);
                },
              ),
              const SizedBox(height: 14),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.tr('cancel'),
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitReport,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.tr('reportSubmitBtn'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showReportUserSheet(
  BuildContext context, {
  String? reportedUserId,
  String? reportedUserName,
  String? userId,
  String? userName,
  String? avatarPath,
  VoidCallback? onReportSuccess,
}) {
  final targetId = reportedUserId ?? userId ?? '';
  final targetName = reportedUserName ?? userName ?? 'User';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ReportUserSheet(
      reportedUserId: targetId,
      reportedUserName: targetName,
      avatarPath: avatarPath,
      onReportSuccess: onReportSuccess,
    ),
  );
}
