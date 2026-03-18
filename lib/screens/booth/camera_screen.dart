import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config.dart';
import '../../providers/app_state.dart';
import '../../services/camera_service.dart';
import '../../widgets/countdown_overlay.dart';
import '../../widgets/flash_overlay.dart';
import '../../widgets/overlay_painter.dart';
import '../../widgets/shutter_button.dart';
import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  bool _isInitializing = true;
  String? _error;

  // Countdown state
  bool _isCountingDown = false;
  int _currentCount = 0;
  Timer? _countdownTimer;
  bool _isTakingPicture = false;
  final GlobalKey<FlashOverlayState> _flashKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraService.initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _error = _cameraService.errorMessage;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraService.disposeCamera();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onShutter() {
    if (!_cameraService.isInitialized || _isCountingDown) return;
    final config = context.read<AppState>().eventConfig;
    if (config == null) return;

    setState(() {
      _isCountingDown = true;
      _currentCount = config.timerDuration;
      _isTakingPicture = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    // Take picture immediately
    final xfile = await _cameraService.takePicture();
    if (!mounted) return;
    if (xfile == null) {
      setState(() => _isCountingDown = false);
      return;
    }

    final config = context.read<AppState>().eventConfig;
    if (config == null || !mounted) return;

    // Navigate to preview with raw photo path immediately (Bug 3 fix)
    // The compositing will happen asynchronously in PreviewScreen
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          compositedPhotoPath: xfile.path,
          rawPhotoPath: xfile.path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppState>().eventConfig;

    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPink),
        ),
      );
    }

    if (_error != null || !_cameraService.isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Camera non disponible',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour',
                    style: TextStyle(color: AppColors.primaryPink)),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview with correct aspect ratio (Bug 2 fix)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),
          ),

          // Live overlay
          if (config != null)
            CustomPaint(painter: OverlayPainter(config: config)),

          // Back button (hidden during countdown)
          if (!_isCountingDown)
            Positioned(
              top: 48,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

          // Countdown overlay (Bug 6: integrated into camera screen)
          if (_isCountingDown) ...[
            CountdownOverlay(currentNumber: _currentCount),
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
          ],

          // Flash overlay
          FlashOverlay(
            key: _flashKey,
            onComplete: _onFlashComplete,
          ),

          // Bottom controls (hidden during countdown) - Bug 5: gallery button removed
          if (!_isCountingDown)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: ShutterButton(onPressed: _onShutter),
              ),
            ),
        ],
      ),
    );
  }
}
