import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../providers/app_state.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<AppState>().plan;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.inputFill,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mon abonnement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current plan badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _planLabel(plan),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Feature comparison
          const Text(
            'Ce qui est inclus',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          _PlanCard(
            name: 'Gratuit',
            color: Colors.white38,
            features: const [
              'Jusqu\'à 100 photos',
              'Cadre Élégant',
              'QR Code par photo',
              'Galerie en ligne',
            ],
            isCurrentPlan: plan == 'free',
          ),
          const SizedBox(height: 12),

          _PlanCard(
            name: 'Premium',
            color: AppColors.primaryPink,
            features: const [
              'Jusqu\'à 500 photos',
              'Tous les cadres',
              'QR Code + Email',
              'Galerie personnalisée',
              'Sans filigrane',
            ],
            isCurrentPlan: plan == 'premium',
          ),
          const SizedBox(height: 12),

          _PlanCard(
            name: 'Pro',
            color: AppColors.orange,
            features: const [
              'Photos illimitées',
              'Tous les cadres',
              'QR Code + Email',
              'Galerie personnalisée',
              'Sans filigrane',
              'Support prioritaire',
              'Export ZIP',
            ],
            isCurrentPlan: plan == 'pro',
          ),

          const SizedBox(height: 32),

          // IAP placeholder
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryPink.withAlpha(80)),
            ),
            child: Column(
              children: [
                const Icon(Icons.diamond_outlined,
                    color: AppColors.primaryPink, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Les achats in-app seront disponibles prochainement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Revenez bientôt pour accéder aux offres Premium et Pro.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (plan == 'free') ...[
                  _UpgradeButton(
                    label: 'Passer en Premium',
                    color: AppColors.primaryPink,
                    onTap: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: 8),
                  _UpgradeButton(
                    label: 'Passer en Pro',
                    color: AppColors.orange,
                    onTap: () => _showComingSoon(context),
                  ),
                ] else if (plan == 'premium')
                  _UpgradeButton(
                    label: 'Passer en Pro',
                    color: AppColors.orange,
                    onTap: () => _showComingSoon(context),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'premium':
        return 'Premium';
      case 'pro':
        return 'Pro';
      default:
        return 'Gratuit';
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Les achats in-app seront disponibles prochainement'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String name;
  final Color color;
  final List<String> features;
  final bool isCurrentPlan;

  const _PlanCard({
    required this.name,
    required this.color,
    required this.features,
    required this.isCurrentPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentPlan
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isCurrentPlan) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Actuel',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _UpgradeButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
