import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';

// ---------------------------------------------------------------------------
// Top-level function required by compute() — runs in a background isolate.
// Receives frame file paths and returns the encoded GIF bytes synchronously.
// ---------------------------------------------------------------------------
Uint8List _assembleGifIsolate(Map<String, dynamic> params) {
  final paths = List<String>.from(params['paths'] as List);
  final mirrorHorizontal = params['mirrorHorizontal'] as bool;

  img.Image? loadAndProcess(String path) {
    final bytes = File(path).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) return null;
    if (mirrorHorizontal) {
      image = img.flipHorizontal(image);
    }
    return img.copyResize(image, width: 720);
  }

  img.Image? animation;

  // Forward frames
  for (final path in paths) {
    final image = loadAndProcess(path);
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
  for (int i = paths.length - 2; i > 0; i--) {
    final image = loadAndProcess(paths[i]);
    if (image == null) continue;
    image.frameDuration = 300;
    animation?.addFrame(image);
  }

  if (animation == null) {
    throw Exception('GIF assembly failed: no frames decoded');
  }

  return Uint8List.fromList(img.encodeGif(animation, samplingFactor: 1));
}

// ---------------------------------------------------------------------------
// Service class
// ---------------------------------------------------------------------------

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
    // Extract paths — XFile cannot cross isolate boundaries.
    final paths = frames.map((f) => f.path).toList();

    // Run CPU-intensive GIF encoding in a background isolate.
    final gifBytes = await compute(_assembleGifIsolate, {
      'paths': paths,
      'mirrorHorizontal': mirrorHorizontal,
    });

    // Write output file and clean up temp frames on the main isolate
    // (getApplicationDocumentsDirectory uses platform channels).
    final dir = await getApplicationDocumentsDirectory();
    final gifPath =
        '${dir.path}/photos/gif_${DateTime.now().millisecondsSinceEpoch}.gif';
    await Directory('${dir.path}/photos').create(recursive: true);
    await File(gifPath).writeAsBytes(gifBytes);

    // Clean up temp frame files
    for (final frame in frames) {
      try {
        await File(frame.path).delete();
      } catch (_) {}
    }

    return gifPath;
  }
}
