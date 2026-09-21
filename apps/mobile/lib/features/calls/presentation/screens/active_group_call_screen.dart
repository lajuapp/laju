import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../conversations/domain/conversation_service.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/call_session_controller.dart';

enum ParticipantCallStatus { ringing, connected, unanswered }

class GroupCallParticipant {
  final String id;
  final String name;
  final bool isSelf;
  ParticipantCallStatus status;
  int ringingSeconds;
  bool isSpeaking;
  bool isMuted;
  bool isVideoOn;
  double opacity;

  GroupCallParticipant({
    required this.id,
    required this.name,
    this.isSelf = false,
    this.status = ParticipantCallStatus.ringing,
    this.ringingSeconds = 0,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isVideoOn = false,
    this.opacity = 1.0,
  });
}

class ActiveGroupCallScreen extends StatefulWidget {
  final String groupName;
  final List<String> initialParticipants;
  final bool isVideo;
  final bool returnToCallsScreen;

  const ActiveGroupCallScreen({
    super.key,
    required this.groupName,
    required this.initialParticipants,
    this.isVideo = false,
    this.returnToCallsScreen = false,
  });

  @override
  State<ActiveGroupCallScreen> createState() => _ActiveGroupCallScreenState();
}

class _ActiveGroupCallScreenState extends State<ActiveGroupCallScreen>
    with TickerProviderStateMixin {
  late final List<GroupCallParticipant> _participants;
  final List<GroupCallParticipant> _unansweredHistory = [];

  bool _isSelfMuted = false;
  bool _isSpeakerOn = true;
  late bool _isSelfVideoOn;
  int _callDurationSeconds = 0;
  Timer? _tickerTimer;
  Timer? _speechCycleTimer;

  late final AnimationController _pulseController;
  late final AnimationController _equalizerController;

  @override
  void initState() {
    super.initState();
    _isSelfVideoOn = widget.isVideo;

    final session = CallSessionController.instance;
    if (!session.isActive || session.callId == null || !session.isGroup) {
      session.startGroupCall(
        groupName: widget.groupName,
        initialParticipants: widget.initialParticipants,
        isVideo: widget.isVideo,
      );
    } else {
      _isSelfMuted = session.isMuted;
      _isSpeakerOn = session.isSpeaker;
      _isSelfVideoOn = session.isVideoOn;
    }

    // Self participant
    final participantsList = <GroupCallParticipant>[
      GroupCallParticipant(
        id: 'self',
        name: 'You',
        isSelf: true,
        status: ParticipantCallStatus.connected,
        isVideoOn: widget.isVideo,
      ),
    ];

    // Seed other participants from initialParticipants
    final seeds = widget.initialParticipants;

    for (int i = 0; i < seeds.length; i++) {
      participantsList.add(
        GroupCallParticipant(
          id: 'p-$i',
          name: seeds[i],
          isSelf: false,
          status: ParticipantCallStatus.ringing,
          isVideoOn: widget.isVideo,
        ),
      );
    }

    _participants = participantsList;

    // Animation controllers for ringing pulse and speech equalizer
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startCallTimers();
  }

  void _startCallTimers() {
    // 1-second call heartbeat
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _callDurationSeconds++;

        // Auto-answer simulation:
        // Participant 1 answers at 3 seconds
        // Participant 2 answers at 7 seconds (if more than 2)
        // Others keep ringing up to 60s timeout
        for (int i = 0; i < _participants.length; i++) {
          final p = _participants[i];
          if (p.isSelf) continue;

          if (p.status == ParticipantCallStatus.ringing) {
            p.ringingSeconds++;

            // Dynamic realistic answer for demonstration
            if (i == 1 && p.ringingSeconds >= 3) {
              p.status = ParticipantCallStatus.connected;
            } else if (i == 2 && _participants.length > 3 && p.ringingSeconds >= 7) {
              p.status = ParticipantCallStatus.connected;
            }

            // 60-second timeout check
            if (p.ringingSeconds >= 60) {
              _handleTimeout(p);
            }
          }
        }
      });
    });

    // Simulated speech activity for connected participants
    _speechCycleTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted) return;
      setState(() {
        for (final p in _participants) {
          if (p.status == ParticipantCallStatus.connected && !p.isSelf && !p.isMuted) {
            // Alternate speaking state
            p.isSpeaking = !p.isSpeaking;
          }
        }
      });
    });
  }

  void _handleTimeout(GroupCallParticipant participant) {
    participant.status = ParticipantCallStatus.unanswered;

    // Animate fade out and remove participant tile after 1.8 seconds
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        if (_participants.contains(participant)) {
          _participants.remove(participant);
          _unansweredHistory.add(participant);

          final notificationMsg = '${participant.name} ${context.tr('participantRemoved')}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.phone_missed_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notificationMsg,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });
    });
  }

  void _simulateFastForwardTimeout() {
    setState(() {
      for (final p in _participants) {
        if (!p.isSelf && p.status == ParticipantCallStatus.ringing) {
          p.ringingSeconds = 59; // Will trigger next second
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('simulateTimeout'),
          style: const TextStyle(fontSize: 12),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reinviteParticipant(GroupCallParticipant participant) {
    setState(() {
      _unansweredHistory.remove(participant);
      participant.status = ParticipantCallStatus.ringing;
      participant.ringingSeconds = 0;
      participant.opacity = 1.0;
      _participants.add(participant);
    });

    Navigator.pop(context); // close sheet
  }

  void _addContactToCall(String name) {
    setState(() {
      _participants.add(
        GroupCallParticipant(
          id: 'p-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          isSelf: false,
          status: ParticipantCallStatus.ringing,
          isVideoOn: widget.isVideo,
        ),
      );
    });
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _speechCycleTimer?.cancel();
    _pulseController.dispose();
    _equalizerController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
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

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeController.instance.isDarkMode(context);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.surfaceBorder;

    final connectedCount = _participants.where((p) => p.status == ParticipantCallStatus.connected).length;
    final ringingCount = _participants.where((p) => p.status == ParticipantCallStatus.ringing).length;

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
                // Top Bar
                _buildTopBar(connectedCount, ringingCount, isDark, cardColor, textPrimary, textSecondary, borderColor),

                // Main Participants Grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: _buildParticipantsGrid(isDark, cardColor, textPrimary, textSecondary, borderColor),
                  ),
                ),

                // Bottom Action Controls
                _buildBottomControls(isDark, cardColor, textPrimary, textSecondary, borderColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    int connectedCount,
    int ringingCount,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: LajuGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 20,
        blurSigma: 16,
        child: Row(
          children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textPrimary, size: 28),
            tooltip: 'Minimize',
            onPressed: _minimizeCall,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.groupName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDuration(_callDurationSeconds)} • $connectedCount ${context.tr('connected')}${ringingCount > 0 ? ' • $ringingCount ${context.tr('calling')}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Simulation Button: 60s Fast Forward for immediate demonstration
          InkWell(
            onTap: _simulateFastForwardTimeout,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: isDark ? Colors.amber : Colors.amber.shade800, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '60s',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.amber : Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Add Participant Button
            IconButton(
              icon: Icon(Icons.person_add_rounded, color: textPrimary, size: 22),
              tooltip: context.tr('addParticipant'),
              onPressed: () => _showParticipantsSheet(isDark, cardColor, textPrimary, textSecondary, borderColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final count = _participants.length;
    if (count == 0) {
      return Center(
        child: Text(
          context.tr('endCall'),
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    if (count == 1) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: _buildParticipantTile(_participants[0], isDark, cardColor, textPrimary, textSecondary, borderColor, isSingle: true),
      );
    }

    if (count == 2) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(child: _buildParticipantTile(_participants[0], isDark, cardColor, textPrimary, textSecondary, borderColor)),
            const SizedBox(height: 8),
            Expanded(child: _buildParticipantTile(_participants[1], isDark, cardColor, textPrimary, textSecondary, borderColor)),
          ],
        ),
      );
    }

    // 3 or more participants: 2-column grid
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(4),
      clipBehavior: Clip.none,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.88,
      ),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        return _buildParticipantTile(_participants[index], isDark, cardColor, textPrimary, textSecondary, borderColor);
      },
    );
  }

  Widget _buildParticipantTile(
    GroupCallParticipant participant,
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color defaultBorderColor, {
    bool isSingle = false,
  }) {
    final isRinging = participant.status == ParticipantCallStatus.ringing;
    final isConnected = participant.status == ParticipantCallStatus.connected;
    final isUnanswered = participant.status == ParticipantCallStatus.unanswered;
    final isSpeaking = participant.isSelf
        ? (!_isSelfMuted)
        : (participant.isSpeaking && !participant.isMuted);

    Color tileBorderColor = defaultBorderColor;
    if (isRinging) {
      tileBorderColor = isDark ? Colors.amber.withValues(alpha: 0.7) : Colors.amber.shade700;
    } else if (isConnected && isSpeaking) {
      tileBorderColor = AppColors.primary;
    } else if (isUnanswered) {
      tileBorderColor = AppColors.danger;
    }

    final hasActiveBorder = (isConnected && isSpeaking) || isRinging;
    final borderWidth = hasActiveBorder ? 2.5 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: isUnanswered ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: LajuGlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 18,
          blurSigma: 14,
          borderColor: tileBorderColor,
          borderWidth: borderWidth,
          customShadow: [
            if (isConnected && isSpeaking)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 14,
                spreadRadius: 2,
              )
            else if (isRinging)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Inner content clipped to card radius so child background won't spill outside
              ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                  // Video Stream Background if video is active for this user
                  if ((participant.isSelf && _isSelfVideoOn) || (!participant.isSelf && participant.isVideoOn && isConnected))
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [const Color(0xFF1F2937), Colors.black.withValues(alpha: 0.8)]
                                : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                color: AppColors.primary,
                                size: isSingle ? 48 : 36,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'HD Live',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    // Audio Call Avatar View
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Avatar with pulsing ring if ringing
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulseScale = isRinging ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                              return Transform.scale(
                                scale: pulseScale,
                                child: ModernAvatar(
                                  name: participant.isSelf ? 'You' : participant.name,
                                  radius: isSingle ? 46 : 30,
                                  isVerified: true,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Speaking Animated Equalizer
                          if (isConnected && isSpeaking)
                            AnimatedBuilder(
                              animation: _equalizerController,
                              builder: (context, child) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(4, (i) {
                                    final wave = ((i + 1) * 0.25 * _equalizerController.value).clamp(0.2, 1.0);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                      width: 3,
                                      height: 8.0 + (wave * 12.0),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                  // Top Status Badge (Calling / Ringing / Connected / No Answer)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusPill(participant, isRinging, isConnected, isUnanswered, isDark),
                        if (participant.isMuted || (participant.isSelf && _isSelfMuted))
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mic_off_rounded,
                              color: isDark ? Colors.white : const Color(0xFF4B5563),
                              size: 13,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Name Pill
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : defaultBorderColor,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              participant.isSelf ? context.tr('you') : participant.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (participant.isSelf) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Crisp Foreground Border Overlay - drawn on top of all content, completely unclipped so all rounded corners stay 100% visible and smooth
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tileBorderColor,
                      width: borderWidth,
                    ),
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

  Widget _buildStatusPill(
    GroupCallParticipant participant,
    bool isRinging,
    bool isConnected,
    bool isUnanswered,
    bool isDark,
  ) {
    if (isRinging) {
      final remaining = (60 - participant.ringingSeconds).clamp(0, 60);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withValues(alpha: isDark ? 0.5 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ring_volume_rounded, color: isDark ? Colors.amber : Colors.amber.shade800, size: 11),
            const SizedBox(width: 4),
            Text(
              '${context.tr('calling')} ${remaining}s',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.amber : Colors.amber.shade800,
              ),
            ),
          ],
        ),
      );
    }

    if (isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 11),
            const SizedBox(width: 4),
            Text(
              context.tr('connected'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.primary : AppColors.primaryDark,
              ),
            ),
          ],
        ),
      );
    }

    // Unanswered
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: isDark ? 0.6 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_missed_rounded, color: AppColors.danger, size: 11),
          const SizedBox(width: 4),
          Text(
            context.tr('noAnswer'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: LajuGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        borderRadius: 28,
        blurSigma: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Speaker toggle
            _buildActionButton(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: context.tr('speaker'),
              isActive: _isSpeakerOn,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              onTap: () {
                setState(() {
                  _isSpeakerOn = !_isSpeakerOn;
                });
              },
            ),

            // Video toggle
            _buildActionButton(
              icon: _isSelfVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: _isSelfVideoOn ? context.tr('videoOn') : context.tr('videoOff'),
              isActive: _isSelfVideoOn,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              onTap: () {
                setState(() {
                  _isSelfVideoOn = !_isSelfVideoOn;
                });
              },
            ),

            // Mic toggle
            _buildActionButton(
              icon: _isSelfMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isSelfMuted ? context.tr('unmute') : context.tr('mute'),
              isActive: !_isSelfMuted,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              onTap: () {
                setState(() {
                  _isSelfMuted = !_isSelfMuted;
                });
              },
            ),

            // Participants sheet button
            _buildActionButton(
              icon: Icons.group_rounded,
              label: context.tr('callParticipants'),
              badgeText: '${_participants.length}',
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              onTap: () => _showParticipantsSheet(isDark, cardColor, textPrimary, textSecondary, borderColor),
            ),

            // End Call button
            _buildActionButton(
              icon: Icons.call_end_rounded,
              label: context.tr('endCall'),
              isEndCall: true,
              isDark: isDark,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              borderColor: borderColor,
              onTap: _endCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    bool isActive = false,
    bool isEndCall = false,
    String? badgeText,
  }) {
    final bgColor = isEndCall
        ? AppColors.danger
        : (isActive ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.05)));
    final iconColor = isEndCall
        ? Colors.white
        : (isActive ? Colors.black : textPrimary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isEndCall
                        ? AppColors.danger
                        : (isActive ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.15) : borderColor)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isEndCall ? AppColors.danger : (isActive ? AppColors.primary : Colors.black)).withValues(alpha: isEndCall || isActive ? 0.35 : 0.08),
                      blurRadius: 12,
                      spreadRadius: isEndCall || isActive ? 1 : 0,
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showParticipantsSheet(
    bool isDark,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.94) : Colors.white.withValues(alpha: 0.96),
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('callParticipants'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${_participants.length} Active',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Active Participants List
                ..._participants.map((p) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: ModernAvatar(
                      name: p.isSelf ? 'You' : p.name,
                      radius: 18,
                      isVerified: true,
                    ),
                    title: Text(
                      p.isSelf ? '${context.tr('you')} (Caller)' : p.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      p.status == ParticipantCallStatus.connected
                          ? context.tr('connected')
                          : '${context.tr('calling')} (${p.ringingSeconds}s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.status == ParticipantCallStatus.connected
                            ? AppColors.primary
                            : (isDark ? Colors.amber : Colors.amber.shade800),
                      ),
                    ),
                    trailing: p.isSpeaking
                        ? const Icon(Icons.graphic_eq_rounded, color: AppColors.primary, size: 20)
                        : null,
                  );
                }),

                // Unanswered Participants (if any)
                if (_unansweredHistory.isNotEmpty) ...[
                  Divider(color: borderColor, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.phone_missed_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${context.tr('noAnswer')} (${_unansweredHistory.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._unansweredHistory.map((up) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: ModernAvatar(name: up.name, radius: 18),
                      title: Text(
                        up.name,
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                      subtitle: Text(
                        context.tr('noAnswer'),
                        style: const TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                      trailing: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _reinviteParticipant(up),
                        icon: const Icon(Icons.call_rounded, size: 14, color: Colors.black),
                        label: Text(
                          context.tr('callAgain'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                Divider(color: borderColor, height: 24),

                // Quick Add Contact Option
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    context.tr('addParticipant'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  onTap: () {
                    _showAddParticipantDialog(cardColor, textPrimary, textSecondary);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddParticipantDialog(Color cardColor, Color textPrimary, Color textSecondary) {
    Navigator.pop(context); // close bottom sheet

    showDialog(
      context: context,
      builder: (dialogCtx) {
        String searchQuery = '';
        List<dynamic> users = [];
        bool isLoading = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void loadUsers(String query) async {
              setDialogState(() => isLoading = true);
              try {
                final results = await ConversationService.instance.searchUsers(query.trim());
                if (context.mounted) {
                  setDialogState(() {
                    users = results.where((u) => !_participants.any((p) => p.name == u.username)).toList();
                    isLoading = false;
                  });
                }
              } catch (_) {
                if (context.mounted) {
                  setDialogState(() {
                    users = [];
                    isLoading = false;
                  });
                }
              }
            }

            // Initial load
            if (isLoading && users.isEmpty && searchQuery.isEmpty) {
              loadUsers('');
            }

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                context.tr('addParticipant'),
                style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari kontak...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: textPrimary.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        searchQuery = val;
                        loadUsers(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Tidak ada kontak ditemukan',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: users.length,
                          itemBuilder: (context, idx) {
                            final user = users[idx];
                            final name = user.username as String;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: ModernAvatar(name: name, radius: 18),
                              title: Text(name, style: TextStyle(color: textPrimary, fontSize: 14)),
                              subtitle: user.phoneNumber != null
                                  ? Text(user.phoneNumber, style: TextStyle(color: textSecondary, fontSize: 11))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.add_call, color: AppColors.primary),
                                onPressed: () {
                                  Navigator.pop(dialogCtx);
                                  _addContactToCall(name);
                                },
                              ),
                              onTap: () {
                                Navigator.pop(dialogCtx);
                                _addContactToCall(name);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(context.tr('cancel')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
