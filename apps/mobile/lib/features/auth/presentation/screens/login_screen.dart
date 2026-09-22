import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/auth_controller.dart';
import 'onboarding_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _recoveryKeyController = TextEditingController();
  bool _isLoading = false;
  String? _activeMigrationId;
  BiometricAvailability? _biometricInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final info = await BiometricService.instance.checkAvailability();
      if (mounted) {
        setState(() => _biometricInfo = info);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recoveryKeyController.dispose();
    super.dispose();
  }

  /// Flow 1: Device Cryptographic Authentication (Biometrics or 6-digit PIN)
  Future<void> _handleDeviceKeystoreAuth() async {
    // 1. Check biometric / device credentials availability
    final availability = _biometricInfo ?? await BiometricService.instance.checkAvailability();

    bool authenticated = false;

    if (availability.isAvailable) {
      final bioLabel = availability.biometricLabel.isNotEmpty
          ? availability.biometricLabel
          : 'Sidik Jari / Wajah';

      authenticated = await BiometricService.instance.authenticate(
        title: 'Verifikasi Pemilik Perangkat',
        subtitle: 'Pindai $bioLabel atau kunci layar HP ini',
        description: 'Autentikasi biometrik diperlukan untuk memastikan Anda adalah pemilik sah HP ini sebelum masuk.',
        allowDeviceCredential: true,
        negativeButtonText: 'Gunakan PIN',
      );
    }

    // 2. If device has NO biometric support, or user chose "Gunakan PIN" / biometric failed:
    // Prompt for 6-digit PIN directly!
    if (!authenticated) {
      if (AppLockController.instance.hasSetPin) {
        if (mounted) {
          authenticated = await SecurityAuthHelper.promptVerifyPin(
            context,
            title: 'Verifikasi PIN Keamanan',
            subtitle: availability.isAvailable
                ? 'Masukkan 6-digit PIN keamanan Anda'
                : 'HP tidak mendukung biometrik. Masukkan 6-digit PIN Anda untuk masuk',
          );
        }
      } else {
        // If device has no PIN set yet, prompt to set one now
        if (mounted) {
          final newPin = await SecurityAuthHelper.promptSetupPin(
            context,
            title: 'Atur PIN Keamanan (6-Digit)',
          );
          if (newPin != null && newPin.length == 6) {
            await AppLockController.instance.setPinCode(newPin);
            authenticated = true;
          }
        }
      }
    }

    // 3. If neither biometric nor PIN succeeded, reject login completely
    if (!authenticated) {
      if (mounted) {
        LajuToast.error(
          context,
          'Autentikasi biometrik atau PIN tidak berhasil. Akses login perangkat ditolak.',
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final success =
          await AuthController.instance.authenticateDeviceKeystoreAsync();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        LajuToast.success(context, context.tr('deviceAuthSuccess'));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } else {
        LajuToast.error(context, context.tr('deviceNotRegistered'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        LajuToast.error(context, '${context.tr('authFailed')}: $e');
      }
    }
  }

  /// Flow 2: QR Migration Handshake (Move from Old Phone)
  Future<void> _startMigrationHandshake() async {
    final scannedPayload = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const LajuQrScannerScreen(
          title: 'Pindai Kode QR Migrasi',
          promptText: 'Arahkan kamera ke kode QR pada HP lama Anda',
        ),
      ),
    );
    if (scannedPayload == null) return;

    setState(() => _isLoading = true);

    // Handle different scanned QR formats
    String migrationId = '';
    if (scannedPayload.startsWith('laju://migrate/')) {
      migrationId = scannedPayload.replaceFirst('laju://migrate/', '').split('?').first.trim();
    } else if (scannedPayload.contains('mig-')) {
      final match = RegExp(r'mig-[a-zA-Z0-9_-]+').firstMatch(scannedPayload);
      if (match != null) migrationId = match.group(0)!;
    } else if (scannedPayload.startsWith('laju://')) {
      // User scanned a profile contact QR instead of a migration QR
      setState(() => _isLoading = false);
      final contactUser = scannedPayload.replaceFirst('laju://', '').split('?').first;
      LajuToast.error(
        context,
        'Ini kode QR kontak (@$contactUser), bukan QR Migrasi Akun. Untuk migrasi, buka menu Pengaturan > Keamanan > Migrasi Perangkat di HP lama Anda.',
      );
      return;
    } else {
      migrationId = scannedPayload.trim();
    }
    _activeMigrationId = migrationId;

    final joinRes = await AuthController.instance.joinMigrationAsync(
      migrationId: migrationId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (joinRes == null || joinRes['sasCode'] == null) {
      LajuToast.error(context, context.tr('migrationCommitFailed'));
      return;
    }

    final sasCode = joinRes['sasCode'].toString();

    // Show Mutual SAS Verification Bottom Sheet
    _showSasVerificationBottomSheet(sasCode, migrationId);
  }

  void _showSasVerificationBottomSheet(String sasCode, String migrationId) {
    final isDark = ThemeModeController.instance.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2232) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                14,
                22,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tactical Shield Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    context.tr('sasModalTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    context.tr('sasModalDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SAS Code Visual Display Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF121724)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        sasCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirm and Commit 2PC Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);

                        final success = await AuthController.instance
                            .commitMigrationAsync(
                          migrationId: migrationId,
                          sasCode: sasCode,
                        );

                        if (!mounted) return;
                        setState(() => _isLoading = false);

                        if (success) {
                          LajuToast.success(
                            context,
                            context.tr('migrationSuccess'),
                          );
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        } else {
                          LajuToast.error(context, context.tr('migrationCommitFailed'));
                        }
                      },
                      child: Text(
                        context.tr('sasConfirmButton'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
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

  /// Flow 3: Restore with Identity Secret / Seed Phrase
  Future<void> _handleRestoreSecret() async {
    final secret = _recoveryKeyController.text.trim();
    if (secret.isEmpty) {
      LajuToast.error(context, context.tr('fillAllRequired'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthController.instance
          .restoreWithIdentitySecretAsync(secret);

      if (!mounted) return;
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
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo_no_bg.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LAJU IDENTITY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            context.tr('loginTitle'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('loginSub'),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3-Mode Modern Segment Tab Bar
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceBorder
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: textSecondary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded,
                                  size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('qrMigrationTab'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phonelink_lock_rounded,
                                  size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('deviceAuthTab'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.vpn_key_outlined, size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('recoverySecretTab'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main Tab Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: QR Migration View
                  _buildQrMigrationTab(isDark, textPrimary, textSecondary),

                  // Tab 2: Hardware Keystore Device Auth
                  _buildDeviceKeystoreTab(isDark, textPrimary, textSecondary),

                  // Tab 3: Recovery Key / Seed
                  _buildRecoverySecretTab(isDark, textPrimary, textSecondary),
                ],
              ),
            ),

            // Bottom Switch to Register
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr('dontHaveAccount'),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );
                    },
                    child: Text(
                      context.tr('register'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
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
  }

  /// Widget for Tab 1: QR Migration from Old Phone
  Widget _buildQrMigrationTab(
      bool isDark, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Step-by-Step Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B2232)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceBorder
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sync_alt_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('qrMigrationCardTitle'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('qrMigrationCardDesc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // High-Tech Scanner Viewfinder Simulation Box
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1420) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Corner tactical markers
                Positioned(
                  top: 12,
                  left: 12,
                  child: Icon(Icons.crop_free_rounded,
                      color: AppColors.primary, size: 28),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(Icons.crop_free_rounded,
                      color: AppColors.primary, size: 28),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Icon(Icons.crop_free_rounded,
                      color: AppColors.primary, size: 28),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Icon(Icons.crop_free_rounded,
                      color: AppColors.primary, size: 28),
                ),

                // Center animated pulse scanner line
                Center(
                  child: Container(
                    width: 170,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('readyToScan'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Button: Scan QR from Camera / Gallery
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 20),
              label: Text(
                _isLoading
                    ? context.tr('verifyingDevice')
                    : context.tr('scanQrButton'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isLoading
                  ? null
                  : _startMigrationHandshake,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget for Tab 2: Hardware Keystore Device Auth
  Widget _buildDeviceKeystoreTab(
      bool isDark, Color textPrimary, Color textSecondary) {
    final isBioAvailable = _biometricInfo?.isAvailable == true;
    final hasFace = _biometricInfo?.hasFace == true && _biometricInfo?.hasFingerprint != true;
    final bioLabel = isBioAvailable ? (_biometricInfo?.biometricLabel ?? 'Biometrik') : 'PIN Keamanan';
    final mainIcon = isBioAvailable
        ? (hasFace ? Icons.face_rounded : Icons.fingerprint_rounded)
        : Icons.lock_outline_rounded;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Hardware TEE / StrongBox & Biometric/PIN Protection Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B2232)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceBorder
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBioAvailable
                                ? 'Proteksi Biometrik Pemilik Perangkat'
                                : 'Proteksi PIN Keamanan Pemilik',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            isBioAvailable
                                ? '$bioLabel Aktif'
                                : 'PIN 6-Digit Aktif',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isBioAvailable
                      ? 'Wajib memverifikasi sidik jari, wajah, atau kunci layar HP ini untuk membuktikan Anda adalah pemilik sah sebelum masuk ke akun.'
                      : 'Perangkat ini tidak mendukung sensor biometrik. Verifikasi 6-digit PIN keamanan pemilik diperlukan untuk membuka akun.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Big Sensor / Keypad Tactile Center Button
          GestureDetector(
            onTap: _isLoading ? null : _handleDeviceKeystoreAuth,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      )
                    : Icon(
                        mainIcon,
                        color: AppColors.primary,
                        size: 64,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            isBioAvailable
                ? (_biometricInfo?.deviceModel.isNotEmpty == true
                    ? 'Sensor: $bioLabel (${_biometricInfo!.deviceModel})'
                    : 'Sentuh sensor untuk verifikasi biometrik')
                : 'Sentuh tombol untuk verifikasi PIN 6-digit',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 28),

          // Unlock Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(mainIcon, size: 20),
              label: Text(
                _isLoading
                    ? context.tr('verifyingDevice')
                    : (isBioAvailable ? 'Buka dengan $bioLabel' : 'Buka dengan PIN Keamanan'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isLoading ? null : _handleDeviceKeystoreAuth,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget for Tab 3: Recovery Key / Seed
  Widget _buildRecoverySecretTab(
      bool isDark, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B2232)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceBorder
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('recoveryKeyTitle'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('recoveryKeyDesc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recovery Input TextField
          TextField(
            controller: _recoveryKeyController,
            maxLines: 3,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: context.tr('recoveryKeyInputHint'),
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : const Color(0xFF9CA3AF),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.darkSurfaceElevated
                  : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkSurfaceBorder
                      : const Color(0xFFE5E7EB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.darkSurfaceBorder
                      : const Color(0xFFE5E7EB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.restore_page_rounded, size: 20),
              label: Text(
                _isLoading
                    ? context.tr('verifyingDevice')
                    : context.tr('restoreAccountButton'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isLoading ? null : _handleRestoreSecret,
            ),
          ),
        ],
      ),
    );
  }
}
