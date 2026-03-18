import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // App logo with gradient fallback
              Image.asset(
                'assets/logo.png',
                width: 280,
                errorBuilder: (_, __, ___) => ShaderMask(
                  shaderCallback: (bounds) => AppColors.primaryGradient
                      .createShader(bounds),
                  child: const Text(
                    'Tronche!',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Le photobooth de votre mariage',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              // Primary CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Créer mon photobooth',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Secondary link
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  "J'ai déjà un compte",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryPink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              // Legal footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openUrl('https://tronche.zordak.fr/legal/cgu'),
                    child: const Text(
                      'CGU',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Text(
                    '·',
                    style: TextStyle(color: Color(0xFF444444)),
                  ),
                  TextButton(
                    onPressed: () =>
                        _openUrl('https://tronche.zordak.fr/legal/privacy'),
                    child: const Text(
                      'Politique de confidentialité',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
