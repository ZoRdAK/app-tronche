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

  /// Mirrors an image file horizontally. Runs in an isolate via compute().
  static String? _mirrorImage(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      image = img.flipHorizontal(image);

      final outPath = path.replaceAll('.jpg', '_m.jpg');
      File(outPath).writeAsBytesSync(img.encodeJpg(image, quality: 92));

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
