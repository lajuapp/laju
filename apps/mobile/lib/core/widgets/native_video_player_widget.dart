import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class NativeVideoPlayerController {
  MethodChannel? _channel;
  bool _isDisposed = false;

  void _attach(int viewId) {
    _channel = MethodChannel('com.laju/native_video_view_$viewId');
  }

  void _detach() {
    _isDisposed = true;
    _channel = null;
  }

  Future<void> play() async {
    if (_isDisposed || _channel == null) return;
    try {
      await _channel?.invokeMethod('play');
    } catch (_) {}
  }

  Future<void> pause() async {
    if (_isDisposed || _channel == null) return;
    try {
      await _channel?.invokeMethod('pause');
    } catch (_) {}
  }

  Future<void> seekTo(int positionMs) async {
    if (_isDisposed || _channel == null) return;
    try {
      await _channel?.invokeMethod('seekTo', {'positionMs': positionMs});
    } catch (_) {}
  }

  Future<void> setMuted(bool muted) async {
    if (_isDisposed || _channel == null) return;
    try {
      await _channel?.invokeMethod('setMuted', {'muted': muted});
    } catch (_) {}
  }
}

class NativeVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool loop;
  final bool muted;
  final NativeVideoPlayerController? controller;
  final void Function(int durationMs)? onPrepared;
  final VoidCallback? onCompleted;
  final void Function(String error)? onError;

  const NativeVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.loop = false,
    this.muted = false,
    this.controller,
    this.onPrepared,
    this.onCompleted,
    this.onError,
  });

  @override
  State<NativeVideoPlayerWidget> createState() => _NativeVideoPlayerWidgetState();
}

class _NativeVideoPlayerWidgetState extends State<NativeVideoPlayerWidget> {
  int? _viewId;
  MethodChannel? _channel;
  bool _isPrepared = false;
  int _durationMs = 0;

  @override
  void didUpdateWidget(covariant NativeVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      widget.controller?.setMuted(widget.muted);
    }
  }

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    _channel = MethodChannel('com.laju/native_video_view_$id');
    widget.controller?._attach(id);

    _channel?.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onPrepared':
          final args = call.arguments as Map?;
          final d = (args?['durationMs'] as num?)?.toInt() ?? 0;
          setState(() {
            _isPrepared = true;
            _durationMs = d;
          });
          widget.onPrepared?.call(d);
          break;
        case 'onCompleted':
          widget.onCompleted?.call();
          break;
        case 'onError':
          final err = call.arguments?.toString() ?? 'Playback error';
          widget.onError?.call(err);
          break;
      }
    });
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AndroidView(
            viewType: 'com.laju/native_video_view',
            layoutDirection: TextDirection.ltr,
            creationParams: {
              'url': widget.videoUrl,
              'autoPlay': widget.autoPlay,
              'loop': widget.loop,
              'muted': widget.muted,
            },
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          ),
          if (!_isPrepared)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
        ],
      );
    }

    // Fallback placeholder for non-Android platforms
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_rounded, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'Video Status (${(_durationMs / 1000).toStringAsFixed(1)}s)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
