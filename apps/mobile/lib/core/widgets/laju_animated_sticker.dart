import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../network/media_url_resolver.dart';
import '../theme/app_colors.dart';
import '../services/laju_media_cache_manager.dart';
import 'laju_cached_image.dart';

// ─── APNG MODELS & PARSER ──────────────────────────────────────────

class _PngChunk {
  final String type;
  final Uint8List data;
  _PngChunk(this.type, this.data);
}

class ApngFrame {
  final Uint8List pngBytes;
  final Duration duration;
  final int width;
  final int height;

  ApngFrame({
    required this.pngBytes,
    required this.duration,
    required this.width,
    required this.height,
  });
}

class ApngAnimation {
  final List<ApngFrame> frames;
  final int numPlays;

  ApngAnimation({required this.frames, this.numPlays = 0});
}

class LajuApngDecoder {
  static const List<int> _pngSignature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

  // CRC32 table
  static final List<int> _crcTable = List<int>.generate(256, (n) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xedb88320 ^ (c >>> 1);
      } else {
        c = c >>> 1;
      }
    }
    return c;
  });

  static int _crc32(Uint8List buf, int offset, int length) {
    int c = 0xffffffff;
    for (int i = 0; i < length; i++) {
      c = _crcTable[(c ^ buf[offset + i]) & 0xff] ^ (c >>> 8);
    }
    return (c ^ 0xffffffff) >>> 0;
  }

  static Uint8List _createChunk(String type, Uint8List data) {
    final len = data.length;
    final chunk = Uint8List(12 + len);
    final bd = ByteData.sublistView(chunk);
    bd.setUint32(0, len);
    chunk[4] = type.codeUnitAt(0);
    chunk[5] = type.codeUnitAt(1);
    chunk[6] = type.codeUnitAt(2);
    chunk[7] = type.codeUnitAt(3);
    chunk.setRange(8, 8 + len, data);
    final crc = _crc32(chunk, 4, 4 + len);
    bd.setUint32(8 + len, crc);
    return chunk;
  }

  // LRU In-Memory Cache (Stores up to 50 decoded animations for instant recall)
  static final Map<String, ApngAnimation?> _memoryCache = {};
  static final List<String> _cacheKeys = [];
  static const int _maxCacheSize = 50;

  static bool isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  static ApngAnimation? decode(Uint8List bytes, {String? cacheKey}) {
    if (cacheKey != null && _memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    if (!isPng(bytes)) return null;

    final bd = ByteData.sublistView(bytes);
    int pos = 8;
    final List<_PngChunk> chunks = [];

    while (pos + 8 <= bytes.length) {
      final len = bd.getUint32(pos);
      if (pos + 12 + len > bytes.length) break;

      final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
      final data = bytes.sublist(pos + 8, pos + 8 + len);
      chunks.add(_PngChunk(type, data));
      pos += 12 + len;
    }

    final actl = chunks.where((c) => c.type == 'acTL').toList();
    if (actl.isEmpty) {
      // Standard static PNG
      if (cacheKey != null) _putCache(cacheKey, null);
      return null;
    }

    final actlData = ByteData.sublistView(actl.first.data);
    final numPlays = actlData.getUint32(4);

    final ihdrChunk = chunks.firstWhere((c) => c.type == 'IHDR', orElse: () => _PngChunk('', Uint8List(0)));
    if (ihdrChunk.data.isEmpty) return null;

    final ancillary = chunks.where((c) =>
      c.type == 'PLTE' || c.type == 'tRNS' || c.type == 'sRGB' ||
      c.type == 'gAMA' || c.type == 'iCCP' || c.type == 'cHRM'
    ).toList();

    final List<ApngFrame> frames = [];

    int currentFrameWidth = 0;
    int currentFrameHeight = 0;
    int delayNum = 1;
    int delayDen = 10;
    List<Uint8List> currentFrameIdatData = [];

    void emitFrame() {
      if (currentFrameIdatData.isEmpty) return;

      final List<Uint8List> frameChunks = [
        Uint8List.fromList(_pngSignature),
        _createChunk('IHDR', ihdrChunk.data),
        ...ancillary.map((c) => _createChunk(c.type, c.data)),
        ...currentFrameIdatData.map((d) => _createChunk('IDAT', d)),
        _createChunk('IEND', Uint8List(0)),
      ];

      final totalLen = frameChunks.fold<int>(0, (sum, c) => sum + c.length);
      final assembled = Uint8List(totalLen);
      int writeOffset = 0;
      for (final c in frameChunks) {
        assembled.setRange(writeOffset, writeOffset + c.length, c);
        writeOffset += c.length;
      }

      int delayMs = (delayNum * 1000 / (delayDen == 0 ? 100 : delayDen)).round();
      if (delayMs <= 10) delayMs = 100;

      frames.add(ApngFrame(
        pngBytes: assembled,
        duration: Duration(milliseconds: delayMs),
        width: currentFrameWidth,
        height: currentFrameHeight,
      ));

      currentFrameIdatData = [];
    }

    for (final c in chunks) {
      if (c.type == 'fcTL') {
        emitFrame();
        final fctlBd = ByteData.sublistView(c.data);
        currentFrameWidth = fctlBd.getUint32(4);
        currentFrameHeight = fctlBd.getUint32(8);
        delayNum = fctlBd.getUint16(20);
        delayDen = fctlBd.getUint16(22);
      } else if (c.type == 'IDAT') {
        currentFrameIdatData.add(c.data);
      } else if (c.type == 'fdAT') {
        if (c.data.length > 4) {
          currentFrameIdatData.add(c.data.sublist(4)); // Strip sequence number
        }
      } else if (c.type == 'IEND') {
        emitFrame();
      }
    }

    final anim = frames.isNotEmpty ? ApngAnimation(frames: frames, numPlays: numPlays) : null;
    if (cacheKey != null) _putCache(cacheKey, anim);
    return anim;
  }

  static void _putCache(String key, ApngAnimation? value) {
    if (_cacheKeys.length >= _maxCacheSize) {
      final oldest = _cacheKeys.removeAt(0);
      _memoryCache.remove(oldest);
    }
    _memoryCache[key] = value;
    _cacheKeys.add(key);
  }
}

