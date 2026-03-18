import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/app_state.dart';
import '../../services/camera_service.dart';
import '../../widgets/overlay_painter.dart';
import '../../widgets/shutter_button.dart';
import '../admin/gallery_screen.dart';
import 'countdown_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  bool _isInitializing = true;
  String? _error;

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
    _cameraService.disposeCamera();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onShutter() {
    if (!_cameraService.isInitialized) return;
    final config = context.read<AppState>().eventConfig;
    if (config == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CountdownScreen(cameraService: _cameraService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppState>().eventConfig;

    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF667EEA)),
        ),
      );
    }

    if (_error != null || !_cameraService.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Colors.white38, size: 64),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Caméra non disponible',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour',
                    style: TextStyle(color: Color(0xFF667EEA))),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(_cameraService.controller!),

          // Live overlay
          if (config != null)
            CustomPaint(painter: OverlayPainter(config: config)),

          // Back button
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spacer for symmetry
                const SizedBox(width: 80),
                ShutterButton(onPressed: _onShutter),
                const SizedBox(width: 20),
                // Gallery button
                IconButton(
                  icon: const Icon(Icons.grid_on,
                      color: Colors.white70, size: 32),
                  onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GalleryScreen()),
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
