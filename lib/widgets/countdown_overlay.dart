import 'package:flutter/material.dart';
import '../config.dart';

/// Animated countdown overlay widget.
/// Each number scales in from 1.5x → 1.0x with a fade, matching the spec.
class CountdownOverlay extends StatefulWidget {
  final int currentNumber;

  const CountdownOverlay({super.key, required this.currentNumber});

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late int _displayedNumber;

  @override
  void initState() {
    super.initState();
    _displayedNumber = widget.currentNumber;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountdownOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentNumber != widget.currentNumber) {
      _displayedNumber = widget.currentNumber;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Center(
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Text(
                '$_displayedNumber',
                style: const TextStyle(
                  fontSize: 140,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(blurRadius: 60, color: AppColors.primaryPink),
                    Shadow(blurRadius: 30, color: AppColors.orange),
                    Shadow(blurRadius: 10, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
