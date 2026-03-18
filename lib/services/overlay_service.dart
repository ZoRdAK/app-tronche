import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/event_config.dart';

// ---------------------------------------------------------------------------
// Top-level function required by compute() — runs in a background isolate.
// All arguments must be serialisable (plain Dart types).
// Returns the encoded JPEG bytes.
// ---------------------------------------------------------------------------
Uint8List _compositeInIsolate(Map<String, dynamic> params) {
  final bytes = params['bytes'] as Uint8List;
  final overlayTemplate = params['overlayTemplate'] as String;
  final nameText = params['nameText'] as String;
  final dateText = params['dateText'] as String;
  final addWatermark = params['addWatermark'] as bool;

  img.Image? image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');

  // Flip horizontally to correct front-camera mirror effect
  image = img.flipHorizontal(image);

  final w = image.width;
  final h = image.height;

  switch (overlayTemplate) {
    case 'minimal':
      image = _applyMinimalOverlay(image, nameText, dateText, w, h);
    case 'festive':
      image = _applyFestiveOverlay(image, nameText, dateText, w, h);
    default:
      image = _applyElegantOverlay(image, nameText, dateText, w, h);
  }

  if (addWatermark) {
    image = _applyWatermark(image, w, h);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

// ---------------------------------------------------------------------------
// Template implementations (top-level so they are accessible from the isolate)
// ---------------------------------------------------------------------------

img.Image _applyElegantOverlay(
  img.Image image,
  String nameText,
  String dateText,
  int w,
  int h,
) {
  // Semi-transparent gradient at bottom
  final gradientHeight = (h * 0.22).toInt();
  for (var y = h - gradientHeight; y < h; y++) {
    final alpha =
        ((y - (h - gradientHeight)) / gradientHeight * 180).toInt();
    for (var x = 0; x < w; x++) {
      final px = image.getPixel(x, y);
      final r = ((px.r * (255 - alpha)) / 255).round();
      final g = ((px.g * (255 - alpha)) / 255).round();
      final b = ((px.b * (255 - alpha)) / 255).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Thin white border (elegant frame) 20px from edges
  const borderPad = 20;
  final borderColor = img.ColorRgba8(255, 255, 255, 160);
  // Top & Bottom
  for (var x = borderPad; x < w - borderPad; x++) {
    image.setPixel(x, borderPad, borderColor);
    image.setPixel(x, h - borderPad - 1, borderColor);
  }
  // Left & Right
  for (var y = borderPad; y < h - borderPad; y++) {
    image.setPixel(borderPad, y, borderColor);
    image.setPixel(w - borderPad - 1, y, borderColor);
  }

  // Draw text centered at bottom
  final white90 = img.ColorRgba8(255, 255, 255, 230);
  final white70 = img.ColorRgba8(255, 255, 255, 178);
  img.drawString(
    image,
    nameText,
    font: img.arial24,
    x: null, // centered
    y: h - 80,
    color: white90,
  );
  img.drawString(
    image,
    dateText,
    font: img.arial24,
    x: null,
    y: h - 48,
    color: white70,
  );

  return image;
}

img.Image _applyMinimalOverlay(
  img.Image image,
  String nameText,
  String dateText,
  int w,
  int h,
) {
  // Subtle left-bottom gradient
  final gradientHeight = (h * 0.15).toInt();
  for (var y = h - gradientHeight; y < h; y++) {
    final alpha =
        ((y - (h - gradientHeight)) / gradientHeight * 120).toInt();
    final halfW = w ~/ 2;
    for (var x = 0; x < halfW; x++) {
      final px = image.getPixel(x, y);
      final r = ((px.r * (255 - alpha)) / 255).round();
      final g = ((px.g * (255 - alpha)) / 255).round();
      final b = ((px.b * (255 - alpha)) / 255).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  final white70 = img.ColorRgba8(255, 255, 255, 178);
  final white50 = img.ColorRgba8(255, 255, 255, 128);
  final lowerName = nameText.toLowerCase().replaceAll('&', '♡');
  img.drawString(
    image,
    lowerName,
    font: img.arial24,
    x: 28,
    y: h - 62,
    color: white70,
  );
  img.drawString(
    image,
    dateText,
    font: img.arial14,
    x: 28,
    y: h - 38,
    color: white50,
  );

  return image;
}

img.Image _applyFestiveOverlay(
  img.Image image,
  String nameText,
  String dateText,
  int w,
  int h,
) {
  final gradientHeight = (h * 0.25).toInt();
  for (var y = h - gradientHeight; y < h; y++) {
    final alpha =
        ((y - (h - gradientHeight)) / gradientHeight * 160).toInt();
    for (var x = 0; x < w; x++) {
      final px = image.getPixel(x, y);
      final r = ((px.r * (255 - alpha)) / 255).round();
      final g = ((px.g * (255 - alpha)) / 255).round();
      final b = ((px.b * (255 - alpha)) / 255).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  final white90 = img.ColorRgba8(255, 255, 255, 230);
  final white70 = img.ColorRgba8(255, 255, 255, 178);

  // Build initials for festive style
  final parts = nameText.split(' & ');
  final initials = parts
      .map((n) => n.trim().isNotEmpty ? n.trim()[0].toUpperCase() : '')
      .join(' + ');
  final festiveLine = '* $initials *';
  img.drawString(
    image,
    festiveLine,
    font: img.arial24,
    x: null,
    y: h - 80,
    color: white90,
  );
  img.drawString(
    image,
    '· $dateText ·',
    font: img.arial24,
    x: null,
    y: h - 48,
    color: white70,
  );

  return image;
}

img.Image _applyWatermark(img.Image image, int w, int h) {
  const watermark = 'Tronche!';
  final white40 = img.ColorRgba8(255, 255, 255, 100);
  // Estimate text width: arial14 ~8px per char
  final textW = watermark.length * 8;
  img.drawString(
    image,
    watermark,
    font: img.arial14,
    x: w - textW - 16,
    y: h - 28,
    color: white40,
  );
  return image;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Public service class
// ---------------------------------------------------------------------------

class OverlayService {
  /// Composites the overlay onto a photo and saves it to the app documents dir.
  /// Returns the path to the composited JPEG file.
  /// The CPU-intensive image processing runs in a background isolate via
  /// [compute]; only file I/O happens on the main isolate.
  Future<String> compositePhoto(
    String photoPath,
    EventConfig config,
    bool addWatermark,
  ) async {
    final bytes = await File(photoPath).readAsBytes();

    final nameText = '${config.name1} & ${config.name2}';
    final dateText = _formatDate(config.eventDate);

    // Run heavy image processing in a background isolate.
    final jpegBytes = await compute(_compositeInIsolate, {
      'bytes': bytes,
      'overlayTemplate': config.overlayTemplate,
      'nameText': nameText,
      'dateText': dateText,
      'addWatermark': addWatermark,
    });

    // Save composited photo (platform channel required — must stay on main isolate).
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'photos'));
    await photosDir.create(recursive: true);

    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}_comp.jpg';
    final outPath = p.join(photosDir.path, fileName);
    await File(outPath).writeAsBytes(jpegBytes);

    return outPath;
  }

  /// Generates a 400px-wide thumbnail and returns its path.
  Future<String> generateThumbnail(String compositedPath) async {
    final bytes = await File(compositedPath).readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode composited image for thumbnail');
    }

    final thumb = img.copyResize(image, width: 400);

    final dir = await getApplicationDocumentsDirectory();
    final thumbDir = Directory(p.join(dir.path, 'thumbnails'));
    await thumbDir.create(recursive: true);

    final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final thumbPath = p.join(thumbDir.path, fileName);
    await File(thumbPath).writeAsBytes(img.encodeJpg(thumb, quality: 75));

    return thumbPath;
  }
}
