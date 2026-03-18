import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

class GifService {
  /// Captures [frameCount] frames from the camera over ~2 seconds and assembles
  /// them into an animated GIF with a boomerang effect.
  /// Returns the path to the saved GIF file.
  static Future<String> captureGif(
    CameraController controller, {
    int frameCount = 4,
    Duration intervalBetweenFrames = const Duration(milliseconds: 500),
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

    return await _assembleGif(frames);
  }

  static Future<String> _assembleGif(List<XFile> frames) async {
    // image v4: use Image with frameType.animation as the animation container.
    // The first frame becomes the "root" image; subsequent frames are added via addFrame().
    // frameDuration is in milliseconds; the GIF encoder converts it to 1/100 sec internally.
    img.Image? animation;

    Future<img.Image?> loadAndResize(String path) async {
      final bytes = await File(path).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;
      return img.copyResize(image, width: 480);
    }

    // Forward frames
    for (final frame in frames) {
      final image = await loadAndResize(frame.path);
      if (image == null) continue;
      image.frameDuration = 500; // 500ms per frame

      if (animation == null) {
        animation = image;
        animation.frameType = img.FrameType.animation;
        animation.loopCount = 0; // loop forever
      } else {
        animation.addFrame(image);
      }
    }

    // Reverse frames for boomerang effect (skip first and last to avoid duplicates)
    for (int i = frames.length - 2; i > 0; i--) {
      final image = await loadAndResize(frames[i].path);
      if (image == null) continue;
      image.frameDuration = 500;
      animation?.addFrame(image);
    }

    if (animation == null) {
      throw Exception('GIF assembly failed: no frames decoded');
    }

    final gif = img.encodeGif(animation);

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
