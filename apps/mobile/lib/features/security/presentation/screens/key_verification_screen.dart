import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';

class KeyVerificationScreen extends StatefulWidget {
  final String contactName;
  final String safetyNumber;

  const KeyVerificationScreen({
    super.key,
    this.contactName = 'Kontak LAJU',
    this.safetyNumber = '19402 48190 28471 00293 84729 48190 92834 58291 01928 38472 91827 46582',
  });

  @override
  State<KeyVerificationScreen> createState() => _KeyVerificationScreenState();
}

class _KeyVerificationScreenState extends State<KeyVerificationScreen>
    with TickerProviderStateMixin {
  bool _isVerified = true;
  bool _isFlipped = false; // false = QR Code (front), true = Safety Number (back)

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 3D Card Flip Animation (600ms cubic ease)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );

    // QR Laser Scanner Line Animation (sweeps up and down)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );

    // Ambient Neon Glowing Orbs Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _laserController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.mediumImpact();
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _copySafetyNumber() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.safetyNumber));
    LajuToast.success(context, context.tr('safetyNumberCopied'));
  }

  void _toggleVerification() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isVerified = !_isVerified;
    });
    if (_isVerified) {
      LajuToast.success(context, '${widget.contactName}: ${context.tr('keyVerifiedStatus')}');
    } else {
      LajuToast.warning(context, '${widget.contactName}: ${context.tr('unverifiedStatus')}');
    }
  }

  Future<void> _openScannerCamera() async {
    HapticFeedback.selectionClick();
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => LajuQrScannerScreen(
          title: 'Verifikasi Kunci Kontak',
          promptText: 'Pindai kode QR kontak untuk verifikasi nomor keamanan',
          onScan: (val) {
            Navigator.pop(ctx, val);
          },
        ),
      ),
    );
    if (scanned != null && mounted) {
      HapticFeedback.heavyImpact();
      setState(() => _isVerified = true);
      LajuToast.success(context, '${widget.contactName}: ${context.tr('keyVerifiedStatus')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060B0F) : const Color(0xFFF1F5F9),
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(context, isDark, textPrimary),
      body: Stack(
        children: [
          // 1. Ambient Glowing Neon Orbs (Glassmorphism backdrop depth)
          _buildAmbientGlowOrbs(isDark),

          // 2. Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Contact Security Header Glass Card
                  _buildContactSecurityGlassCard(isDark, textPrimary, textSecondary),
                  const SizedBox(height: 20),

                  // Mode Segmented Switcher (QR Code vs Safety Number)
                  _buildGlassSegmentedSwitcher(isDark),
                  const SizedBox(height: 20),

                  // 3D Perspective Flip Transform Card
                  _buildTransformCard(isDark, textPrimary, textSecondary),
                  const SizedBox(height: 24),

                  // Transformative Verification Action & Sharing Bar
                  _buildBottomGlassActionBar(isDark, textPrimary),
                  const SizedBox(height: 20),

                  // Quantum E2EE Micro-notice
                  _buildQuantumDisclaimer(isDark, textSecondary),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Glassmorphic App Bar ---
  PreferredSizeWidget _buildGlassAppBar(BuildContext context, bool isDark, Color textPrimary) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: isDark ? const Color(0xFF060B0F).withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.75),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                context.tr('securityKeyVerification'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 22),
                  color: textPrimary,
                  tooltip: context.tr('shareSecurityKey'),
                  onPressed: _copySafetyNumber,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 2. Ambient Glowing Neon Orbs ---
  Widget _buildAmbientGlowOrbs(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final pulse = _pulseAnimation.value;
        return Stack(
          children: [
            // Top Left Emerald Orb
            Positioned(
              top: -40 + (pulse * 20),
              left: -40 + (pulse * 15),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.32 : 0.22),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Center Right Electric Cyan Orb
            Positioned(
              top: 220 - (pulse * 30),
              right: -60 + (pulse * 20),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.28 : 0.18),
                      const Color(0xFF06B6D4).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Left Indigo Glow Orb
            Positioned(
              bottom: 40 + (pulse * 25),
              left: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: isDark ? 0.22 : 0.14),
                      const Color(0xFF6366F1).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 3. Contact Security Glass Card ---
  Widget _buildContactSecurityGlassCard(bool isDark, Color textPrimary, Color textSecondary) {
    return _buildGlassBox(
      isDark: isDark,
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with glowing verified status halo
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _isVerified ? AppColors.primary : const Color(0xFFF59E0B),
                      const Color(0xFF06B6D4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isVerified ? AppColors.primary : const Color(0xFFF59E0B)).withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _isVerified ? AppColors.primary : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _isVerified ? AppColors.primary : const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isVerified ? Icons.check_rounded : Icons.priority_high_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // User info and live security status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.contactName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (_isVerified ? AppColors.primary : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_isVerified ? AppColors.primary : const Color(0xFFF59E0B)).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isVerified ? Icons.shield_rounded : Icons.shield_outlined,
                            size: 11,
                            color: _isVerified ? AppColors.primary : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isVerified ? context.tr('keyVerifiedStatus') : context.tr('unverifiedStatus'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _isVerified ? AppColors.primary : const Color(0xFFF59E0B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('compareSafetyNumberDesc'),
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Glass Segmented Mode Switcher ---
  Widget _buildGlassSegmentedSwitcher(bool isDark) {
    return _buildGlassBox(
      isDark: isDark,
      padding: const EdgeInsets.all(5),
      borderRadius: 24,
      child: Row(
        children: [
          // QR Code Tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isFlipped) _toggleFlip();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: !_isFlipped
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            const Color(0xFF06B6D4),
                          ],
                        )
                      : null,
                  color: _isFlipped ? Colors.transparent : null,
                  boxShadow: !_isFlipped
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_rounded,
                      size: 18,
                      color: !_isFlipped ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('qrCodeTab'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isFlipped ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Safety Numbers Tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isFlipped) _toggleFlip();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: _isFlipped
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            const Color(0xFF06B6D4),
                          ],
                        )
                      : null,
                  color: !_isFlipped ? Colors.transparent : null,
                  boxShadow: _isFlipped
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pin_rounded,
                      size: 18,
                      color: _isFlipped ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('safetyNumbersTab'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isFlipped ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. 3D Perspective Flip Transform Card ---
  Widget _buildTransformCard(bool isDark, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final value = _flipAnimation.value;
          final angle = value * math.pi;
          final isBack = angle > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // authentic 3D perspective depth
              ..rotateY(angle),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi), // un-mirror back face
                    child: _buildBackFace(isDark, textPrimary, textSecondary),
                  )
                : _buildFrontFace(isDark, textPrimary, textSecondary),
          );
        },
      ),
    );
  }

  // 5A. Front Face: Frosted Glass QR Code with Animated Laser Scanner
  Widget _buildFrontFace(bool isDark, Color textPrimary, Color textSecondary) {
    return _buildGlassBox(
      isDark: isDark,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        children: [
          // Top Title & Flip Cue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, size: 17, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'LAJU SECURE QR',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip_camera_android_rounded, size: 12, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('tapToFlipCard'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR Box with Animated Laser Scanner Line
          Stack(
            alignment: Alignment.center,
            children: [
              // High-Definition QR Card with embedded LAJU Logo
              LajuQrCodeView(
                data: 'laju://verify-key/${widget.contactName}?sn=${widget.safetyNumber.replaceAll(' ', '')}',
                size: 220,
              ),

              // Animated Glowing Laser Scanner Line
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    final progress = _laserAnimation.value;
                    return Align(
                      alignment: Alignment(0, -1.0 + (progress * 2.0)),
                      child: Container(
                        width: 220,
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary,
                              const Color(0xFF06B6D4),
                              AppColors.primary,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Scan with Camera Action Pill
          InkWell(
            onTap: _openScannerCamera,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('scanQrCode'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5B. Back Face: Frosted Glass 60-Digit Holographic Safety Numbers
  Widget _buildBackFace(bool isDark, Color textPrimary, Color textSecondary) {
    final blocks = widget.safetyNumber.split(' ');

    return _buildGlassBox(
      isDark: isDark,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          // Top Header & Flip Cue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 17, color: Color(0xFF06B6D4)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '60-DIGIT SAFETY CODE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip_camera_android_rounded, size: 12, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('tapToFlipCard'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 12 Blocks of 5 digits displayed in a frosted glass grid (responsive 4 or 3 columns)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 310 ? 4 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: crossAxisCount == 4 ? 2.1 : 2.4,
                ),
                itemCount: blocks.length,
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131D26).withValues(alpha: 0.75)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      block,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: crossAxisCount == 4 ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Copy Button
          InkWell(
            onTap: _copySafetyNumber,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('copySafetyNumber'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF06B6D4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Transformative Action & Sharing Glass Bar ---
  Widget _buildBottomGlassActionBar(bool isDark, Color textPrimary) {
    return Column(
      children: [
        // Scan QR Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
          label: Text(
            context.tr('scanCode').toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8),
          ),
          onPressed: _openScannerCamera,
        ),
        const SizedBox(height: 12),

        // Primary Verification Toggle Button
        GestureDetector(
          onTap: _toggleVerification,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: _isVerified
                  ? LinearGradient(
                      colors: [
                        AppColors.primary,
                        const Color(0xFF059669),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        isDark ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                      ],
                    ),
              boxShadow: _isVerified
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isVerified ? Icons.verified_rounded : Icons.check_circle_outline_rounded,
                  color: _isVerified ? Colors.white : textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  _isVerified ? context.tr('keyVerifiedStatus').toUpperCase() : context.tr('markAsVerified').toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: _isVerified ? Colors.white : textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 7. Quantum Security Disclaimer ---
  Widget _buildQuantumDisclaimer(bool isDark, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${context.tr('quantumShieldActive')} • Double Ratchet Protocol',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary.withValues(alpha: 0.85),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // --- Reusable Glass Container Builder ---
  Widget _buildGlassBox({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 20,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: [
                isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.85),
                isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.60),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.3,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
