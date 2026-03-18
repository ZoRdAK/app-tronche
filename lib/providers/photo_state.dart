import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo.dart';
import '../services/database_service.dart';

class PhotoState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Photo> _photos = [];
  int _photoCount = 0;
  int _syncedCount = 0;

  List<Photo> get photos => List.unmodifiable(_photos);
  int get photoCount => _photoCount;
  int get syncedCount => _syncedCount;
  int get pendingCount => _photoCount - _syncedCount;

  /// Loads all photos from SQLite.
  Future<void> loadPhotos() async {
    _photos = await _db.getAllPhotos();
    _photoCount = _photos.length;
    _syncedCount = _photos.where((p) => p.isSynced).length;
    notifyListeners();
  }

  /// Inserts a new photo into SQLite and updates state.
  Future<void> addPhoto(Photo photo) async {
    final id = await _db.insertPhoto(photo);
    // Build a copy with the assigned id.
    final saved = Photo(
      id: id,
      localPath: photo.localPath,
      thumbnailPath: photo.thumbnailPath,
      photoCode: photo.photoCode,
      takenAt: photo.takenAt,
      isSynced: photo.isSynced,
      serverPhotoId: photo.serverPhotoId,
      syncedAt: photo.syncedAt,
    );
    _photos.insert(0, saved); // newest first
    _photoCount = _photos.length;
    _syncedCount = _photos.where((p) => p.isSynced).length;
    notifyListeners();
  }

  /// Deletes a photo's file and removes it from SQLite and state.
  Future<void> deletePhoto(int id, String filePath) async {
    await _db.deletePhoto(id);
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort file deletion; ignore errors.
    }
    _photos.removeWhere((p) => p.id == id);
    _photoCount = _photos.length;
    _syncedCount = _photos.where((p) => p.isSynced).length;
    notifyListeners();
  }

  /// Re-queries counts from SQLite (useful after background sync).
  Future<void> refreshCounts() async {
    _photoCount = await _db.getPhotoCount();
    _syncedCount = await _db.getSyncedPhotoCount();
    notifyListeners();
  }
}
