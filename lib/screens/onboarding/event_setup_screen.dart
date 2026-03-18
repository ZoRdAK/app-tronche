import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../config.dart';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/event_config.dart';
import '../booth/idle_screen.dart';

class EventSetupScreen extends StatefulWidget {
  const EventSetupScreen({super.key});

  @override
  State<EventSetupScreen> createState() => _EventSetupScreenState();
}

class _EventSetupScreenState extends State<EventSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name1Ctrl = TextEditingController();
  final _name2Ctrl = TextEditingController();
  final _adminPwCtrl = TextEditingController();

  DateTime? _eventDate;
  String _overlayTemplate = 'elegant';
  int _timerDuration = 3;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isFormValid {
    if (_name1Ctrl.text.trim().isEmpty) return false;
    if (_name2Ctrl.text.trim().isEmpty) return false;
    if (_eventDate == null) return false;
    final pw = _adminPwCtrl.text.trim();
    if (pw.length < 4 || pw.length > 6) return false;
    return true;
  }

  @override
  void dispose() {
    _name1Ctrl.dispose();
    _name2Ctrl.dispose();
    _adminPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPink,
              onPrimary: Colors.white,
              surface: AppColors.backgroundLight,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _eventDate == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appState = context.read<AppState>();
      final db = DatabaseService();
      final api = ApiService(db);

      final eventDateStr =
          '${_eventDate!.year.toString().padLeft(4, '0')}-'
          '${_eventDate!.month.toString().padLeft(2, '0')}-'
          '${_eventDate!.day.toString().padLeft(2, '0')}';

      final adminPw = _adminPwCtrl.text.trim();
      final adminPwHash =
          sha256.convert(utf8.encode(adminPw)).toString();

      final eventData = await api.createEvent(
        name1: _name1Ctrl.text.trim(),
        name2: _name2Ctrl.text.trim(),
        eventDate: eventDateStr,
        adminPassword: adminPw,
        overlayTemplate: _overlayTemplate,
        timerDuration: _timerDuration,
      );

      final existing = appState.eventConfig;
      final config = EventConfig(
        serverEventId: eventData['id'] as String? ??
            eventData['event']?['id'] as String?,
        userEmail: existing?.userEmail ?? '',
        jwtToken: existing?.jwtToken ?? '',
        refreshToken: existing?.refreshToken ?? '',
        name1: _name1Ctrl.text.trim(),
        name2: _name2Ctrl.text.trim(),
        eventDate: eventDateStr,
        overlayTemplate: _overlayTemplate,
        timerDuration: _timerDuration,
        adminPasswordHash: adminPwHash,
        shareCode: eventData['share_code'] as String? ??
            eventData['shareCode'] as String? ??
            eventData['event']?['share_code'] as String? ??
            '',
        plan: existing?.plan ?? 'free',
      );

      if (!mounted) return;
      await appState.setEventConfig(config);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IdleScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Configuration',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurez votre photobooth',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 32),

                // Names
                _buildLabel('Prénom partenaire 1'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name1Ctrl,
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: _inputDecoration('Marie'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Prénom partenaire 2'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name2Ctrl,
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: _inputDecoration('Thomas'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                ),
                const SizedBox(height: 20),

                // Date picker
                _buildLabel('Date de l\'événement'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.inputFillLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primaryPink, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _eventDate == null
                              ? 'Sélectionner une date'
                              : '${_eventDate!.day.toString().padLeft(2, '0')}.'
                                  '${_eventDate!.month.toString().padLeft(2, '0')}.'
                                  '${_eventDate!.year}',
                          style: TextStyle(
                            color: _eventDate == null
                                ? AppColors.textDarkSecondary
                                : AppColors.textDark,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Overlay template selector
                _buildLabel('Style de l\'overlay'),
                const SizedBox(height: 12),
                _OverlayTemplateSelector(
                  selected: _overlayTemplate,
                  onChanged: (t) => setState(() => _overlayTemplate = t),
                ),
                const SizedBox(height: 28),

                // Timer duration
                _buildLabel('Durée du compte à rebours'),
                const SizedBox(height: 12),
                Row(
                  children: [3, 5, 10].map((d) {
                    final isSelected = _timerDuration == d;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _timerDuration = d),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? AppColors.primaryGradient
                                  : null,
                              color: isSelected
                                  ? null
                                  : AppColors.inputFillLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : AppColors.inputBorderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${d}s',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textDarkSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Admin password
                _buildLabel('Code admin (4 à 6 chiffres)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _adminPwCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                    color: AppColors.textDark,
                    letterSpacing: 8,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration('• • • •'),
                  validator: (v) {
                    if (v == null || v.length < 4) {
                      return 'Minimum 4 chiffres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ce code protège l\'accès admin contre les invités curieux.',
                  style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withAlpha(120)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryPink),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: _isFormValid
                                ? AppColors.primaryGradient
                                : null,
                            color: _isFormValid
                                ? null
                                : AppColors.inputBorderLight,
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
                              'Lancer le photobooth !',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _isFormValid
                                    ? Colors.white
                                    : AppColors.textDarkSecondary,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),
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
        color: AppColors.textDark,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDarkSecondary),
      filled: true,
      fillColor: AppColors.inputFillLight,
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
        borderSide: const BorderSide(color: AppColors.primaryPink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _OverlayTemplateSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _OverlayTemplateSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final templates = [
      _OverlayOption(
        id: 'elegant',
        name: 'Élégant',
        description: 'Sérif, centré',
        icon: Icons.auto_awesome,
        locked: false,
      ),
      _OverlayOption(
        id: 'minimal',
        name: 'Minimal',
        description: 'Sans-sérif',
        icon: Icons.minimize,
        locked: true,
      ),
      _OverlayOption(
        id: 'festive',
        name: 'Festif',
        description: 'Emojis, fun',
        icon: Icons.celebration,
        locked: true,
      ),
    ];

    return Row(
      children: templates.map((t) {
        final isSelected = selected == t.id;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: t.locked ? null : () => onChanged(t.id),
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? AppColors.primaryGradient
                      : null,
                  color: isSelected ? null : AppColors.inputFillLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.inputBorderLight,
                  ),
                  boxShadow: isSelected
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            t.icon,
                            color: t.locked
                                ? AppColors.inputBorderLight
                                : isSelected
                                    ? Colors.white
                                    : AppColors.textDarkSecondary,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.name,
                            style: TextStyle(
                              color: t.locked
                                  ? AppColors.inputBorderLight
                                  : isSelected
                                      ? Colors.white
                                      : AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            t.description,
                            style: TextStyle(
                              color: t.locked
                                  ? AppColors.inputBorderLight
                                  : isSelected
                                      ? Colors.white70
                                      : AppColors.textDarkSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t.locked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.inputBorderLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: AppColors.textDarkSecondary,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OverlayOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool locked;

  const _OverlayOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.locked,
  });
}
