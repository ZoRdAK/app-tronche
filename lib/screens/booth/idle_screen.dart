import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config.dart';
import '../../providers/app_state.dart';
import '../../providers/photo_state.dart';
import '../../widgets/slideshow_widget.dart';
import 'camera_screen.dart';

class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen> {
  Timer? _longPressTimer;
  bool _longPressActive = false;

  /// Asset paths used as slideshow images in screenshot mode.
  static const _screenshotAssets = [
    'assets/screenshots/Gemini_Generated_Image_vf0oy1vf0oy1vf0o.png',
    'assets/screenshots/Gemini_Generated_Image_wsjjpowsjjpowsjj.png',
    'assets/screenshots/Gemini_Generated_Image_wwrdjwwwrdjwwwrd.png',
    'assets/screenshots/Gemini_Generated_Image_xrxizxrxizxrxizx.png',
  ];

  @override
  void initState() {
    super.initState();
    // Keep screen on while in photobooth mode.
    WakelockPlus.enable();
    if (AppConfig.isScreenshotMode) {
      // No camera needed in screenshot mode
      return;
    }
    // Load photos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoState>().loadPhotos();
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
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

    // Fallback: always show warm gradient with logo (never black)
    final cameraFallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFDF8F4),
            Color(0xFFF5E6D8),
            Color(0xFFFCE4EC),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 180,
              errorBuilder: (_, __, ___) => const Text(
                'Tronche!',
                style: TextStyle(
                  color: Color(0xFFE91E8C),
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              photoPaths.isEmpty
                  ? 'Prenez la première photo !'
                  : 'Le photobooth rigolo',
              style: const TextStyle(
                color: Color(0xFF9E6B7A),
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );

    // In screenshot mode, show asset images instead of file-based slideshow
    Widget backgroundWidget;
    if (AppConfig.isScreenshotMode) {
      backgroundWidget = SizedBox.expand(
        child: Image.asset(
          _screenshotAssets.first,
          fit: BoxFit.cover,
        ),
      );
    } else {
      backgroundWidget = SlideshowWidget(
        photoPaths: photoPaths,
        fallback: cameraFallback,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: slideshow or camera
          backgroundWidget,

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
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(blurRadius: 16, color: Colors.black54),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(config.eventDate),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
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
                    key: const Key('branding_logo'),
                    onTapDown: (_) => _startLongPress(),
                    onTapUp: (_) => _cancelLongPress(),
                    onTapCancel: _cancelLongPress,
                    onLongPress: _goToAdmin,
                    child: Image.asset(
                      'assets/logo.png',
                      height: 50,
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
