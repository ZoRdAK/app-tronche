import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config.dart';
import '../../providers/app_state.dart';
import '../../services/camera_service.dart';
import '../../services/gif_service.dart';
import '../../widgets/countdown_overlay.dart';
import '../../widgets/flash_overlay.dart';
import '../../widgets/overlay_painter.dart';
import '../../widgets/shutter_button.dart';
import 'preview_screen.dart';

enum _CaptureMode { photo, gif }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  bool _isInitializing = true;
  String? _error;

  // Capture mode
  _CaptureMode _captureMode = _CaptureMode.photo;

  // Countdown state
  bool _isCountingDown = false;
  int _currentCount = 0;
  Timer? _countdownTimer;
  bool _isTakingPicture = false;
  final GlobalKey<FlashOverlayState> _flashKey = GlobalKey();

  // GIF capture state
  bool _isCapturingGif = false;
  int _gifFramesCaptured = 0;
  static const int _gifFrameCount = 4;
  bool _isAssemblingGif = false;

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
        if (_captureMode == _CaptureMode.gif) {
          _triggerGifCapture();
        } else {
          _triggerCapture();
        }
      } else {
        setState(() => _currentCount--);
      }
    });
  }

  // ── Photo capture ──────────────────────────────────────────────────────────

  Future<void> _triggerCapture() async {
    if (_isTakingPicture) return;
    _isTakingPicture = true;
    _flashKey.currentState?.trigger();
  }

  Future<void> _onFlashComplete() async {
    if (_captureMode == _CaptureMode.gif) {
      // In GIF mode the flash callback is not used (GIF handles its own loop)
      return;
    }

    final xfile = await _cameraService.takePicture();
    if (!mounted) return;
    if (xfile == null) {
      setState(() => _isCountingDown = false);
      return;
    }

    final config = context.read<AppState>().eventConfig;
    if (config == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          compositedPhotoPath: xfile.path,
          rawPhotoPath: xfile.path,
        ),
      ),
    );
  }

  // ── GIF capture ────────────────────────────────────────────────────────────

  Future<void> _triggerGifCapture() async {
    if (!mounted) return;
    setState(() {
      _isCountingDown = false;
      _isCapturingGif = true;
      _gifFramesCaptured = 0;
    });

    final controller = _cameraService.controller;
    if (controller == null) return;

    String? gifPath;
    try {
      gifPath = await GifService.captureGif(
        controller,
        frameCount: _gifFrameCount,
        intervalBetweenFrames: const Duration(milliseconds: 500),
        onFrameCaptured: (captured, total) {
          // Brief flash between frames
          _flashKey.currentState?.trigger();
          if (mounted) {
            setState(() => _gifFramesCaptured = captured);
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCapturingGif = false;
          _isAssemblingGif = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isCapturingGif = false;
      _isAssemblingGif = false;
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          compositedPhotoPath: gifPath!,
          rawPhotoPath: gifPath,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
    final bool busy = _isCountingDown || _isCapturingGif || _isAssemblingGif;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview with correct aspect ratio
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

          // Back button (hidden during countdown / capture)
          if (!busy)
            Positioned(
              top: 48,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

          // Countdown overlay
          if (_isCountingDown) ...[
            CountdownOverlay(currentNumber: _currentCount),
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Text(
                _captureMode == _CaptureMode.gif ? 'Préparez-vous !' : 'Souriez !',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          // GIF capture progress overlay
          if (_isCapturingGif) _buildGifCaptureOverlay(),

          // Assembling GIF overlay
          if (_isAssemblingGif)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryPink),
                    SizedBox(height: 16),
                    Text(
                      'Création du GIF...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Flash overlay
          FlashOverlay(
            key: _flashKey,
            onComplete: _onFlashComplete,
          ),

          // Bottom controls (hidden during capture)
          if (!busy)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 24),
                  Center(
                    child: ShutterButton(onPressed: _onShutter),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeButton(
          label: '📸 Photo',
          selected: _captureMode == _CaptureMode.photo,
          onTap: () => setState(() => _captureMode = _CaptureMode.photo),
        ),
        const SizedBox(width: 12),
        _ModeButton(
          label: '🎬 GIF',
          selected: _captureMode == _CaptureMode.gif,
          onTap: () => setState(() => _captureMode = _CaptureMode.gif),
        ),
      ],
    );
  }

  Widget _buildGifCaptureOverlay() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing camera icon
            _PulsingIcon(),
            const SizedBox(height: 20),
            Text(
              '$_gifFramesCaptured / $_gifFrameCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture en cours...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode toggle button ──────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primaryPink, AppColors.orange],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: selected
              ? null
              : Border.all(color: Colors.white38, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Pulsing icon for GIF capture ────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Text(
        '📸',
        style: TextStyle(fontSize: 64),
      ),
    );
  }
}
