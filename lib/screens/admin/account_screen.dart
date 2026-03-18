import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mon compte',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current email
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppColors.primaryPink, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(color: AppColors.textDark),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ChangeEmailScreen(currentEmail: email),
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Modifier le mot de passe',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _ChangePasswordScreen(),
              ),
            ),
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

          const SizedBox(height: 32),
          const Text(
            'Tronche! v1.0.0',
            style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
            backgroundColor: AppColors.backgroundLight,
            title: const Text('Export',
                style: TextStyle(color: AppColors.textDark)),
            content: SingleChildScrollView(
              child: Text(
                result.toString(),
                style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fermer',
                    style: TextStyle(color: AppColors.primaryPink)),
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
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Déconnexion',
            style: TextStyle(color: AppColors.textDark)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textDarkSecondary)),
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
        backgroundColor: AppColors.backgroundLight,
        title: const Text('Supprimer mon compte',
            style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cette action est irréversible. Votre compte sera supprimé dans 30 jours.',
              style: TextStyle(color: AppColors.textDarkSecondary),
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
                style: TextStyle(color: AppColors.textDarkSecondary)),
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
// Change Email Screen
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeEmailScreen extends StatefulWidget {
  final String currentEmail;
  const _ChangeEmailScreen({required this.currentEmail});

  @override
  State<_ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<_ChangeEmailScreen> {
  final _newEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un email valide')),
      );
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez votre mot de passe')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      final api = ApiService(db);
      await api.changeEmail(newEmail, _passwordCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Email modifié'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          "Modifier l'email",
          style: TextStyle(
              color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Current email (read-only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.inputBorderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.currentEmail,
              style: const TextStyle(
                  color: AppColors.textDarkSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 20),

          _FullPageField(
            controller: _newEmailCtrl,
            label: 'Nouvel email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _FullPageField(
            controller: _passwordCtrl,
            label: 'Mot de passe actuel',
            obscure: true,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
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
// Change Password Screen
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_currentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez votre mot de passe actuel')),
      );
      return;
    }
    if (_newCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Le nouveau mot de passe doit faire au moins 6 caractères')),
      );
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final db = DatabaseService();
      final api = ApiService(db);
      await api.changePassword(_currentCtrl.text, _newCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mot de passe modifié'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Modifier le mot de passe',
          style: TextStyle(
              color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _FullPageField(
            controller: _currentCtrl,
            label: 'Mot de passe actuel',
            obscure: true,
          ),
          const SizedBox(height: 16),
          _FullPageField(
            controller: _newCtrl,
            label: 'Nouveau mot de passe',
            obscure: true,
          ),
          const SizedBox(height: 16),
          _FullPageField(
            controller: _confirmCtrl,
            label: 'Confirmer le nouveau mot de passe',
            obscure: true,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
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
            color: AppColors.textDarkSecondary,
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
    this.color = AppColors.primaryPink,
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
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textDarkSecondary),
        onTap: onTap,
      ),
    );
  }
}

class _FullPageField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;

  const _FullPageField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDarkSecondary),
        filled: true,
        fillColor: AppColors.cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryPink, width: 1.5),
        ),
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
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDarkSecondary),
        filled: true,
        fillColor: AppColors.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.inputBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primaryPink, width: 1.5),
        ),
      ),
    );
  }
}
