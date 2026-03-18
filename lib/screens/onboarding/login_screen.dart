import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/event_config.dart';
import '../booth/idle_screen.dart';
import 'event_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isForgotLoading = false;
  String? _errorMessage;

  bool get _isFormValid =>
      _emailCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = DatabaseService();
      final api = ApiService(db);
      final data = await api.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      final token = data['accessToken'] as String? ?? '';
      final refreshToken = data['refreshToken'] as String? ?? '';
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final plan = user['plan'] as String? ?? 'free';

      // Save a minimal config so the API interceptor can use the JWT token
      final tempConfig = EventConfig(
        userEmail: _emailCtrl.text.trim(),
        jwtToken: token,
        refreshToken: refreshToken,
        name1: '',
        name2: '',
        eventDate: '',
        adminPasswordHash: '',
        shareCode: '',
        plan: plan,
      );
      await db.saveEventConfig(tempConfig);

      // Try to fetch existing events
      Map<String, dynamic>? firstEvent;
      try {
        final events = await api.getEvents();
        if (events.isNotEmpty) {
          firstEvent = Map<String, dynamic>.from(events.first as Map);
        }
      } catch (_) {
        // If fetching events fails, proceed to event setup
      }

      if (!mounted) return;

      EventConfig config;
      if (firstEvent != null) {
        config = EventConfig(
          serverEventId: firstEvent['id'] as String?,
          userEmail: _emailCtrl.text.trim(),
          jwtToken: token,
          refreshToken: refreshToken,
          name1: firstEvent['name1'] as String? ?? '',
          name2: firstEvent['name2'] as String? ?? '',
          eventDate: firstEvent['event_date'] as String? ??
              firstEvent['eventDate'] as String? ??
              '',
          overlayTemplate:
              firstEvent['overlay_template'] as String? ?? 'elegant',
          timerDuration: firstEvent['timer_duration'] as int? ?? 3,
          adminPasswordHash:
              firstEvent['admin_password_hash'] as String? ?? '',
          shareCode: firstEvent['share_code'] as String? ?? '',
          plan: plan,
        );
      } else {
        config = EventConfig(
          userEmail: _emailCtrl.text.trim(),
          jwtToken: token,
          refreshToken: refreshToken,
          name1: '',
          name2: '',
          eventDate: '',
          adminPasswordHash: '',
          shareCode: '',
          plan: plan,
        );
      }

      await context.read<AppState>().setEventConfig(config);

      if (!mounted) return;

      if (firstEvent != null &&
          config.name1.isNotEmpty &&
          config.name2.isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const IdleScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EventSetupScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez votre email pour réinitialiser votre mot de passe.'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
      return;
    }

    setState(() => _isForgotLoading = true);
    try {
      final db = DatabaseService();
      final api = ApiService(db);
      await api.forgotPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Un email de réinitialisation a été envoyé à $email.'),
          backgroundColor: const Color(0xFF1E3A2A),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer l\'email. Réessayez plus tard.'),
          backgroundColor: Color(0xFF2A1010),
        ),
      );
    } finally {
      if (mounted) setState(() => _isForgotLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connexion',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Retrouvez votre photobooth.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 36),
                _buildLabel('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('votre@email.com'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildLabel('Mot de passe'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Votre mot de passe').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF555555),
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _isForgotLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF667EEA),
                          ),
                        )
                      : TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              color: Color(0xFF667EEA),
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1010),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7A2020)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFE57373), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Color(0xFFE57373), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF667EEA),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _isFormValid
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                  )
                                : null,
                            color: _isFormValid
                                ? null
                                : const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _isFormValid ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _isFormValid
                                    ? Colors.white
                                    : const Color(0xFF555555),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFCCCCCC),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF444444)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF667EEA), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE57373)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
