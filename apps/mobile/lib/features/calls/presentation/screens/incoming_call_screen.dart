import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import '../../domain/call_session_controller.dart';
import 'active_call_screen.dart';
import 'active_group_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final bool isVideo;
  final String? callerId;
  final String? callerPhone;
  final String? avatarUrl;
  final bool isGroup;
  final String? groupName;
  final String? conversationId;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.isVideo,
    this.callerId,
    this.callerPhone,
    this.avatarUrl,
    this.isGroup = false,
    this.groupName,
    this.conversationId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Timer? _vibrateTimer;
  bool _isActionTaken = false;

  static const MethodChannel _systemNotifChannel =
      MethodChannel('com.laju.laju_mobile/system_notifications');

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _startRingtoneAndVibration();
    _enableLockscreenWindow();

    // Listen to session changes to auto-dismiss if remote ends call
    CallSessionController.instance.addListener(_handleSessionStatusChange);
  }

  void _enableLockscreenWindow() {
    try {
      _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': true});
    } catch (_) {}
  }

  void _disableLockscreenWindow() {
    try {
      _systemNotifChannel.invokeMethod('setLockscreenActive', {'active': false});
    } catch (_) {}
  }

  void _startRingtoneAndVibration() {
    try {
      LajuSoundService.playRingtone('Panggilan Masuk');
      LajuSoundService.triggerVibrate('Panjang');
    } catch (_) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    _vibrateTimer?.cancel();
    _vibrateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _isActionTaken) return;
      try {
        LajuSoundService.triggerVibrate('Panjang');
      } catch (_) {
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
      }
    });
  }

  void _stopRingtoneAndVibration() {
    _vibrateTimer?.cancel();
    _vibrateTimer = null;
    try {
      LajuSoundService.stopRingtone();
    } catch (_) {}
  }

  void _handleSessionStatusChange() {
    if (!mounted || _isActionTaken) return;
    final session = CallSessionController.instance;

    // If call was rejected, busy, ended remotely, or caller cancelled before answer
    if (session.status == CallStatus.ended ||
        session.status == CallStatus.rejected ||
        session.status == CallStatus.busy ||
        (!session.isActive && session.lastRingingCallId != widget.callId)) {
      _dismissScreen();
    }
  }

  void _dismissScreen() {
    if (_isActionTaken || !mounted) return;
    _isActionTaken = true;
    _stopRingtoneAndVibration();
    _disableLockscreenWindow();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleAccept() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _stopRingtoneAndVibration();
    HapticFeedback.heavyImpact();

    try {
      if (widget.isGroup) {
        await CallSessionController.instance.answerIncomingGroupCall(
          widget.callId,
          groupName: widget.groupName ?? widget.callerName,
          conversationId: widget.conversationId,
          isVideo: widget.isVideo,
          callerName: widget.callerName,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveGroupCallScreen(
              groupName: widget.groupName ?? widget.callerName,
              initialParticipants: [widget.callerName],
              initialParticipantIds: widget.callerId != null ? [widget.callerId!] : null,
              isVideo: widget.isVideo,
              conversationId: widget.conversationId,
            ),
          ),
        );
      } else {
        await CallSessionController.instance.answerIncomingCall(
          widget.callId,
          callerName: widget.callerName,
          isVideo: widget.isVideo,
          callerId: widget.callerId,
          callerPhone: widget.callerPhone,
          avatarUrl: widget.avatarUrl,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              contactName: widget.callerName,
              calleeUserId: widget.callerId,
              contactPhone: widget.callerPhone,
              avatarUrl: widget.avatarUrl,
              isVideo: widget.isVideo,
            ),
          ),
        );
      }
    } catch (e) {
      _dismissScreen();
    }
  }

  Future<void> _handleDecline() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _stopRingtoneAndVibration();
    _disableLockscreenWindow();
    HapticFeedback.mediumImpact();

    try {
      await CallSessionController.instance.declineIncomingCall(
        widget.callId,
        callerName: widget.callerName,
        isVideo: widget.isVideo,
        callerId: widget.callerId,
        callerPhone: widget.callerPhone,
        avatarUrl: widget.avatarUrl,
      );
    } catch (_) {}

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    CallSessionController.instance.removeListener(_handleSessionStatusChange);
    _pulseController.dispose();
    _stopRingtoneAndVibration();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDisplayName = widget.isGroup && widget.groupName != null
        ? '${widget.callerName} di ${widget.groupName}'
        : widget.callerName;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleDecline();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B132B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Dark Frosted Atmospheric Gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      const Color(0xFF0B132B),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Top E2EE Security Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TERENKRIPSI END-TO-END',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Center Avatar with Concentric Pulse Wave
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final val = _pulseController.value;
                              return Container(
                                width: 140 + (val * 50),
                                height: 140 + (val * 50),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: (1.0 - val) * 0.45,
                                    ),
                                    width: 2.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final val = (_pulseController.value + 0.5) % 1.0;
                              return Container(
                                width: 130 + (val * 40),
                                height: 130 + (val * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF06B6D4).withValues(
                                      alpha: (1.0 - val) * 0.35,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: ModernAvatar(
                              name: widget.callerName,
                              imagePath: widget.avatarUrl,
                              radius: 60,
                              isVerified: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Caller Name
                    Text(
                      effectiveDisplayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Call Type Subtitle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideo
                              ? 'Panggilan Video Masuk...'
                              : 'Panggilan Suara Masuk...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 3),

                    // Action Buttons Row (Tolak & Jawab)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Decline Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _handleDecline,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFEF4444),
                                        Color(0xFFDC2626),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                                        blurRadius: 24,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.call_end_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tolak',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),

                          // Accept Button
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _handleAccept,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF00C896),
                                        Color(0xFF059669),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.5),
                                        blurRadius: 28,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      widget.isVideo
                                          ? Icons.videocam_rounded
                                          : Icons.call_rounded,
                                      color: Colors.black,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Jawab',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
