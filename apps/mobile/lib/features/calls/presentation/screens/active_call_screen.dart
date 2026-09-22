import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/laju_glass.dart';
import '../../../../core/widgets/modern_avatar.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/call_session_controller.dart';

class ActiveCallScreen extends StatefulWidget {
  final String contactName;
  final String? calleeUserId;
  final String? contactPhone;
  final bool isVideo;
  final bool returnToCallsScreen;

  const ActiveCallScreen({
    super.key,
    required this.contactName,
    this.calleeUserId,
    this.contactPhone,
    this.isVideo = false,
    this.returnToCallsScreen = false,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late bool _isVideoEnabled;
  MobileScannerController? _cameraController;
  bool _isFrontCamera = true;
  bool _isCameraInMainView = true;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideo;

    if (_isVideoEnabled) {
      _startCamera();
    }

    final session = CallSessionController.instance;
    session.addListener(_onSessionUpdated);
    if (!session.isActive || session.callId == null) {
      session.start1on1Call(
        contactName: widget.contactName,
        calleeUserId: widget.calleeUserId,
        contactPhone: widget.contactPhone,
        isVideo: widget.isVideo,
      );
    } else {
      _isVideoEnabled = session.isVideoOn;
    }
  }

  void _startCamera() {
    _cameraController?.dispose();
    _cameraController = MobileScannerController(
      facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      torchEnabled: false,
    );
  }

  void _stopCamera() {
    _cameraController?.dispose();
    _cameraController = null;
  }

  void _switchCamera() async {
    _isFrontCamera = !_isFrontCamera;
    try {
      await _cameraController?.switchCamera();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _swapViews() {
    setState(() {
      _isCameraInMainView = !_isCameraInMainView;
    });
  }

  @override
  void dispose() {
    _stopCamera();
    CallSessionController.instance.removeListener(_onSessionUpdated);
    super.dispose();
  }

  void _onSessionUpdated() {
    if (!mounted) return;
    final session = CallSessionController.instance;
    if (_isVideoEnabled != session.isVideoOn) {
      setState(() {
        _isVideoEnabled = session.isVideoOn;
        if (_isVideoEnabled) {
          _startCamera();
        } else {
          _stopCamera();
        }
      });
    }
    if (session.status == CallStatus.rejected || session.status == CallStatus.ended) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _exitCall();
        }
      });
    }
  }

  void _minimizeCall() {
    CallSessionController.instance.minimize();
    Navigator.pop(context);
  }

  void _endCall() {
    CallSessionController.instance.endCall();
    _exitCall();
  }

  void _exitCall() {
    if (widget.returnToCallsScreen) {
      HomeScreen.activeTabNotifier.value = 2;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.pop(context);
    }
  }

  Color _getStatusBadgeBgColor(CallStatus status) {
    switch (status) {
      case CallStatus.connecting:
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case CallStatus.ringing:
        return AppColors.cyan.withValues(alpha: 0.15);
      case CallStatus.connected:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case CallStatus.rejected:
        return AppColors.danger.withValues(alpha: 0.18);
      case CallStatus.ended:
      default:
        return Colors.grey.withValues(alpha: 0.15);
    }
  }

  Color _getStatusBadgeBorderColor(CallStatus status) {
    switch (status) {
      case CallStatus.connecting:
        return const Color(0xFFF59E0B).withValues(alpha: 0.4);
      case CallStatus.ringing:
        return AppColors.cyan.withValues(alpha: 0.4);
      case CallStatus.connected:
        return const Color(0xFF10B981).withValues(alpha: 0.4);
      case CallStatus.rejected:
        return AppColors.danger.withValues(alpha: 0.5);
      case CallStatus.ended:
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  Color _getStatusBadgeTextColor(CallStatus status) {
    switch (status) {
      case CallStatus.connecting:
        return const Color(0xFFF59E0B);
      case CallStatus.ringing:
        return AppColors.cyan;
      case CallStatus.connected:
        return const Color(0xFF10B981);
      case CallStatus.rejected:
        return AppColors.danger;
      case CallStatus.ended:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CallSessionController.instance,
      builder: (context, _) {
        final session = CallSessionController.instance;
        final isDark = ThemeModeController.instance.isDarkMode(context);

        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _minimizeCall();
          },
          child: Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
            body: LajuGlassBackground(
              showOrbs: true,
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Frosted Navigation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          LajuGlassCard(
                            padding: const EdgeInsets.all(8),
                            borderRadius: 14,
                            blurSigma: 12,
                            onTap: _minimizeCall,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 26,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Contact Info Header
                    Text(
                      widget.contactName,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusBadgeBgColor(session.status),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _getStatusBadgeBorderColor(session.status)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (session.status == CallStatus.connecting || session.status == CallStatus.ringing)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getStatusBadgeTextColor(session.status),
                              ),
                            ),
                          Text(
                            session.statusLabel,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: _getStatusBadgeTextColor(session.status),
                              fontWeight: FontWeight.w700,
                              letterSpacing: session.status == CallStatus.connected ? 1.2 : 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Visualizer / Video Frame
                    if (_isVideoEnabled)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Main Stage Card (Either Local Live Camera or Remote Avatar)
                            LajuGlassCard(
                              padding: const EdgeInsets.all(3),
                              borderRadius: 28,
                              blurSigma: 24,
                              borderColor: AppColors.primary.withValues(alpha: 0.45),
                              borderWidth: 1.5,
                              customShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                              child: Container(
                                width: double.infinity,
                                height: 320,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: Colors.black,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: Stack(
                                    children: [
                                      if (_isCameraInMainView) ...[
                                        if (_cameraController != null)
                                          Positioned.fill(
                                            child: MobileScanner(
                                              controller: _cameraController!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        else
                                          const Center(
                                            child: CircularProgressIndicator(color: AppColors.primary),
                                          ),
                                        // Camera label & flip button
                                        Positioned(
                                          top: 12,
                                          left: 14,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.videocam_rounded, size: 14, color: AppColors.primary),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Kamera Anda (HD Live)',
                                                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 12,
                                          left: 14,
                                          child: GestureDetector(
                                            onTap: _switchCamera,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.black60,
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 16),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Putar Kamera',
                                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        // Remote contact view on main stage
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ModernAvatar(
                                                name: widget.contactName,
                                                radius: 50,
                                                isVerified: true,
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                widget.contactName,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '1080p 60fps • Terenkripsi E2EE',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Floating Picture-in-Picture (PiP) Window (Tap to swap!)
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: GestureDetector(
                                onTap: _swapViews,
                                child: Container(
                                  width: 110,
                                  height: 155,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.8),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        if (!_isCameraInMainView) ...[
                                          if (_cameraController != null)
                                            MobileScanner(
                                              controller: _cameraController!,
                                              fit: BoxFit.cover,
                                            )
                                          else
                                            const Center(
                                              child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 28),
                                            ),
                                          // Flip button
                                          Positioned(
                                            bottom: 6,
                                            right: 6,
                                            child: GestureDetector(
                                              onTap: _switchCamera,
                                              child: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.flip_camera_ios_rounded,
                                                  color: Colors.white,
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          // Remote contact mini avatar
                                          Container(
                                            color: const Color(0xFF1E293B),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  ModernAvatar(
                                                    name: widget.contactName,
                                                    radius: 26,
                                                    isVerified: true,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: Text(
                                                      widget.contactName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Tukar (Ketuk)',
                                                    style: TextStyle(color: AppColors.primary, fontSize: 9.5, fontWeight: FontWeight.w600),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: ModernAvatar(
                              name: widget.contactName,
                              radius: 64,
                              isVerified: true,
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Animated glass equalizer waveform bars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(14, (index) {
                              final heights = [14.0, 26.0, 42.0, 18.0, 36.0, 50.0, 28.0, 44.0, 20.0, 32.0, 16.0, 38.0, 22.0, 12.0];
                              return Container(
                                width: 3.5,
                                height: heights[index % heights.length],
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [AppColors.primary, AppColors.cyan],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),

                    const Spacer(),

                    // Floating Glassmorphic Bottom Control Panel
                    LajuGlassCard(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      borderRadius: 30,
                      blurSigma: 24,
                      borderColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCallAction(
                            icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            isActive: session.isMuted,
                            label: 'Mute',
                            onTap: () {
                              session.toggleMute();
                            },
                          ),
                          _buildCallAction(
                            icon: session.isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                            isActive: session.isVideoOn,
                            label: 'Video',
                            onTap: () {
                              session.toggleVideo();
                            },
                          ),
                          if (_isVideoEnabled)
                            _buildCallAction(
                              icon: Icons.flip_camera_ios_rounded,
                              isActive: false,
                              label: 'Putar',
                              onTap: _switchCamera,
                            ),
                          _buildCallAction(
                            icon: session.isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                            isActive: session.isSpeaker,
                            label: 'Speaker',
                            onTap: () {
                              session.toggleSpeaker();
                            },
                          ),
                          _buildCallAction(
                            icon: Icons.call_end_rounded,
                            isEndCall: true,
                            label: 'Akhiri',
                            onTap: _endCall,
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
      },
    );
  }

  Widget _buildCallAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isEndCall = false,
  }) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final bgColor = isEndCall
        ? AppColors.danger
        : (isActive
            ? AppColors.primary
            : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFF1F5F9)));
    final iconColor = isEndCall
        ? Colors.white
        : (isActive
            ? Colors.black
            : (isDark ? Colors.white : AppColors.textPrimary));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEndCall
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : (isActive
                        ? AppColors.primary
                        : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1))),
                width: 1.2,
              ),
              boxShadow: [
                if (isEndCall)
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                else if (isActive)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
