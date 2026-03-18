import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../providers/app_state.dart';

class OnlineGalleryScreen extends StatelessWidget {
  const OnlineGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppState>().eventConfig;
    final shareCode = config?.shareCode ?? '';
    final galleryUrl = 'https://tronche.zordak.fr/g/$shareCode';

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
          'Galerie en ligne',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: shareCode.isEmpty
          ? const Center(
              child: Text(
                'Code de partage non disponible',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Partagez votre galerie',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vos invités peuvent scanner ce QR code pour accéder à toutes les photos',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // QR code
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: galleryUrl,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // URL display
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    galleryUrl,
                    style: const TextStyle(
                      color: AppColors.primaryPink,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // Copy button
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: galleryUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lien copié dans le presse-papiers'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text(
                    'Copier le lien',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Open in browser
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(galleryUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser,
                      color: AppColors.primaryPink),
                  label: const Text(
                    'Ouvrir dans le navigateur',
                    style: TextStyle(color: AppColors.primaryPink),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryPink),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Share code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Code : ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      Text(
                        shareCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
