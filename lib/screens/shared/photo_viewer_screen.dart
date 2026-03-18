import 'dart:io';
import 'package:flutter/material.dart';

/// Full-screen photo viewer with pinch-to-zoom and pan support.
class PhotoViewerScreen extends StatelessWidget {
  final String photoPath;

  const PhotoViewerScreen({super.key, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive photo viewer
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: Colors.white38, size: 80),
                ),
              ),
            ),
          ),

          // Back button overlay
          Positioned(
            top: 48,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
