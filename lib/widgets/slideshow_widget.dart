import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Full-screen crossfade slideshow of local photo files.
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

  @override
  void initState() {
    super.initState();
    _filterValidPaths();
    _startTimer();
  }

  @override
  void didUpdateWidget(SlideshowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPaths != widget.photoPaths) {
      _filterValidPaths();
      _currentIndex = 0;
      _restartTimer();
    }
  }

  /// Only keep paths where the file actually exists on disk.
  void _filterValidPaths() {
    _validPaths = widget.photoPaths
        .where((p) => File(p).existsSync())
        .toList();
  }

  void _startTimer() {
    if (_validPaths.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _validPaths.length;
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm fallback behind in case image takes time to load
        widget.fallback,
        // Photo on top
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildImage(_currentIndex),
        ),
      ],
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
