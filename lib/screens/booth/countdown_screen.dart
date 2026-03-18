import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/camera_service.dart';
import '../../services/overlay_service.dart';
import '../../widgets/countdown_overlay.dart';
import '../../widgets/flash_overlay.dart';
import 'preview_screen.dart';

class CountdownScreen extends StatefulWidget {
  final CameraService cameraService;

  const CountdownScreen({super.key, required this.cameraService});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  late int _currentCount;
  Timer? _timer;
  bool _isTakingPicture = false;
  final GlobalKey<FlashOverlayState> _flashKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().eventConfig;
    _currentCount = config?.timerDuration ?? 3;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentCount <= 1) {
        timer.cancel();
        _triggerCapture();
      } else {
        setState(() => _currentCount--);
      }
    });
  }

  Future<void> _triggerCapture() async {
    if (_isTakingPicture) return;
    _isTakingPicture = true;

    // Flash effect
    _flashKey.currentState?.trigger();
  }

  Future<void> _onFlashComplete() async {
    final xfile = await widget.cameraService.takePicture();
    if (!mounted) return;
    if (xfile == null) {
      Navigator.of(context).pop();
      return;
    }

    final config = context.read<AppState>().eventConfig;
    if (config == null || !mounted) return;

    // Composite overlay
    final overlayService = OverlayService();
    final addWatermark = config.plan == 'free';
    String compositedPath;
    try {
      compositedPath = await overlayService.compositePhoto(
        xfile.path,
        config,
        addWatermark,
      );
    } catch (_) {
      compositedPath = xfile.path;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(compositedPhotoPath: compositedPath),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (Bug 2 fix: correct aspect ratio)
          if (widget.cameraService.isInitialized &&
              widget.cameraService.controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: widget.cameraService.controller!.value.previewSize!.height,
                  height: widget.cameraService.controller!.value.previewSize!.width,
                  child: CameraPreview(widget.cameraService.controller!),
                ),
              ),
            ),

          // Countdown number
          CountdownOverlay(currentNumber: _currentCount),

          // "Souriez !" text at bottom
          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'Souriez !',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Flash overlay — sits on top of everything
          FlashOverlay(
            key: _flashKey,
            onComplete: _onFlashComplete,
          ),
        ],
      ),
    );
  }
}
