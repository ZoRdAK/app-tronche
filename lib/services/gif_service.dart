import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

class GifService {
  /// Captures [frameCount] frames from the camera and assembles
  /// them into an animated GIF with a boomerang effect.
  static Future<String> captureGif(
    CameraController controller, {
    int frameCount = 4,
    Duration intervalBetweenFrames = const Duration(milliseconds: 350),
    bool mirrorHorizontal = true,
    void Function(int captured, int total)? onFrameCaptured,
  }) async {
    final frames = <XFile>[];

    for (int i = 0; i < frameCount; i++) {
      final photo = await controller.takePicture();
      frames.add(photo);
      onFrameCaptured?.call(i + 1, frameCount);
      if (i < frameCount - 1) {
        await Future.delayed(intervalBetweenFrames);
      }
    }

    return await _assembleGif(frames, mirrorHorizontal: mirrorHorizontal);
  }

  static Future<String> _assembleGif(
    List<XFile> frames, {
    bool mirrorHorizontal = true,
  }) async {
    img.Image? animation;

    Future<img.Image?> loadAndProcess(String path) async {
      final bytes = await File(path).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Mirror for front camera
      if (mirrorHorizontal) {
        image = img.flipHorizontal(image);
      }

      // Resize to 720px wide for decent quality GIF
      return img.copyResize(image, width: 720);
    }

    // Forward frames
    for (final frame in frames) {
      final image = await loadAndProcess(frame.path);
      if (image == null) continue;
      image.frameDuration = 300; // 300ms per frame (snappier)

      if (animation == null) {
        animation = image;
        animation.frameType = img.FrameType.animation;
        animation.loopCount = 0; // loop forever
      } else {
        animation.addFrame(image);
      }
    }

    // Reverse frames for boomerang (skip first and last to avoid duplicates)
    for (int i = frames.length - 2; i > 0; i--) {
      final image = await loadAndProcess(frames[i].path);
      if (image == null) continue;
      image.frameDuration = 300;
      animation?.addFrame(image);
    }

    if (animation == null) {
      throw Exception('GIF assembly failed: no frames decoded');
    }

    final gif = img.encodeGif(animation, samplingFactor: 1);

    final dir = await getApplicationDocumentsDirectory();
    final gifPath =
        '${dir.path}/photos/gif_${DateTime.now().millisecondsSinceEpoch}.gif';
    await Directory('${dir.path}/photos').create(recursive: true);
    await File(gifPath).writeAsBytes(gif);

    // Clean up temp frame files
    for (final frame in frames) {
      try {
        await File(frame.path).delete();
      } catch (_) {}
    }

    return gifPath;
  }
}
