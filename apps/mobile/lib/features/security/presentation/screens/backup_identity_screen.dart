import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../auth/domain/auth_controller.dart';

class BackupIdentityScreen extends StatefulWidget {
  const BackupIdentityScreen({super.key});

  @override
  State<BackupIdentityScreen> createState() => _BackupIdentityScreenState();
}

class _BackupIdentityScreenState extends State<BackupIdentityScreen> {
  String _secretKey = '';
  bool _isRevealed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecretKey();
  }

  Future<void> _loadSecretKey() async {
    final key = await AuthController.instance.getOrGenerateIdentitySecret();
    if (mounted) {
      setState(() {
        _secretKey = key;
        _isLoading = false;
      });
    }
  }

  Future<void> _revealSecret() async {
    final authOk = await SecurityAuthHelper.authenticate(
      context,
      title: 'Buka Kunci Rahasia',
      subtitle: 'Pindai sidik jari atau masukkan PIN untuk menampilkan kunci privat pemulihan akun',
    );
    if (authOk) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isRevealed = true;
        });
        LajuToast.success(context, 'Kunci identitas berhasil dibuka');
      }
    } else {
      if (mounted) {
        HapticFeedback.mediumImpact();
        LajuToast.warning(context, 'Otorisasi keamanan dibatalkan atau gagal');
      }
    }
  }

  Future<void> _copySecret() async {
    if (_secretKey.isEmpty) return;
    if (!_isRevealed) {
      await _revealSecret();
      if (!_isRevealed) return;
    }
    Clipboard.setData(ClipboardData(text: _secretKey));
    HapticFeedback.lightImpact();
    if (mounted) {
      LajuToast.success(context, context.tr('backupSecretCopied'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: LajuGlassAppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('backupIdentityTitle'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LajuGlassBackground(
        showOrbs: true,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Hero Glass Card
                      LajuGlassCard(
                        borderRadius: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        blurSigma: 18,
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                                    Colors.transparent,
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                        blurRadius: 14,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.key_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('backupIdentityTitle'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('backupIdentitySub'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Warning Alert Banner Glass Card
                      LajuGlassCard(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                  const Color(0xFFB45309).withValues(alpha: 0.08),
                                ]
                              : [
                                  const Color(0xFFFFFBEB),
                                  const Color(0xFFFEF3C7),
                                ],
                        ),
                        borderColor: isDark
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.45),
                        borderWidth: 1.2,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.20 : 0.15),
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('secretKeyWarning'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    context.tr('revealSecretNotice'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF78350F),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Secret Display Glass Box
                      LajuGlassCard(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(20),
                        blurSigma: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isRevealed)
                              Column(
                                children: [
                                  const Icon(
                                    Icons.visibility_off_rounded,
                                    size: 40,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('authenticateToViewSecret'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: _revealSecret,
                                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                                      label: const Text(
                                        'Tampilkan Kunci Rahasia',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black45 : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark ? Colors.white12 : Colors.black12,
                                      ),
                                    ),
                                    child: SelectableText(
                                      _secretKey,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: _copySecret,
                                      icon: const Icon(Icons.copy_rounded, size: 18),
                                      label: Text(
                                        context.tr('copyIdentityKey'),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
