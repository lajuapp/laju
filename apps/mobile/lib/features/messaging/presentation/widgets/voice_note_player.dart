import 'package:flutter/material.dart';
import '../../../../core/services/voice_note_service.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String filePath;
  final String durationLabel;
  final bool isOutgoing;
  final bool isDark;

  const VoiceNotePlayer({
    super.key,
    required this.filePath,
    required this.durationLabel,
    required this.isOutgoing,
    required this.isDark,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  String? _resolvedDuration;

  @override
  void initState() {
    super.initState();
    _checkDuration();
  }

  @override
  void didUpdateWidget(VoiceNotePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.durationLabel != widget.durationLabel) {
      _checkDuration();
    }
  }

  void _checkDuration() {
    final label = widget.durationLabel.trim();
    if (label.isNotEmpty && label != '0:00' && label != '0:15') {
      _resolvedDuration = label;
      return;
    }
    // Asynchronously resolve real duration from media metadata if missing
    VoiceNoteService.instance.getAudioDuration(widget.filePath).then((durMs) {
      if (mounted && durMs > 0) {
        setState(() {
          _resolvedDuration = VoiceNoteService.instance.formatDurationMs(durMs);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: VoiceNoteService.instance.playbackState,
      builder: (context, state, _) {
        final isCurrent = state.filePath == widget.filePath;
        final isPlaying = isCurrent && state.isPlaying;
        final progress = isCurrent ? state.progress : 0.0;

        final effectiveDuration = (isCurrent && state.durationMs > 0)
            ? state.formattedDuration
            : (_resolvedDuration ??
                (widget.durationLabel.isNotEmpty && widget.durationLabel != '0:15'
                    ? widget.durationLabel
                    : '0:00'));

        final timeDisplay = isPlaying
            ? '${state.formattedPosition} / $effectiveDuration'
            : (isCurrent && state.positionMs > 0
                ? '${state.formattedPosition} / $effectiveDuration'
                : effectiveDuration);

        final playButtonBg = widget.isOutgoing
            ? Colors.white.withValues(alpha: 0.25)
            : (widget.isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primaryLight);
        final playIconColor = widget.isOutgoing
            ? Colors.white
            : (widget.isDark ? AppColors.primaryLight : AppColors.primaryDark);

        final playedBarColor = widget.isOutgoing
            ? Colors.white
            : (widget.isDark ? AppColors.primaryLight : AppColors.primaryDark);
        final unplayedBarColor = widget.isOutgoing
            ? Colors.white.withValues(alpha: 0.40)
            : (widget.isDark ? Colors.white24 : const Color(0xFFCBD5E1));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: widget.isOutgoing
                ? Colors.black.withValues(alpha: 0.15)
                : (widget.isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isOutgoing
                  ? Colors.white.withValues(alpha: 0.15)
                  : (widget.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Play / Pause Circle Button
                  GestureDetector(
                    onTap: () {
                      VoiceNoteService.instance.togglePlay(widget.filePath);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: playButtonBg,
                        shape: BoxShape.circle,
                        boxShadow: isPlaying
                            ? [
                                BoxShadow(
                                  color: playIconColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: playIconColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Waveform and progress representation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dynamic Waveform Bars
                        _buildWaveformBars(progress, playedBarColor, unplayedBarColor),
                        const SizedBox(height: 6),

                        // Time position & lock indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeDisplay,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: widget.isOutgoing
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 10,
                                  color: widget.isOutgoing
                                      ? Colors.white70
                                      : (widget.isDark ? AppColors.primaryLight : AppColors.primaryDark),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Voice Note',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: widget.isOutgoing
                                        ? Colors.white70
                                        : (widget.isDark ? AppColors.primaryLight : AppColors.primaryDark),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaveformBars(double progress, Color playedColor, Color unplayedColor) {
    // Simulated waveform bar heights pattern
    const barHeights = [
      8.0, 14.0, 20.0, 12.0, 24.0, 18.0, 28.0, 16.0,
      22.0, 26.0, 14.0, 20.0, 24.0, 16.0, 12.0, 26.0,
      18.0, 22.0, 10.0, 16.0, 24.0, 18.0, 14.0, 8.0,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalBars = barHeights.length;
        final playedCount = (progress * totalBars).round();

        return SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(totalBars, (index) {
              final isPlayed = index < playedCount;
              return Container(
                width: 3.0,
                height: barHeights[index],
                decoration: BoxDecoration(
                  color: isPlayed ? playedColor : unplayedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
