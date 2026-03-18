import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// Finds the front camera and initializes the CameraController.
  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _errorMessage = 'No cameras available on this device.';
        notifyListeners();
        return;
      }

      // Prefer front camera; fall back to first available
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _errorMessage = null;
      notifyListeners();
    } on CameraException catch (e) {
      _isInitialized = false;
      _errorMessage = 'Camera error: ${e.description ?? e.code}';
      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  /// Takes a picture and returns the XFile, or null on error.
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final xfile = await _controller!.takePicture();
      return xfile;
    } on CameraException catch (e) {
      _errorMessage = 'Capture failed: ${e.description ?? e.code}';
      notifyListeners();
      return null;
    }
  }

  /// Disposes the camera controller and resets state.
  Future<void> disposeCamera() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
