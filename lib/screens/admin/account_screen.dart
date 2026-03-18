import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../onboarding/welcome_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final email = appState.eventConfig?.userEmail ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mon compte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current email
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    color: Color(0xFF667EEA), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Modifier le compte'),

          _ActionTile(
            icon: Icons.email_outlined,
            label: "Modifier l'email",
            onTap: () => _showChangeEmailDialog(context),
          ),
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Modifier le mot de passe',
            onTap: () => _showChangePasswordDialog(context),
          ),

          const SizedBox(height: 16),
          const _SectionLabel('Données'),

          _ActionTile(
            icon: Icons.download_outlined,
            label: 'Exporter mes données',
            onTap: () => _exportData(context),
          ),

          const SizedBox(height: 16),
          const _SectionLabel('Danger'),

          _ActionTile(
            icon: Icons.logout,
            label: 'Déconnexion',
            color: Colors.red,
            onTap: () => _showLogoutDialog(context),
          ),
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            label: 'Supprimer mon compte',
            color: Colors.red,
            onTap: () => _showDeleteAccountDialog(context),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Change email ────────────────────────────────────────────────────────────

  void _showChangeEmailDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Modifier l'email",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(controller: emailCtrl, label: 'Nouvel email'),
            const SizedBox(height: 12),
            _DialogField(
                controller: passwordCtrl,
                label: 'Mot de passe actuel',
                obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final db = DatabaseService();
                final api = ApiService(db);
                await api.changeEmail(
                    emailCtrl.text.trim(), passwordCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Email modifié'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }
            },
            child: const Text('Enregistrer',
                style: TextStyle(color: Color(0xFF667EEA))),
          ),
        ],
      ),
    );
  }

  // ── Change password ─────────────────────────────────────────────────────────

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Modifier le mot de passe',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(
                controller: currentCtrl,
                label: 'Mot de passe actuel',
                obscure: true),
            const SizedBox(height: 12),
            _DialogField(
                controller: newCtrl,
                label: 'Nouveau mot de passe',
                obscure: true),
            const SizedBox(height: 12),
            _DialogField(
                controller: confirmCtrl,
                label: 'Confirmer',
                obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                final db = DatabaseService();
                final api = ApiService(db);
                await api.changePassword(currentCtrl.text, newCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Mot de passe modifié'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }
            },
            child: const Text('Enregistrer',
                style: TextStyle(color: Color(0xFF667EEA))),
          ),
        ],
      ),
    );
  }

  // ── Export data ──────────────────────────────────────────────────────────────

  Future<void> _exportData(BuildContext context) async {
    try {
      final db = DatabaseService();
      final api = ApiService(db);
      final result = await api.exportData();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Export',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Text(
                result.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fermer',
                    style: TextStyle(color: Color(0xFF667EEA))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')),
        );
      }
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Déconnexion',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              context.read<SyncService>().stop();
              await context.read<AppState>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Déconnexion',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Delete account ───────────────────────────────────────────────────────────

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Supprimer mon compte',
            style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cette action est irréversible. Votre compte sera supprimé dans 30 jours.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _DialogField(
                controller: passwordCtrl,
                label: 'Mot de passe',
                obscure: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final syncService = context.read<SyncService>();
              final appState = context.read<AppState>();
              try {
                final db = DatabaseService();
                final api = ApiService(db);
                await api.deleteAccount(passwordCtrl.text);
                syncService.stop();
                await appState.logout();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (_) => false,
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erreur : $e')),
                );
              }
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF667EEA),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;

  const _DialogField({
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
