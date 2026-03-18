import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../providers/photo_state.dart';
import '../shared/photo_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoState>().loadPhotos();
    });
  }

  Future<void> _confirmDelete(BuildContext context, int id, String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Supprimer la photo',
            style: TextStyle(color: AppColors.textDark)),
        content: const Text(
          'Cette photo sera supprimée définitivement.',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textDarkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<PhotoState>().deletePhoto(id, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoState = context.watch<PhotoState>();
    final photos = photoState.photos;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Galerie locale (${photos.length})',
          style: const TextStyle(
              color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: photos.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: AppColors.inputBorderLight, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Aucune photo pour le moment',
                    style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                final displayPath =
                    photo.thumbnailPath ?? photo.localPath;
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PhotoViewerScreen(photoPath: photo.localPath),
                    ),
                  ),
                  onLongPress: () => _confirmDelete(
                    context,
                    photo.id!,
                    photo.localPath,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(displayPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.inputBorderLight,
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textDarkSecondary),
                          ),
                        ),
                        // Sync status indicator
                        if (!photo.isSynced)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.pending,
                                  color: Colors.black, size: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
