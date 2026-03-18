import 'dart:async';
import 'package:flutter/material.dart';
import '../../config.dart';
import '../../models/send_queue_item.dart';
import '../../services/database_service.dart';
import 'camera_screen.dart';

class EmailScreen extends StatefulWidget {
  final String photoCode;
  final int photoId;

  const EmailScreen({
    super.key,
    required this.photoCode,
    required this.photoId,
  });

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _emailCtrl = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  int _autoReturnSeconds = 5;
  Timer? _autoReturnTimer;

  bool get _isEmailValid {
    final email = _emailCtrl.text.trim();
    return email.contains('@') && email.contains('.');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _autoReturnTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_isEmailValid || _isSending) return;
    setState(() => _isSending = true);

    try {
      final db = DatabaseService();
      await db.insertSendQueueItem(SendQueueItem(
        photoId: widget.photoId,
        type: 'email',
        recipient: _emailCtrl.text.trim(),
        createdAt: DateTime.now(),
      ));

      if (!mounted) return;
      setState(() {
        _sent = true;
        _isSending = false;
      });

      // Bug 7 fix: No SnackBar — success is shown directly in the UI

      // Bug 8 fix: Auto-return countdown to camera (not idle)
      _autoReturnTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _autoReturnSeconds--);
        if (_autoReturnSeconds <= 0) {
          _autoReturnTimer?.cancel();
          _goToCamera();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFF2A1010),
          ),
        );
      }
    }
  }

  void _goToCamera() {
    if (!mounted) return;
    // Bug 8 fix: navigate back to CameraScreen instead of idle
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white54, size: 16),
                  label: const Text('Retour',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
              const Spacer(),

              if (!_sent) ...[
                const Text(
                  'Recevez votre photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Email field
                TextField(
                  controller: _emailCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'votre@email.com',
                    hintStyle: const TextStyle(
                        color: Color(0xFF333333), fontSize: 22),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primaryPink, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre email sera uniquement utilise pour vous envoyer cette photo.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSending
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryPink),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _isEmailValid
                                ? AppColors.primaryGradient
                                : null,
                            color: _isEmailValid
                                ? null
                                : AppColors.inputBorder,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _isEmailValid ? _send : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Envoyer',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _isEmailValid
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                ),
              ] else ...[
                // Sent confirmation (Bug 7: shown directly, no snackbar)
                const Icon(Icons.check_circle_outline,
                    color: Color(0xFF4CAF50), size: 80),
                const SizedBox(height: 24),
                const Text(
                  'Photo en route !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La photo sera envoyee des que possible.',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Bug 8 fix: visible live countdown
                Text(
                  'Retour dans ${_autoReturnSeconds}s...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _goToCamera,
                  child: const Text(
                    'Prendre une autre photo',
                    style: TextStyle(
                        color: AppColors.primaryPink, fontSize: 16),
                  ),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
