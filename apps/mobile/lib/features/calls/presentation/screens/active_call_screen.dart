import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/core.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/call_session_controller.dart';
import '../../domain/webrtc_call_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final String contactName;
  final String? calleeUserId;
  final String? contactPhone;
  final String? avatarUrl;
  final bool isVideo;
  final bool returnToCallsScreen;

  const ActiveCallScreen({
    super.key,
    required this.contactName,
    this.calleeUserId,
    this.contactPhone,
    this.avatarUrl,
    this.isVideo = false,
    this.returnToCallsScreen = false,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late bool _isVideoEnabled;
  CameraController? _cameraController;
  bool _isFrontCamera = true;
  bool _isCameraInMainView = false;

  Uint8List? _remoteVideoBytes;
  int _lastRemoteFrameTime = 0;
  Timer? _remoteVideoPoller;
  bool _isConvertingFrame = false;
  int _lastFrameSentTime = 0;

  String? get _resolvedAvatarUrl =>
      widget.avatarUrl ?? CallSessionController.instance.avatarUrl;

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.isVideo;

    if (_isVideoEnabled) {
      _startCamera();
      _startRemoteVideoPoller();
    }

    final session = CallSessionController.instance;
    session.addListener(_onSessionUpdated);
    if (!session.isActive || session.callId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        session.start1on1Call(
          contactName: widget.contactName,
          calleeUserId: widget.calleeUserId,
          contactPhone: widget.contactPhone,
          avatarUrl: widget.avatarUrl,
          isVideo: widget.isVideo,
        );
      });
    } else {
      _isVideoEnabled = session.isVideoOn;
    }
  }

  void _startCamera() async {
    // If WebRTC already acquired local camera stream, no need to lock hardware camera with CameraController
    if (WebRTCCallService.instance.localStream != null &&
        WebRTCCallService.instance.localStream!.getVideoTracks().isNotEmpty) {
      debugPrint('[ActiveCallScreen] WebRTC owns local stream, skipping CameraController');
      if (mounted) setState(() {});
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      final old = _cameraController;
      _cameraController = null;
      await old?.dispose();

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {});

      _startImageStreaming();
    } catch (e) {
      debugPrint('[ActiveCallScreen] Camera initialization error: $e');
    }
  }


  void _startImageStreaming() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isVideoEnabled || !mounted) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastFrameSentTime < 160) return; // ~6 FPS
        if (_isConvertingFrame) return;
        _isConvertingFrame = true;
        _lastFrameSentTime = now;

        try {
          final Uint8List? jpeg = await const MethodChannel('com.laju/call_audio').invokeMethod('convertYuvToJpeg', {
            'y': image.planes[0].bytes,
            'u': image.planes[1].bytes,
            'v': image.planes[2].bytes,
            'width': image.width,
            'height': image.height,
            'yRowStride': image.planes[0].bytesPerRow,
            'uvRowStride': image.planes[1].bytesPerRow,
            'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
            'quality': 78,
            'isFront': _isFrontCamera,
          });

          if (jpeg != null && jpeg.isNotEmpty) {
            final curCallId = CallSessionController.instance.callId;
            if (curCallId != null && !curCallId.startsWith('call-') && !curCallId.startsWith('group-')) {
              final b64 = base64Encode(jpeg);
              ApiClient.instance.post(
                ApiEndpoints.callVideoFrame(curCallId),
                body: {'frame': b64},
              ).catchError((_) => ApiResponse<dynamic>.error(500, 'Video frame error'));
            }
          }
        } catch (_) {
        } finally {
          _isConvertingFrame = false;
        }
      });
    } catch (e) {
      debugPrint('[ActiveCallScreen] startImageStream error: $e');
    }
  }

  void _startRemoteVideoPoller() {
    _remoteVideoPoller?.cancel();
    _remoteVideoPoller = Timer.periodic(const Duration(milliseconds: 140), (_) async {
      if (!mounted || !_isVideoEnabled) return;
      final curCallId = CallSessionController.instance.callId;
      if (curCallId == null || curCallId.startsWith('call-') || curCallId.startsWith('group-')) return;
      if (CallSessionController.instance.status != CallStatus.connected) return;

      try {
        final resp = await ApiClient.instance.get(ApiEndpoints.callVideoFrame(curCallId));
        if (resp.isSuccess && resp.rawJson is Map) {
          final b64 = resp.rawJson['frame'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            final bytes = base64Decode(b64);
            if (mounted) {
              setState(() {
                _remoteVideoBytes = bytes;
                _lastRemoteFrameTime = DateTime.now().millisecondsSinceEpoch;
              });
            }
          }
        }
      } catch (_) {}
    });
  }

  void _stopCamera() {
    _remoteVideoPoller?.cancel();
    _remoteVideoPoller = null;
    _cameraController?.dispose();
    _cameraController = null;
  }

  void _switchCamera() async {
    _isFrontCamera = !_isFrontCamera;
    if (WebRTCCallService.instance.localStream != null) {
      await WebRTCCallService.instance.switchCamera();
      if (mounted) setState(() {});
    } else {
      _startCamera();
    }
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

  bool _isExiting = false;

  void _onSessionUpdated() {
    if (!mounted) return;
    final session = CallSessionController.instance;
    if (_isVideoEnabled != session.isVideoOn) {
      setState(() {
        _isVideoEnabled = session.isVideoOn;
        if (_isVideoEnabled) {
          _startCamera();
          _startRemoteVideoPoller();
        } else {
          _stopCamera();
        }
      });
    }
    if (session.status == CallStatus.rejected || session.status == CallStatus.ended) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          _exitCall();
        }
      });
    }
  }

  void _minimizeCall() {
    if (_isExiting) return;
    _isExiting = true;
    CallSessionController.instance.minimize();
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  void _endCall() {
    CallSessionController.instance.endCall();
    _exitCall();
  }

  void _exitCall() {
    if (_isExiting) return;
    _isExiting = true;

    if (!mounted) return;

    if (widget.returnToCallsScreen) {
      HomeScreen.activeTabNotifier.value = 2;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
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
            backgroundColor: _isVideoEnabled
                ? Colors.black
                : (isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9)),
            body: _isVideoEnabled
                ? _buildVideoCallView(session)
                : _buildAudioCallView(session, isDark, textPrimary, textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildVideoCallView(CallSessionController session) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fullscreen Main Stage (Remote Video or Local Camera)
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: _switchCamera,
            child: _isCameraInMainView
                ? _buildLocalCameraPreview(isPip: false)
                : _buildRemoteVideoView(isPip: false, textPrimary: Colors.white, textSecondary: Colors.white70),
          ),
        ),

        // 2. Top Vignette Gradient for Header Contrast
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. Bottom Vignette Gradient for Controls Contrast
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.88),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4. Top Floating App Bar (Minimize, Contact Info & Status, Camera Flip)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  LajuGlassCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: 14,
                    blurSigma: 16,
                    borderColor: Colors.white.withValues(alpha: 0.2),
                    onTap: _minimizeCall,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.contactName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    if (session.status == CallStatus.connecting || session.status == CallStatus.ringing)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getStatusBadgeTextColor(session.status),
                                        ),
                                      ),
                                    Text(
                                      session.statusLabel,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: _getStatusBadgeTextColor(session.status),
                                        fontWeight: FontWeight.w600,
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
                  const SizedBox(width: 10),
                  LajuGlassCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: 14,
                    blurSigma: 16,
                    borderColor: Colors.white.withValues(alpha: 0.2),
                    onTap: _switchCamera,
                    child: const Icon(
                      Icons.flip_camera_ios_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 5. Floating Picture-in-Picture (PiP) Window (Tap to swap!)
        Positioned(
          top: 96,
          right: 16,
          child: GestureDetector(
            onTap: _swapViews,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.85),
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
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: !_isCameraInMainView
                          ? _buildLocalCameraPreview(isPip: true)
                          : _buildRemoteVideoView(isPip: true, textPrimary: Colors.white, textSecondary: Colors.white70),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 11, color: Colors.white70),
                            SizedBox(width: 3),
                            Text(
                              'Tukar',
                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 6. Floating Glassmorphic Bottom Controls Dock
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: LajuGlassCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              borderRadius: 30,
              blurSigma: 24,
              borderColor: Colors.white.withValues(alpha: 0.15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallAction(
                    icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    isActive: session.isMuted,
                    label: 'Mute',
                    onTap: session.toggleMute,
                  ),
                  _buildCallAction(
                    icon: session.isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    isActive: session.isVideoOn,
                    label: 'Video',
                    onTap: session.toggleVideo,
                  ),
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
                    onTap: session.toggleSpeaker,
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
          ),
        ),
      ],
    );
  }

  Widget _buildAudioCallView(
    CallSessionController session,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LajuGlassBackground(
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

            // Large Animated Avatar & Audio Waveform
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
                    imagePath: _resolvedAvatarUrl,
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

            // Bottom Call Controls
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
                    onTap: session.toggleMute,
                  ),
                  _buildCallAction(
                    icon: session.isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    isActive: session.isVideoOn,
                    label: 'Video',
                    onTap: session.toggleVideo,
                  ),
                  _buildCallAction(
                    icon: session.isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    isActive: session.isSpeaker,
                    label: 'Speaker',
                    onTap: session.toggleSpeaker,
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
    final isVideo = _isVideoEnabled;
    final bgColor = isEndCall
        ? AppColors.danger
        : (isActive
            ? AppColors.primary
            : (isVideo
                ? Colors.black.withValues(alpha: 0.5)
                : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFF1F5F9))));
    final iconColor = isEndCall
        ? Colors.white
        : (isActive
            ? Colors.black
            : (isVideo || isDark ? Colors.white : AppColors.textPrimary));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEndCall
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : (isActive
                        ? AppColors.primary
                        : (isVideo ? Colors.white.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1)))),
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
              color: isVideo ? Colors.white.withValues(alpha: 0.9) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalCameraPreview({required bool isPip}) {
    final localRenderer = WebRTCCallService.instance.localRenderer;
    final hasWebRtcStream = localRenderer != null && localRenderer.srcObject != null;

    if (hasWebRtcStream) {
      return RTCVideoView(
        localRenderer,
        mirror: _isFrontCamera,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      Widget preview = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );

      if (_isFrontCamera) {
        preview = Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(math.pi),
          child: preview,
        );
      }

      return preview;
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }

  Widget _buildRemoteVideoView({required bool isPip, required Color textPrimary, required Color textSecondary}) {
    final remoteRenderer = WebRTCCallService.instance.remoteRenderer;
    final hasWebRtcStream = remoteRenderer != null && remoteRenderer.srcObject != null;

    if (hasWebRtcStream) {
      return RTCVideoView(
        remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final hasLiveFrame = _remoteVideoBytes != null && (now - _lastRemoteFrameTime < 6000);

    if (hasLiveFrame) {
      return Image.memory(
        _remoteVideoBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Modern placeholder while waiting for peer's camera feed
    return Container(
      color: const Color(0xFF0F172A),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ModernAvatar(
              name: widget.contactName,
              imagePath: _resolvedAvatarUrl,
              radius: isPip ? 26 : 48,
              isVerified: true,
            ),
            SizedBox(height: isPip ? 6 : 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                widget.contactName,
                style: TextStyle(
                  fontSize: isPip ? 11 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isPip ? 5 : 7,
                  height: isPip ? 5 : 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  CallSessionController.instance.status == CallStatus.connected
                      ? 'Menghubungkan video...'
                      : 'Memanggil...',
                  style: TextStyle(
                    fontSize: isPip ? 9 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
