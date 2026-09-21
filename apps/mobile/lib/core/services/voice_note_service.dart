import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoiceRecordResult {
  final String filePath;
  final int durationMs;
  final int fileSize;

  const VoiceRecordResult({
    required this.filePath,
    required this.durationMs,
    required this.fileSize,
  });

  int get durationSeconds => (durationMs / 1000).ceil();

  String get formattedDuration {
    final totalSec = durationSeconds;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PlaybackState {
  final String? filePath;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;

  const PlaybackState({
    this.filePath,
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 0,
  });

  double get progress => durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  String get formattedPosition {
    final s = (positionMs / 1000).floor();
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final s = (durationMs / 1000).ceil();
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}

class VoiceNoteService {
  VoiceNoteService._() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static final VoiceNoteService instance = VoiceNoteService._();
  static const MethodChannel _channel = MethodChannel('com.laju/voice_note');

  final ValueNotifier<PlaybackState> playbackState = ValueNotifier(const PlaybackState());
  Timer? _positionPollTimer;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onPlaybackCompleted') {
      _stopPollTimer();
      final current = playbackState.value;
      playbackState.value = PlaybackState(
        filePath: current.filePath,
        isPlaying: false,
        positionMs: 0,
        durationMs: current.durationMs,
      );
    }
  }

  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasRecordPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestRecordPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      // Stop any existing playback first
      await stop();

      final res = await _channel.invokeMethod<String>('startRecording');
      _isRecording = res != null;
      return res;
    } catch (e) {
      _isRecording = false;
      debugPrint('Error starting voice recording: $e');
      return null;
    }
  }

  Future<VoiceRecordResult?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('stopRecording');
      if (res != null && res['path'] != null) {
        final path = res['path'] as String;
        final durationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
        final fileSize = (res['fileSize'] as num?)?.toInt() ?? 0;
        return VoiceRecordResult(
          filePath: path,
          durationMs: durationMs,
          fileSize: fileSize,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error stopping voice recording: $e');
      return null;
    }
  }

  Future<bool> cancelRecording() async {
    _isRecording = false;
    try {
      final res = await _channel.invokeMethod<bool>('cancelRecording');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> play(String filePath) async {
    try {
      String actualPath = filePath;
      if (filePath.startsWith('data:audio')) {
        try {
          final b64 = filePath.split(',').last;
          final bytes = base64Decode(b64);
          final tempFile = File('${Directory.systemTemp.path}/vn_${filePath.hashCode}.m4a');
          if (!tempFile.existsSync()) {
            tempFile.writeAsBytesSync(bytes);
          }
          actualPath = tempFile.path;
        } catch (e) {
          debugPrint('Error decoding base64 voice note: $e');
        }
      }

      final res = await _channel.invokeMapMethod<String, dynamic>('playAudio', {
        'filePath': actualPath,
      });
      if (res != null) {
        final durationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
        final positionMs = (res['positionMs'] as num?)?.toInt() ?? 0;
        playbackState.value = PlaybackState(
          filePath: filePath,
          isPlaying: true,
          positionMs: positionMs,
          durationMs: durationMs,
        );
        _startPollTimer();
      }
    } catch (e) {
      debugPrint('Error playing voice note: $e');
      playbackState.value = const PlaybackState();
    }
  }

  Future<void> pause() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('pauseAudio');
      _stopPollTimer();
      final current = playbackState.value;
      final pos = (res?['positionMs'] as num?)?.toInt() ?? current.positionMs;
      playbackState.value = PlaybackState(
        filePath: current.filePath,
        isPlaying: false,
        positionMs: pos,
        durationMs: current.durationMs,
      );
    } catch (e) {
      debugPrint('Error pausing voice note: $e');
    }
  }

  Future<void> stop() async {
    _stopPollTimer();
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
    playbackState.value = const PlaybackState();
  }

  Future<void> togglePlay(String filePath) async {
    final current = playbackState.value;
    if (current.filePath == filePath && current.isPlaying) {
      await pause();
    } else {
      await play(filePath);
    }
  }

  Future<void> seek(int positionMs) async {
    try {
      await _channel.invokeMethod('seekAudio', {'positionMs': positionMs});
      final current = playbackState.value;
      playbackState.value = PlaybackState(
        filePath: current.filePath,
        isPlaying: current.isPlaying,
        positionMs: positionMs,
        durationMs: current.durationMs,
      );
    } catch (_) {}
  }

  void _startPollTimer() {
    _stopPollTimer();
    _positionPollTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('getPlaybackStatus');
        if (res != null) {
          final isPlaying = res['isPlaying'] as bool? ?? false;
          final pos = (res['positionMs'] as num?)?.toInt() ?? 0;
          final dur = (res['durationMs'] as num?)?.toInt() ?? 0;
          final path = res['filePath'] as String?;

          playbackState.value = PlaybackState(
            filePath: path,
            isPlaying: isPlaying,
            positionMs: pos,
            durationMs: dur,
          );

          if (!isPlaying && (dur > 0 && pos >= dur - 200)) {
            _stopPollTimer();
            playbackState.value = PlaybackState(
              filePath: path,
              isPlaying: false,
              positionMs: 0,
              durationMs: dur,
            );
          }
        }
      } catch (_) {}
    });
  }

  void _stopPollTimer() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
  }
}
