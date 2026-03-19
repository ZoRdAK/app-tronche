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
    final screenWidth = MediaQuery.of(context).size.width;

    final photoPaths = photoState.photos
        .where((p) => p.localPath.isNotEmpty)
        .map((p) => p.localPath)
        .toList();

    // Fallback shown inside the frame when no photos yet
    final frameFallback = Container(
      color: const Color(0xFFF5E6D8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: AppColors.primaryPink.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              photoPaths.isEmpty
                  ? 'Prenez la première photo !'
                  : 'Le photobooth rigolo',
              style: TextStyle(
                color: AppColors.primaryPink.withAlpha(180),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Photo slideshow widget (or screenshot asset in screenshot mode)
    Widget photoContent;
    if (AppConfig.isScreenshotMode) {
      photoContent = Image.asset(
        _screenshotAssets.first,
        fit: BoxFit.cover,
      );
    } else {
      photoContent = SlideshowWidget(
        photoPaths: photoPaths,
        fallback: frameFallback,
      );
    }

    // Frame width: ~70% of screen width, square
    final frameSize = screenWidth * 0.70;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F4),
      body: SizedBox.expand(
        child: Container(
          // Warm gradient background
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
          child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Couple names + date ──────────────────────────────
              if (config != null) ...[
                Column(
                  children: [
                    Text(
                      '${config.name1} & ${config.name2}',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Color(0x22000000),
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(config.eventDate),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textDarkSecondary,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ],

              // ── Photo frame (polaroid-style) ─────────────────────
              Container(
                width: frameSize,
                height: frameSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 6,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: photoContent,
                ),
              ),

              // ── CTA + branding ───────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Touchez pour commencer" gradient button
                  GestureDetector(
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

                  const SizedBox(height: 20),

                  // Branding logo with long-press to admin
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
                          color: AppColors.textDarkSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
