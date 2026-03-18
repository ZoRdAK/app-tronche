import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/photo.dart';
import '../../models/send_queue_item.dart';
import '../../providers/app_state.dart';
import '../../providers/photo_state.dart';
import '../../services/database_service.dart';
import '../../services/overlay_service.dart';
import 'camera_screen.dart';
import 'email_screen.dart';
import 'idle_screen.dart';
import 'qr_screen.dart';

class PreviewScreen extends StatefulWidget {
  final String compositedPhotoPath;
  final String? rawPhotoPath;

  const PreviewScreen({
    super.key,
    required this.compositedPhotoPath,
    this.rawPhotoPath,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late String _photoCode;
  int? _savedPhotoId;
  bool _isSaving = true;
  bool _showUpgradePrompt = false;
  late String _displayPhotoPath;

  @override
  void initState() {
    super.initState();
    _photoCode = _generatePhotoCode();
    // Show raw photo immediately for fast transition (Bug 3 fix)
    _displayPhotoPath = widget.rawPhotoPath ?? widget.compositedPhotoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _compositeAndSave());
  }

  String _generatePhotoCode() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _compositeAndSave() async {
    final appState = context.read<AppState>();
    final photoState = context.read<PhotoState>();
    final config = appState.eventConfig;
    if (config == null) {
      setState(() => _isSaving = false);
      return;
    }

    // Check plan limit
    final maxPhotos = appState.maxPhotos;
    final currentCount = photoState.photoCount;
    if (maxPhotos != -1 && currentCount >= maxPhotos) {
      setState(() {
        _isSaving = false;
        _showUpgradePrompt = true;
      });
      return;
    }

    // Composite overlay asynchronously (Bug 3 fix)
    final overlayService = OverlayService();
    final addWatermark = config.plan == 'free';
    String compositedPath;
    try {
      compositedPath = await overlayService.compositePhoto(
        widget.rawPhotoPath ?? widget.compositedPhotoPath,
        config,
        addWatermark,
      );
    } catch (_) {
      compositedPath = widget.rawPhotoPath ?? widget.compositedPhotoPath;
    }

    // Update display with composited photo
    if (mounted) {
      setState(() => _displayPhotoPath = compositedPath);
    }

    // Generate thumbnail
    String? thumbnailPath;
    try {
      thumbnailPath = await overlayService.generateThumbnail(compositedPath);
    } catch (_) {
      thumbnailPath = null;
    }

    final photo = Photo(
      localPath: compositedPath,
      thumbnailPath: thumbnailPath,
      photoCode: _photoCode,
      takenAt: DateTime.now(),
    );

    await photoState.addPhoto(photo);

    // Get the saved photo's id
    final savedPhotos = photoState.photos;
    final savedPhoto =
        savedPhotos.isNotEmpty ? savedPhotos.first : null;
    _savedPhotoId = savedPhoto?.id;

    // Add 'sync' item to send queue
    if (_savedPhotoId != null) {
      final db = DatabaseService();
      await db.insertSendQueueItem(SendQueueItem(
        photoId: _savedPhotoId!,
        type: 'sync',
        createdAt: DateTime.now(),
      ));
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Image.file(
            File(_displayPhotoPath),
            fit: BoxFit.contain,
          ),

          // Top back button
          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Bottom actions
          if (!_isSaving)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(220),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _showUpgradePrompt
                    ? _buildUpgradePrompt()
                    : _buildActionButtons(),
              ),
            ),

          if (_isSaving)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF667EEA)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.qr_code,
              label: 'QR Code',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QrScreen(photoCode: _photoCode),
                ),
              ),
            ),
            _ActionButton(
              icon: Icons.email_outlined,
              label: 'Email',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmailScreen(
                    photoCode: _photoCode,
                    photoId: _savedPhotoId ?? 0,
                  ),
                ),
              ),
            ),
            _ActionButton(
              icon: Icons.camera_alt,
              label: 'Encore !',
              onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CameraScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const IdleScreen()),
            (route) => false,
          ),
          child: const Text(
            'Passer',
            style: TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradePrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, color: Color(0xFF667EEA), size: 40),
        const SizedBox(height: 12),
        const Text(
          'Limite de photos atteinte',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Passez a Premium pour des photos illimitees.',
          style: TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Voir les offres'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const IdleScreen()),
              (route) => false,
            ),
            child: const Text("Retour a l'accueil",
                style: TextStyle(color: Colors.white38)),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
