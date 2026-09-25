import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/core.dart';
import 'status_view_screen.dart';

class TextStatusComposerScreen extends StatefulWidget {
  const TextStatusComposerScreen({super.key});

  @override
  State<TextStatusComposerScreen> createState() => _TextStatusComposerScreenState();
}

class _TextStatusComposerScreenState extends State<TextStatusComposerScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<Color> _palette = const [
    Color(0xFF005C4B), // LAJU Dark Teal
    Color(0xFF1E3A8A), // Tactical Navy
    Color(0xFF581C87), // Deep Purple
    Color(0xFF831843), // Crimson Berry
    Color(0xFF7C2D12), // Amber Rust
    Color(0xFF064E3B), // Dark Emerald
    Color(0xFF0F172A), // Midnight Carbon
  ];

  final List<String> _fontFamilies = ['sans-serif', 'serif', 'monospace'];
  int _colorIndex = 0;
  int _fontIndex = 0;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cycleColor() {
    HapticFeedback.lightImpact();
    setState(() {
      _colorIndex = (_colorIndex + 1) % _palette.length;
    });
  }

  void _cycleFont() {
    HapticFeedback.lightImpact();
    setState(() {
      _fontIndex = (_fontIndex + 1) % _fontFamilies.length;
    });
  }

  TextStyle _getCurrentTextStyle() {
    final family = _fontFamilies[_fontIndex];
    switch (family) {
      case 'serif':
        return const TextStyle(
          fontFamily: 'serif',
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.35,
        );
      case 'monospace':
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.35,
        );
      case 'sans-serif':
      default:
        return const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
        );
    }
  }

  void _publishStatus() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final story = StatusStoryItem(
      text: text,
      time: 'Just now',
      backgroundColor: _palette[_colorIndex],
    );

    Navigator.pop(context, story);
  }

  @override
  Widget build(BuildContext context) {
    final activeBg = _palette[_colorIndex];

    return Scaffold(
      backgroundColor: activeBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Control Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Batal',
                  ),
                  const Spacer(),

                  // Font style switcher
                  IconButton(
                    icon: const Icon(Icons.title_rounded, color: Colors.white, size: 26),
                    onPressed: _cycleFont,
                    tooltip: 'Ganti Font',
                  ),

                  // Color palette switcher
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, color: Colors.white, size: 26),
                    onPressed: _cycleColor,
                    tooltip: 'Ganti Warna Latar',
                  ),
                ],
              ),
            ),

            // Center Text Input Area
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: _getCurrentTextStyle(),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: 'Ketik status terenkripsi...',
                      hintStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  // Privacy Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Status (Kontak Saya)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Send FAB Button
                  AnimatedScale(
                    scale: _hasText ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 200),
                    child: FloatingActionButton(
                      mini: false,
                      heroTag: 'fab_send_text_status',
                      backgroundColor: _hasText ? AppColors.primary : Colors.white24,
                      onPressed: _hasText ? _publishStatus : null,
                      elevation: _hasText ? 4 : 0,
                      child: Icon(
                        Icons.send_rounded,
                        color: _hasText ? Colors.black : Colors.white54,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
