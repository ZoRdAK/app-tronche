import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../providers/photo_state.dart';
import '../../providers/sync_state.dart';
import 'config_screen.dart';
import 'gallery_screen.dart';
import 'send_queue_screen.dart';
import 'online_gallery_screen.dart';
import 'subscription_screen.dart';
import 'account_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final photoState = context.watch<PhotoState>();
    final syncState = context.watch<SyncState>();

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
          'Administration',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Stat cards ───────────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: 'Photos prises',
                value: '${photoState.photoCount}',
                icon: Icons.photo_camera,
                color: AppColors.primaryPink,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Synchronisées',
                value: '${photoState.syncedCount}',
                icon: Icons.cloud_done,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'En attente',
                value: '${photoState.pendingCount}',
                icon: Icons.pending_outlined,
                color: AppColors.orange,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── Network status ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: syncState.isOnline ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  syncState.isOnline ? 'Connecté' : 'Hors ligne',
                  style: TextStyle(
                    color: syncState.isOnline ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (syncState.isSyncing) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryPink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Synchronisation…',
                    style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Menu ─────────────────────────────────────────────────────────
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Configuration',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfigScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.photo_library_outlined,
            label: 'Galerie locale',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GalleryScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.outbox_outlined,
            label: "File d'envoi",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SendQueueScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.public,
            label: 'Galerie en ligne',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OnlineGalleryScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.diamond_outlined,
            label: 'Mon abonnement',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.person_outline,
            label: 'Mon compte',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Return to photobooth ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Pop back past admin gate to idle screen.
                  Navigator.of(context)
                    ..pop()  // DashboardScreen
                    ..pop(); // AdminGateScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retour au photobooth',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryPink),
        title: Text(label, style: const TextStyle(color: AppColors.textDark)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textDarkSecondary, size: 20),
        onTap: onTap,
      ),
    );
  }
}