// ─── LAJU ANIMATED STICKER WIDGET ──────────────────────────────────

class LajuAnimatedSticker extends StatefulWidget {
  final String pathOrUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? fallback;

  const LajuAnimatedSticker({
    super.key,
    required this.pathOrUrl,
    this.width = 145,
    this.height = 145,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  @override
  State<LajuAnimatedSticker> createState() => _LajuAnimatedStickerState();
}

class _LajuAnimatedStickerState extends State<LajuAnimatedSticker> {
  ApngAnimation? _apngAnimation;
  int _currentFrameIdx = 0;
  Timer? _frameTimer;
  bool _isLoading = false;
  bool _hasError = false;
  Uint8List? _rawBytes;

  @override
  void initState() {
    super.initState();
    _loadStickerData();
  }

  @override
  void didUpdateWidget(covariant LajuAnimatedSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pathOrUrl != widget.pathOrUrl) {
      _stopTimer();
      _loadStickerData();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _stopTimer() {
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  bool get _isNativeAnimated {
    final lower = widget.pathOrUrl.toLowerCase();
    return lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  Future<void> _loadStickerData() async {
    final src = widget.pathOrUrl;
    if (src.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    // 1. If it's WebP or GIF, Flutter's Image widget handles it natively at 60fps!
    if (_isNativeAnimated) {
      return;
    }

    // 2. For PNG or APNG, load bytes and parse APNG frames
    setState(() {
      _isLoading = true;
      _hasError = false;
      _apngAnimation = null;
      _currentFrameIdx = 0;
    });

    try {
      Uint8List? bytes;

      if (src.startsWith('assets/')) {
        final bundle = DefaultAssetBundle.of(context);
        final data = await bundle.load(src);
        bytes = data.buffer.asUint8List();
      } else if (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('/') || src.startsWith('admin/media')) {
        bytes = await LajuMediaCacheManager.instance.getBytes(src);
      } else if (File(src).existsSync()) {
        bytes = await File(src).readAsBytes();
      } else if (src.startsWith('data:image')) {
        final b64 = src.split(',').last;
        bytes = base64Decode(b64);
      }

      if (bytes != null && mounted) {
        _rawBytes = bytes;
        final decoded = LajuApngDecoder.decode(bytes, cacheKey: src);

        if (decoded != null && decoded.frames.length > 1) {
          _apngAnimation = decoded;
          _startAnimation();
        }

        setState(() {
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _startAnimation() {
    _stopTimer();
    if (_apngAnimation == null || _apngAnimation!.frames.isEmpty) return;

    final currentFrame = _apngAnimation!.frames[_currentFrameIdx];
    _frameTimer = Timer(currentFrame.duration, () {
      if (!mounted || _apngAnimation == null) return;
      setState(() {
        _currentFrameIdx = (_currentFrameIdx + 1) % _apngAnimation!.frames.length;
      });
      _startAnimation();
    });
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.fallback != null) return widget.fallback!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          Icons.sticky_note_2_outlined,
          size: (widget.width != null && widget.width! < 60) ? 20 : 32,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.pathOrUrl;

    if (_hasError) {
      return _buildFallback(context);
    }

    if (_isLoading && !_isNativeAnimated) {
      return _buildFallback(context);
    }

    // A. Native Animated Formats (WebP / GIF) -> 60fps Native Hardware Acceleration
    if (_isNativeAnimated) {
      if (src.startsWith('assets/')) {
        return Image.asset(
          src,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _buildFallback(context),
        );
      } else if (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('/') || src.startsWith('admin/media')) {
        return LajuCachedImage(
          imageUrlOrPath: src,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: widget.width != null ? (widget.width! * 2).toInt() : 256,
          cacheHeight: widget.height != null ? (widget.height! * 2).toInt() : 256,
          placeholder: _buildFallback(context),
          errorWidget: _buildFallback(context),
        );
      } else if (File(src).existsSync()) {
        return Image.file(
          File(src),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, __, ___) => _buildFallback(context),
        );
      }
    }

    // B. APNG Animated Multi-Frame Player
    if (_apngAnimation != null && _apngAnimation!.frames.isNotEmpty) {
      final activeFrame = _apngAnimation!.frames[_currentFrameIdx];
      return Image.memory(
        activeFrame.pngBytes,
        key: ValueKey('apng_frame_$_currentFrameIdx'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }

    // C. Static PNG Fallback from Bytes
    if (_rawBytes != null) {
      return Image.memory(
        _rawBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }

    // D. Loading Placeholder or Standard Network/Asset fallback
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }

    if (src.startsWith('http://') || src.startsWith('https://') || src.startsWith('/') || src.startsWith('admin/media')) {
      return LajuCachedImage(
        imageUrlOrPath: src,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.width != null ? (widget.width! * 2).toInt() : 256,
        cacheHeight: widget.height != null ? (widget.height! * 2).toInt() : 256,
        placeholder: _buildFallback(context),
        errorWidget: _buildFallback(context),
      );
    }

    return _buildFallback(context);
  }
}
