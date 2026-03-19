import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

/// Full-screen crossfade slideshow of local photo files.
/// Shuffles order, flashes between transitions, pauses on long press.
/// Falls back to [fallback] when [photoPaths] is empty or files don't exist.
class SlideshowWidget extends StatefulWidget {
  final List<String> photoPaths;
  final Widget fallback;
  final Duration interval;

  const SlideshowWidget({
    super.key,
    required this.photoPaths,
    required this.fallback,
    this.interval = const Duration(seconds: 4),
  });

  @override
  State<SlideshowWidget> createState() => _SlideshowWidgetState();
}

class _SlideshowWidgetState extends State<SlideshowWidget> {
  int _currentIndex = 0;
  Timer? _timer;
  List<String> _validPaths = [];
  bool _flashing = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _filterAndShuffle();
    _startTimer();
  }

  @override
  void didUpdateWidget(SlideshowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPaths != widget.photoPaths) {
      _filterAndShuffle();
      _currentIndex = 0;
      _restartTimer();
    }
  }

  /// Filter valid paths and shuffle for random order.
  void _filterAndShuffle() {
    _validPaths = widget.photoPaths
        .where((p) => File(p).existsSync())
        .toList()
      ..shuffle(Random());
  }

  void _startTimer() {
    if (_validPaths.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || _paused) return;
      setState(() => _flashing = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % _validPaths.length;
          _flashing = false;
        });
      });
    });
  }

  void _restartTimer() {
    _timer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_validPaths.isEmpty) {
      return widget.fallback;
    }

    return GestureDetector(
      // Long press pauses the slideshow (like Instagram stories)
      onLongPressStart: (_) => setState(() => _paused = true),
      onLongPressEnd: (_) => setState(() => _paused = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.fallback,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _buildImage(_currentIndex),
          ),
          AnimatedOpacity(
            opacity: _flashing ? 0.8 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: Container(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(int index) {
    if (index >= _validPaths.length) return const SizedBox.shrink();
    final path = _validPaths[index];
    return SizedBox.expand(
      key: ValueKey(path),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
