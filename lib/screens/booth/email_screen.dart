import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/send_queue_item.dart';
import '../../services/database_service.dart';
import 'idle_screen.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo ajoutée à la file d\'envoi !'),
          backgroundColor: Color(0xFF1E3A2A),
        ),
      );

      // Auto-return after 5 seconds
      _autoReturnTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _autoReturnSeconds--);
        if (_autoReturnSeconds <= 0) {
          _autoReturnTimer?.cancel();
          _goToIdle();
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

  void _goToIdle() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const IdleScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white54, size: 16),
                label: const Text('Retour',
                    style: TextStyle(color: Colors.white54)),
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
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF667EEA), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre email sera uniquement utilisé pour vous envoyer cette photo.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSending
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF667EEA)),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _isEmailValid
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                  )
                                : null,
                            color: _isEmailValid
                                ? null
                                : const Color(0xFF2A2A2A),
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
                                    : const Color(0xFF555555),
                              ),
                            ),
                          ),
                        ),
                ),
              ] else ...[
                // Sent confirmation
                const Center(
                  child: Icon(Icons.check_circle_outline,
                      color: Color(0xFF4CAF50), size: 80),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Photo en route !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'La photo sera envoyée dès que possible.',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Retour dans ${_autoReturnSeconds}s',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _goToIdle,
                    child: const Text(
                      'Retour à l\'accueil →',
                      style: TextStyle(
                          color: Color(0xFF667EEA), fontSize: 16),
                    ),
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
