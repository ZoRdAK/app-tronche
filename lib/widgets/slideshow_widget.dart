import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../config.dart';

/// Full-screen crossfade slideshow of local photo files.
/// Falls back to [fallback] when [photoPaths] is empty.
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

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(SlideshowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPaths != widget.photoPaths) {
      _currentIndex = 0;
      _restartTimer();
    }
  }

  void _startTimer() {
    if (widget.photoPaths.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.photoPaths.length;
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
    if (widget.photoPaths.isEmpty) {
      return widget.fallback;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildImage(_currentIndex),
    );
  }

  Widget _buildImage(int index) {
    if (index >= widget.photoPaths.length) return widget.fallback;
    final path = widget.photoPaths[index];
    return SizedBox.expand(
      key: ValueKey(path),
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: AppColors.background),
      ),
    );
  }
}
