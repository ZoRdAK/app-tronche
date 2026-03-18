import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config.dart';
import '../../providers/app_state.dart';
import '../../providers/photo_state.dart';
import '../../services/camera_service.dart';
import '../../widgets/slideshow_widget.dart';
import 'camera_screen.dart';

class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen> {
  final CameraService _cameraService = CameraService();
  bool _cameraReady = false;
  Timer? _longPressTimer;
  bool _longPressActive = false;

  @override
  void initState() {
    super.initState();
    // Keep screen on while in photobooth mode.
    WakelockPlus.enable();
    // Load photos and initialise camera for fallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoState>().loadPhotos();
      _initCamera();
    });
  }

  Future<void> _initCamera() async {
    await _cameraService.initialize();
    if (mounted) setState(() => _cameraReady = _cameraService.isInitialized);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _cameraService.disposeCamera();
    // Disable wakelock when leaving booth mode.
    WakelockPlus.disable();
    super.dispose();
  }

  void _startLongPress() {
    _longPressActive = true;
    _longPressTimer = Timer(const Duration(seconds: 3), () {
      if (_longPressActive && mounted) {
        _goToAdmin();
      }
    });
  }

  void _cancelLongPress() {
    _longPressActive = false;
    _longPressTimer?.cancel();
  }

  void _goToAdmin() {
    // Navigate to AdminGateScreen — imported lazily to avoid circular deps
    Navigator.of(context).pushNamed('/admin');
  }

  void _startPhotobooth() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoState = context.watch<PhotoState>();
    final appState = context.watch<AppState>();
    final config = appState.eventConfig;

    final photoPaths = photoState.photos
        .where((p) => p.localPath.isNotEmpty)
        .map((p) => p.localPath)
        .toList();

    // Fallback: camera preview (Bug 2 fix: correct aspect ratio)
    Widget cameraFallback;
    if (_cameraReady && _cameraService.controller != null) {
      final ctrl = _cameraService.controller!;
      cameraFallback = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.previewSize!.height,
            height: ctrl.value.previewSize!.width,
            child: CameraPreview(ctrl),
          ),
        ),
      );
    } else {
      cameraFallback = Container(color: AppColors.background);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: slideshow or camera
          SlideshowWidget(
            photoPaths: photoPaths,
            fallback: cameraFallback,
          ),

          // Top overlay: couple names + date
          if (config != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 52, 24, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(180),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${config.name1} & ${config.name2}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(config.eventDate),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom overlay: CTA + branding
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 52),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withAlpha(200),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // CTA button (Bug 10: centered)
                  Center(
                    child: GestureDetector(
                      onTap: _startPhotobooth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 18),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPink.withAlpha(100),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Touchez pour commencer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Branding with long-press to admin
                  GestureDetector(
                    onTapDown: (_) => _startLongPress(),
                    onTapUp: (_) => _cancelLongPress(),
                    onTapCancel: _cancelLongPress,
                    onLongPress: _goToAdmin,
                    child: Image.asset(
                      'assets/logo.png',
                      height: 40,
                      errorBuilder: (_, __, ___) => const Text(
                        'Tronche!',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
