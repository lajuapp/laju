import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/auth_controller.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String _identitySecret = '';
  String _deviceModel = '';
  String _registrationLocation = '';
  String _pushToken = '';
  bool _isSavedConfirmed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initIdentitySecret();
  }

  Future<void> _initIdentitySecret() async {
    final secret = await AuthController.instance.getOrGenerateIdentitySecret();
    final model = AuthController.instance.getDetectedDeviceModel();
    final location = AuthController.instance.getDetectedRegistrationLocation();
    final token = await AuthController.instance.getOrCreatePushToken();
    if (mounted) {
      setState(() {
        _identitySecret = secret;
        _deviceModel = model;
        _registrationLocation = location;
        _pushToken = token;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _copySecret() {
    if (_identitySecret.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _identitySecret));
    HapticFeedback.lightImpact();
    LajuToast.success(context, context.tr('copiedToClipboard'));
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      LajuToast.error(context, context.tr('fillAllRequired'));
      return;
    }

    if (!_isSavedConfirmed) {
      LajuToast.warning(context, context.tr('identityKeySavedConfirmation'));
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await AuthController.instance.registerDeviceIdentityAsync(
        username: username,
        identitySecret: _identitySecret,
        deviceModel: _deviceModel.isNotEmpty ? _deviceModel : null,
        registrationLocation: _registrationLocation.isNotEmpty ? _registrationLocation : null,
        pushToken: _pushToken.isNotEmpty ? _pushToken : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          LajuToast.success(context, context.tr('deviceAuthSuccess'));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else {
          final errorMsg = AuthController.instance.lastAuthError;
          LajuToast.error(
            context,
            (errorMsg != null && errorMsg.isNotEmpty)
                ? errorMsg
                : context.tr('authFailed'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LajuToast.error(context, '${context.tr('authFailed')}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('register'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Security Shield Icon
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.enhanced_encryption_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                context.tr('cryptoRegisterTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                context.tr('cryptoRegisterSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Username Input Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('username'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.alternate_email_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        hintText: context.tr('usernameHint'),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Identity Secret Box Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.key_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('identityBackupNotice'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('identityBackupDesc'),
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Monospace Secret Key Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black45 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: SelectableText(
                        _identitySecret.isEmpty ? 'Generating cryptographic key...' : _identitySecret,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Copy Button
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _copySecret,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: Text(
                          context.tr('copyIdentityKey'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Confirmation Checkbox Tile
              InkWell(
                onTap: () {
                  setState(() {
                    _isSavedConfirmed = !_isSavedConfirmed;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isSavedConfirmed,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _isSavedConfirmed = val ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          context.tr('identityKeySavedConfirmation'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Register Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          context.tr('createIdentityButton'),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Already have an account -> Login
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    context.tr('alreadyHaveAccount'),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF4B5563),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
