import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../models/send_queue_item.dart';
import '../../providers/photo_state.dart';
import '../../providers/sync_state.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncState>().loadQueueItems();
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
    final items = syncState.queueItems;

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

          // Queue list
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'La file est vide',
                      style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 16),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final photo = photoState.photos
                            .where((p) => p.id == item.photoId)
                            .firstOrNull;
                        return _QueueItemTile(item: item, thumbnailPath: photo?.thumbnailPath);
                      },
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
                  gradient: syncState.isOnline ? AppColors.primaryGradient : null,
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
}

// ─────────────────────────────────────────────────────────────────────────────

class _QueueItemTile extends StatelessWidget {
  final SendQueueItem item;
  final String? thumbnailPath;

  const _QueueItemTile({required this.item, this.thumbnailPath});

  @override
  Widget build(BuildContext context) {
    Widget? thumbnail;
    if (thumbnailPath != null) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(thumbnailPath!),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    } else {
      thumbnail = _placeholder();
    }

    final statusIcon = _statusIcon(item.status);
    final destination = item.type == 'email'
        ? (item.recipient ?? 'email')
        : 'Serveur';

    final ts = item.sentAt ?? item.createdAt;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          thumbnail,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.type == 'email' ? 'Email' : 'Synchronisation',
                  style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              statusIcon,
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputBorderLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.photo, color: AppColors.textDarkSecondary, size: 24),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'failed':
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
      default:
        return const Icon(Icons.pending_outlined,
            color: Colors.amber, size: 20);
    }
  }
}
