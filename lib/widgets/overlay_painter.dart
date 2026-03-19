import 'package:flutter/material.dart';
import '../models/event_config.dart';

/// CustomPainter that draws a live camera overlay preview on top of the
/// camera feed. Mirrors the compositing logic of OverlayService so that
/// guests see an accurate preview before the photo is taken.
class OverlayPainter extends CustomPainter {
  final EventConfig config;

  const OverlayPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    switch (config.overlayTemplate) {
      case 'minimal':
        _paintMinimal(canvas, size);
      case 'festive':
        _paintFestive(canvas, size);
      default:
        _paintElegant(canvas, size);
    }
  }

  // ---------------------------------------------------------------------------
  // Elegant template
  // ---------------------------------------------------------------------------

  void _paintElegant(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top gradient for names overlay
    final topGradientHeight = h * 0.22;
    final topRect = Rect.fromLTWH(0, 0, w, topGradientHeight);
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withAlpha(180), Colors.transparent],
    );
    canvas.drawRect(topRect, Paint()..shader = topGradient.createShader(topRect));

    // Thin white border — 20px from edges
    const pad = 20.0;
    final borderPaint = Paint()
      ..color = Colors.white.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(
      Rect.fromLTRB(pad, pad, w - pad, h - pad),
      borderPaint,
    );

    // Name & date centered at top
    final nameText = '${config.name1} & ${config.name2}';
    final dateText = _formatDate(config.eventDate);
    _drawCenteredText(
      canvas,
      nameText,
      size,
      y: 48,
      fontSize: 24,
      opacity: 0.92,
      fontStyle: FontStyle.italic,
    );
    _drawCenteredText(
      canvas,
      dateText,
      size,
      y: 80,
      fontSize: 15,
      opacity: 0.75,
    );
  }

  // ---------------------------------------------------------------------------
  // Minimal template
  // ---------------------------------------------------------------------------

  void _paintMinimal(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top-left gradient for names
    final gradientHeight = h * 0.18;
    final rect = Rect.fromLTWH(0, 0, w, gradientHeight);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withAlpha(120), Colors.transparent],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final nameText =
        '${config.name1.toLowerCase()} ♡ ${config.name2.toLowerCase()}';
    final dateText = _formatDate(config.eventDate);
    _drawText(
      canvas,
      nameText,
      x: 28,
      y: 48,
      fontSize: 18,
      opacity: 0.75,
    );
    _drawText(
      canvas,
      dateText,
      x: 28,
      y: 74,
      fontSize: 14,
      opacity: 0.55,
    );
  }

  // ---------------------------------------------------------------------------
  // Festive template
  // ---------------------------------------------------------------------------

  void _paintFestive(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Full-top gradient
    final gradientHeight = h * 0.25;
    final rect = Rect.fromLTWH(0, 0, w, gradientHeight);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.black.withAlpha(160), Colors.transparent],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final parts = '${config.name1} & ${config.name2}'.split(' & ');
    final initials = parts
        .map((n) => n.trim().isNotEmpty ? n.trim()[0].toUpperCase() : '')
        .join(' + ');
    final festiveLine = '* $initials *';
    final dateText = '· ${_formatDate(config.eventDate)} ·';

    _drawCenteredText(
      canvas,
      festiveLine,
      size,
      y: 44,
      fontSize: 26,
      opacity: 0.95,
      fontWeight: FontWeight.w700,
    );
    _drawCenteredText(
      canvas,
      dateText,
      size,
      y: 78,
      fontSize: 18,
      opacity: 0.75,
    );
  }

  // ---------------------------------------------------------------------------
  // Drawing helpers
  // ---------------------------------------------------------------------------

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Size size, {
    required double y,
    double fontSize = 20,
    double opacity = 1.0,
    FontWeight fontWeight = FontWeight.w600,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          shadows: const [
            Shadow(blurRadius: 8, color: Colors.black),
            Shadow(blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);

    final x = (size.width - painter.width) / 2;
    painter.paint(canvas, Offset(x, y));
  }

  void _drawText(
    Canvas canvas,
    String text, {
    required double x,
    required double y,
    double fontSize = 16,
    double opacity = 1.0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(blurRadius: 6, color: Colors.black),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, Offset(x, y));
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

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) =>
      oldDelegate.config != config;
}
