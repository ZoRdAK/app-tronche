import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../models/photo.dart';
import '../../providers/photo_state.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../booth/idle_screen.dart';

class ServerSyncScreen extends StatefulWidget {
  final String eventId;
  const ServerSyncScreen({super.key, required this.eventId});

  @override
  State<ServerSyncScreen> createState() => _ServerSyncScreenState();
}

class _ServerSyncScreenState extends State<ServerSyncScreen> {
  int _total = 0;
  int _downloaded = 0;
  bool _isDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      final db = DatabaseService();
      final api = ApiService(db);

      // Fetch photo list from server
      final serverPhotos = await api.getEventPhotos(widget.eventId);

      if (!mounted) return;
      setState(() => _total = serverPhotos.length);

      if (serverPhotos.isEmpty) {
        _goToIdle();
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/photos');
      final thumbsDir = Directory('${appDir.path}/photos/thumbs');
      await photosDir.create(recursive: true);
      await thumbsDir.create(recursive: true);

      // Get existing local photo codes to skip duplicates
      final localPhotos = await db.getAllPhotos();
      final localCodes = localPhotos.map((p) => p.photoCode).toSet();

      for (final serverPhoto in serverPhotos) {
        if (!mounted) return;

        final photoCode = serverPhoto['photo_code'] as String? ?? '';
        if (photoCode.isEmpty || localCodes.contains(photoCode)) {
          setState(() => _downloaded++);
          continue;
        }

        try {
          final filename = '${DateTime.now().millisecondsSinceEpoch}_$_downloaded.jpg';
          final localPath = '${photosDir.path}/$filename';
          final thumbPath = '${thumbsDir.path}/$filename';

          // Download full photo
          await api.downloadPhoto(photoCode, localPath);

          // Download thumbnail
          try {
            await api.downloadThumbnail(photoCode, thumbPath);
          } catch (_) {
            // Thumbnail is optional, continue without it
          }

          // Insert into local DB
          final photo = Photo(
            localPath: localPath,
            thumbnailPath: File(thumbPath).existsSync() ? thumbPath : localPath,
            photoCode: photoCode,
            takenAt: DateTime.tryParse(serverPhoto['taken_at'] as String? ?? '') ?? DateTime.now(),
            isSynced: true,
            serverPhotoId: serverPhoto['id'] as String? ?? '',
            syncedAt: DateTime.now(),
          );
          await db.insertPhoto(photo);
        } catch (e) {
          // Skip failed photo, continue with next
          debugPrint('Failed to download photo $photoCode: $e');
        }

        if (mounted) {
          setState(() => _downloaded++);
        }
      }

      // Refresh photo state
      if (mounted) {
        await context.read<PhotoState>().loadPhotos();
        setState(() => _isDone = true);
        // Auto-navigate after short delay
        await Future.delayed(const Duration(seconds: 1));
        _goToIdle();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _goToIdle() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IdleScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _downloaded / _total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Logo
              Image.asset(
                'assets/logo.png',
                width: 80,
                errorBuilder: (_, __, ___) => ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Tronche!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              if (_isDone) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Terminé !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ] else if (_error != null) ...[
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Récupération de vos photos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _goToIdle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Récupération de vos photos',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nous téléchargeons les photos de votre événement...',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textDarkSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _total > 0 ? progress : null,
                    minHeight: 10,
                    backgroundColor: AppColors.inputBorderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryPink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_total > 0)
                  Text(
                    'Photo $_downloaded / $_total',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textDarkSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
              const Spacer(flex: 3),
              // Skip button
              if (!_isDone && _error == null)
                TextButton(
                  onPressed: _goToIdle,
                  child: const Text(
                    'Passer',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textDarkSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
