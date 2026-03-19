import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../models/send_queue_item.dart';
import '../../providers/photo_state.dart';
import '../../providers/sync_state.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';

class SendQueueScreen extends StatefulWidget {
  const SendQueueScreen({super.key});

  @override
  State<SendQueueScreen> createState() => _SendQueueScreenState();
}

class _SendQueueScreenState extends State<SendQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Clean up orphaned queue items (photos deleted but queue entries remain)
      final db = DatabaseService();
      await db.cleanOrphanedQueueItems();
      if (mounted) {
        context.read<SyncState>().loadQueueItems();
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<SyncState>().loadQueueItems();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = context.watch<SyncState>();
    final photoState = context.watch<PhotoState>();
    final syncService = context.read<SyncService>();
    // Show photo sync status from PhotoState (source of truth)
    final totalPhotos = photoState.photoCount;
    final syncedPhotos = photoState.syncedCount;
    final pendingPhotos = photoState.pendingCount;

    // Show only email items from send_queue (sync items are tracked via photos table)
    final emailItems = syncState.queueItems.where((i) => i.type == 'email').toList();
    final pendingEmails = emailItems.where((i) => i.status == 'pending' || i.status == 'sending').toList();
    final sentEmails = emailItems.where((i) => i.status == 'sent').toList();
    final failedEmails = emailItems.where((i) => i.status == 'failed').toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "File d'envoi",
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Network status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.cardLight,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: syncState.isOnline ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  syncState.isOnline ? 'Connecté' : 'Hors ligne',
                  style: TextStyle(
                    color: syncState.isOnline ? Colors.green : Colors.red,
                    fontSize: 13,
                  ),
                ),
                if (syncState.isSyncing) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryPink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Synchronisation en cours…',
                    style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          // Sync progress
          if (syncState.isSyncing)
            const LinearProgressIndicator(
              color: AppColors.primaryPink,
              backgroundColor: AppColors.inputBorderLight,
              minHeight: 3,
            ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  // ── Photo sync summary card ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Synchronisation des photos',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatChip(
                                label: 'Total',
                                value: '$totalPhotos',
                                color: AppColors.primaryPink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: 'Synchronisées',
                                value: '$syncedPhotos',
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatChip(
                                label: 'En attente',
                                value: '$pendingPhotos',
                                color: pendingPhotos > 0 ? AppColors.warning : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        if (pendingPhotos > 0 && syncState.isSyncing)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Synchronisation en cours…',
                              style: TextStyle(color: AppColors.primaryPink, fontSize: 13),
                            ),
                          ),
                        if (pendingPhotos > 0 && !syncState.isSyncing && syncState.isOnline)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'Prochaine synchronisation dans quelques secondes…',
                              style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13),
                            ),
                          ),
                        if (pendingPhotos > 0 && !syncState.isOnline)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'En attente de connexion réseau…',
                              style: TextStyle(color: AppColors.warning, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Emails section ──
                  if (emailItems.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        'Envois par email',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (pendingEmails.isNotEmpty) ...[
                      _SectionHeader(label: 'En attente', count: pendingEmails.length, dotColor: Colors.amber),
                      ...pendingEmails.map((item) => _SimpleItemTile(
                            item: item,
                            thumbnail: _thumbnailFor(item, photoState),
                            isOnline: syncState.isOnline,
                            isSyncing: syncState.isSyncing,
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (failedEmails.isNotEmpty) ...[
                      _SectionHeader(label: 'Échoué', count: failedEmails.length, dotColor: Colors.red),
                      ...failedEmails.map((item) => _SimpleItemTile(
                            item: item,
                            thumbnail: _thumbnailFor(item, photoState),
                            isOnline: syncState.isOnline,
                            isSyncing: syncState.isSyncing,
                          )),
                      const SizedBox(height: 8),
                    ],
                    if (sentEmails.isNotEmpty) ...[
                      _SectionHeader(label: 'Envoyé', count: sentEmails.length, dotColor: Colors.green),
                      ...sentEmails.map((item) => _SimpleItemTile(
                            item: item,
                            thumbnail: _thumbnailFor(item, photoState),
                            isOnline: syncState.isOnline,
                            isSyncing: syncState.isSyncing,
                          )),
                    ],
                  ],

                  if (emailItems.isEmpty && pendingPhotos == 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          'Tout est à jour !',
                          style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Force sync button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient:
                      syncState.isOnline ? AppColors.primaryGradient : null,
                  color: syncState.isOnline ? null : AppColors.inputBorderLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: syncState.isOnline
                      ? () => syncService.syncNow()
                      : null,
                  icon: const Icon(Icons.sync, color: Colors.white),
                  label: const Text(
                    'Forcer la synchronisation',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _thumbnailFor(SendQueueItem item, PhotoState photoState) {
    return photoState.photos
        .where((p) => p.id == item.photoId)
        .firstOrNull
        ?.thumbnailPath;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color dotColor;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2, left: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleItemTile extends StatelessWidget {
  final SendQueueItem item;
  final String? thumbnail;
  final bool isOnline;
  final bool isSyncing;

  const _SimpleItemTile({
    required this.item,
    this.thumbnail,
    this.isOnline = false,
    this.isSyncing = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget thumbWidget;
    if (thumbnail != null) {
      thumbWidget = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(thumbnail!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderThumb(),
        ),
      );
    } else {
      thumbWidget = _placeholderThumb();
    }

    final statusText = _statusText(isOnline, isSyncing);
    final dotColor = _dotColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorderLight),
      ),
      child: Row(
        children: [
          thumbWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                  color: AppColors.textDark, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(bool isOnline, bool isSyncing) {
    if (item.type == 'email') {
      final dest = item.recipient ?? 'email';
      switch (item.status) {
        case 'sent':
          return 'Email envoyé à $dest ✓';
        case 'failed':
          return 'Échec d\'envoi à $dest';
        default:
          if (isSyncing) return 'Envoi en cours à $dest…';
          if (!isOnline) return 'En attente de réseau…';
          return 'En attente d\'envoi à $dest';
      }
    } else {
      switch (item.status) {
        case 'sent':
          return 'Photo synchronisée ✓';
        case 'failed':
          return 'Échec de synchronisation';
        default:
          if (isSyncing) return 'Synchronisation en cours…';
          if (!isOnline) return 'En attente de réseau…';
          return 'En attente de synchronisation…';
      }
    }
  }

  Color _dotColor() {
    switch (item.status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  Widget _placeholderThumb() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.inputBorderLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.photo,
          color: AppColors.textDarkSecondary, size: 22),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textDarkSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
