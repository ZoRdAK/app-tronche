import 'package:flutter/material.dart';

/// Full-screen white flash that animates: 0 → 1 → 0 over 300ms.
/// Call [trigger] to start the animation, then [onComplete] is called.
class FlashOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const FlashOverlay({super.key, required this.onComplete});

  @override
  State<FlashOverlay> createState() => FlashOverlayState();
}

class FlashOverlayState extends State<FlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // 0 → 1 (first half) → 0 (second half)
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  void trigger() {
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => IgnorePointer(
        child: Opacity(
          opacity: _opacity.value,
          child: const ColoredBox(
            color: Colors.white,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
