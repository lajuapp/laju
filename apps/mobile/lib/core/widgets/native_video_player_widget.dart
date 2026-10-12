import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../network/api_client.dart';
import '../network/media_url_resolver.dart';
import '../services/laju_media_cache_manager.dart';

class NativeVideoPlayerController {
  MethodChannel? _channel;
  bool _isDisposed = false;

  void _attach(int viewId) {
    _isDisposed = false;
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

  Future<void> setSource(String source) async {
    if (_isDisposed || _channel == null) return;
    try {
      await _channel?.invokeMethod('setSource', {'url': source});
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
  bool _hasError = false;
  String? _errorMessage;
  int _durationMs = 0;
  String? _resolvedSourcePath;
  bool _isResolving = true;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialSyncResolution();
    _resolveVideoSource(widget.videoUrl);
    _startPrepareTimeout();
  }

  void _startPrepareTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && !_isPrepared && !_hasError) {
        setState(() {
          _isResolving = false;
          _hasError = true;
          _errorMessage = 'Waktu memuat video habis. Periksa koneksi internet Anda.';
        });
        widget.onError?.call('Timeout memuat video');
      }
    });
  }

  void _checkInitialSyncResolution() {
    final clean = resolveMediaUrl(widget.videoUrl).trim();
    if (clean.isEmpty) return;

    if (clean.startsWith('file://')) {
      try {
        final local = File(Uri.parse(clean).toFilePath());
        if (local.existsSync()) {
          _resolvedSourcePath = local.path;
          _isResolving = false;
          return;
        }
      } catch (_) {}
    } else if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('data:')) {
      final local = File(clean);
      if (local.existsSync()) {
        _resolvedSourcePath = local.path;
        _isResolving = false;
        return;
      }
    } else {
      final syncCached = LajuMediaCacheManager.instance.getCachedFileIfPresentSync(clean);
      if (syncCached != null && syncCached.existsSync() && syncCached.lengthSync() > 0) {
        _resolvedSourcePath = syncCached.path;
        _isResolving = false;
        return;
      }
    }
  }

  Future<void> _resolveVideoSource(String rawSource) async {
    final clean = resolveMediaUrl(rawSource).trim();
    if (clean.isEmpty) {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _hasError = true;
          _isPrepared = true;
          _errorMessage = 'Sumber video tidak ditemukan';
        });
      }
      return;
    }

    // 1. Check local file or file://
    if (clean.startsWith('file://')) {
      try {
        final local = File(Uri.parse(clean).toFilePath());
        if (local.existsSync()) {
          _setResolved(local.path);
          return;
        }
      } catch (_) {}
    } else if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('data:')) {
      final local = File(clean);
      if (local.existsSync()) {
        _setResolved(local.path);
        return;
      }
    }

    // 2. Check base64 data URI
    if (clean.startsWith('data:')) {
      try {
        final commaIdx = clean.indexOf(',');
        final b64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(b64);
        final key = LajuMediaCacheManager.instance.getCacheKey(clean);
        final cached = await LajuMediaCacheManager.instance.putBytes(key, bytes, ext: '.mp4');
        if (cached != null && cached.existsSync()) {
          _setResolved(cached.path);
          return;
        }
      } catch (e) {
        debugPrint('[NativeVideoPlayer] Base64 write error: $e');
      }
    }

    // 3. Check synchronous cache in LajuMediaCacheManager
    final syncCached = LajuMediaCacheManager.instance.getCachedFileIfPresentSync(clean);
    if (syncCached != null && syncCached.existsSync() && syncCached.lengthSync() > 0) {
      _setResolved(syncCached.path);
      return;
    }

    // 4. Download and cache to disk to bypass Android VideoView HTTP streaming issues
    try {
      final cachedFile = await LajuMediaCacheManager.instance.getSingleFile(
        clean,
        timeout: const Duration(seconds: 15),
      );
      if (cachedFile != null && cachedFile.existsSync() && cachedFile.lengthSync() > 0) {
        _setResolved(cachedFile.path);
        return;
      }
    } catch (e) {
      debugPrint('[NativeVideoPlayer] Media cache fetch failed: $e');
    }

    // 5. Fallback: pass clean URL directly
    _setResolved(clean);
  }

  void _setResolved(String path) {
    if (!mounted) return;
    setState(() {
      _resolvedSourcePath = path;
      _isResolving = false;
    });
    if (_viewId != null && _channel != null) {
      _channel?.invokeMethod('setSource', {
        'url': path,
        'token': ApiClient.instance.authToken,
      });
    }
  }

  @override
  void didUpdateWidget(covariant NativeVideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      widget.controller?.setMuted(widget.muted);
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      setState(() {
        _isPrepared = false;
        _hasError = false;
        _errorMessage = null;
        _isResolving = true;
      });
      _startPrepareTimeout();
      _checkInitialSyncResolution();
      _resolveVideoSource(widget.videoUrl);
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
          _timeoutTimer?.cancel();
          final args = call.arguments as Map?;
          final d = (args?['durationMs'] as num?)?.toInt() ?? 0;
          setState(() {
            _isPrepared = true;
            _hasError = false;
            _durationMs = d;
          });
          widget.onPrepared?.call(d);
          break;
        case 'onCompleted':
          widget.onCompleted?.call();
          break;
        case 'onError':
          _timeoutTimer?.cancel();
          final err = call.arguments?.toString() ?? 'Playback error';
          setState(() {
            _isPrepared = true; // Dismiss infinite spinner on error
            _hasError = true;
            _errorMessage = err;
          });
          widget.onError?.call(err);
          break;
      }
    });

    // Send source after handler is ready
    final targetPath = _resolvedSourcePath ?? widget.videoUrl;
    if (targetPath.isNotEmpty) {
      _channel?.invokeMethod('setSource', {
        'url': targetPath,
        'token': ApiClient.instance.authToken,
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    try {
      _channel?.invokeMethod('pause');
    } catch (_) {}
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
          if (_resolvedSourcePath != null)
            AndroidView(
              key: ValueKey('android_video_${_resolvedSourcePath!}'),
              viewType: 'com.laju/native_video_view',
              layoutDirection: TextDirection.ltr,
              creationParams: {
                'url': _resolvedSourcePath,
                'autoPlay': widget.autoPlay,
                'loop': widget.loop,
                'muted': widget.muted,
                'token': ApiClient.instance.authToken,
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            ),
          if ((!_isPrepared || _isResolving) && !_hasError)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          if (_hasError)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44, color: Colors.white70),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? 'Gagal memutar video',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isPrepared = false;
                          _isResolving = true;
                        });
                        _resolveVideoSource(widget.videoUrl);
                      },
                    ),
                  ],
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
