import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isFrontCamera = false;

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

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _isFrontCamera = camera.lensDirection == CameraLensDirection.front;

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
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

  /// Takes a picture, mirrors it if front camera, returns the path.
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      final xfile = await _controller!.takePicture();

      // Front camera photos need to be flipped horizontally to match the preview
      if (_isFrontCamera) {
        final mirrored = await compute(_mirrorImage, xfile.path);
        if (mirrored != null) {
          return XFile(mirrored);
        }
      }

      return xfile;
    } on CameraException catch (e) {
      _errorMessage = 'Capture failed: ${e.description ?? e.code}';
      notifyListeners();
      return null;
    }
  }

  /// Mirrors an image file horizontally and resizes to max 1920px for faster
  /// sync. Runs in an isolate via compute().
  static String? _mirrorImage(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      image = img.flipHorizontal(image);

      // Resize to max 1920px on the longest side (~300–500 KB vs 5–8 MB)
      const maxDim = 1920;
      if (image.width > maxDim || image.height > maxDim) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: maxDim);
        } else {
          image = img.copyResize(image, height: maxDim);
        }
      }

      final outPath = path.replaceAll('.jpg', '_m.jpg');
      File(outPath).writeAsBytesSync(img.encodeJpg(image, quality: 85));

      // Clean up original
      try { File(path).deleteSync(); } catch (_) {}

      return outPath;
    } catch (_) {
      return null;
    }
  }

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
