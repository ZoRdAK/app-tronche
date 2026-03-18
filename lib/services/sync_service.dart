import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../providers/photo_state.dart';
import '../providers/sync_state.dart';
import 'api_service.dart';
import 'database_service.dart';

/// Background sync service: uploads unsynced photos and processes the email
/// queue.  Should be started when the user is logged in and stopped on logout.
class SyncService {
  final DatabaseService _db;
  final ApiService _api;
  final PhotoState _photoState;
  final SyncState _syncState;

  Timer? _timer;
  bool _isSyncing = false;

  SyncService({
    required DatabaseService db,
    required ApiService api,
    required PhotoState photoState,
    required SyncState syncState,
  })  : _db = db,
        _api = api,
        _photoState = photoState,
        _syncState = syncState;

  /// Starts periodic background sync (every 30 seconds).
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.syncInterval, (_) => _runSync());
    // Kick off an immediate sync on start.
    _runSync();
  }

  /// Cancels the periodic timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Manually trigger a sync cycle (used by the "Force sync" button).
  Future<void> syncNow() => _runSync();

  // ────────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _runSync() async {
    // Guard: skip if already syncing or offline or provider disposed.
    if (_isSyncing) return;
    if (_syncState.isDisposed) return;
    if (!_syncState.isOnline) return;

    _isSyncing = true;
    _syncState.isSyncing = true;

    try {
      await _syncPhotos();
      await _processEmailQueue();
    } finally {
      _isSyncing = false;
      if (!_syncState.isDisposed) {
        _syncState.isSyncing = false;
        // Refresh counts in both states so the UI stays up to date.
        await _syncState.loadCounts();
        await _syncState.loadQueueItems();
      }
      await _photoState.refreshCounts();
    }
  }

  /// Uploads each unsynced photo to the server, one at a time (oldest first).
  Future<void> _syncPhotos() async {
    final config = await _db.getEventConfig();
    if (config == null || config.serverEventId == null) return;

    final photos = await _db.getUnsyncedPhotos();
    for (final photo in photos) {
      // Re-check connectivity before each upload.
      if (!_syncState.isOnline) break;

      try {
        final result = await _api.uploadPhoto(
          eventId: config.serverEventId!,
          filePath: photo.localPath,
          takenAt: photo.takenAt.toIso8601String(),
        );
        final serverPhotoId = result['id']?.toString() ??
            result['photoId']?.toString() ??
            '';
        await _db.markPhotoSynced(photo.id!, serverPhotoId);
      } catch (e) {
        debugPrint('[SyncService] Failed to upload photo ${photo.id}: $e');
        // Continue with the next photo; don't abort the whole cycle.
      }
    }
  }

  /// Processes pending email queue items, sending each one to the server.
  Future<void> _processEmailQueue() async {
    if (!_syncState.isOnline) return;

    final items = await _db.getPendingQueueItems();
    final emailItems = items.where((i) => i.type == 'email').toList();

    for (final item in emailItems) {
      if (!_syncState.isOnline) break;
      if (item.attempts >= 5) continue; // Skip after 5 failed attempts.

      try {
        // We need the server photo ID to send the email.
        final photos = await _db.getAllPhotos();
        final photo = photos.where((p) => p.id == item.photoId).firstOrNull;
        if (photo == null || photo.serverPhotoId == null) {
          // Photo not yet synced; skip for now.
          continue;
        }

        await _api.queueEmail(
          photoId: photo.serverPhotoId!,
          recipient: item.recipient ?? '',
        );

        await _db.updateQueueItemStatus(
          item.id!,
          'sent',
          sentAt: DateTime.now(),
        );
      } catch (e) {
        debugPrint('[SyncService] Failed to process email queue item ${item.id}: $e');
        await _db.updateQueueItemStatus(
          item.id!,
          'failed',
          error: e.toString(),
        );
      }
    }
  }
}
