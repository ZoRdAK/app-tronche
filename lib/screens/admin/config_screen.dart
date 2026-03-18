import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../providers/app_state.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _name1Controller;
  late TextEditingController _name2Controller;
  late TextEditingController _adminPasswordController;

  String _overlayTemplate = 'elegant';
  int _timerDuration = 3;
  DateTime? _eventDate;

  bool _isSaving = false;

  static const _overlayOptions = ['elegant', 'minimal', 'festive'];
  static const _timerOptions = [3, 5, 10];

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().eventConfig;
    _name1Controller = TextEditingController(text: config?.name1 ?? '');
    _name2Controller = TextEditingController(text: config?.name2 ?? '');
    _adminPasswordController = TextEditingController();
    _overlayTemplate = config?.overlayTemplate ?? 'elegant';
    _timerDuration = config?.timerDuration ?? 3;
    if (config?.eventDate != null) {
      try {
        _eventDate = DateTime.parse(config!.eventDate);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _name1Controller.dispose();
    _name2Controller.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appState = context.read<AppState>();
      final config = appState.eventConfig!;

      final updates = <String, dynamic>{
        'name1': _name1Controller.text.trim(),
        'name2': _name2Controller.text.trim(),
        'event_date': _eventDate!.toIso8601String(),
        'overlay_template': _overlayTemplate,
        'timer_duration': _timerDuration,
      };

      if (_adminPasswordController.text.isNotEmpty) {
        updates['admin_password_hash'] =
            sha256.convert(utf8.encode(_adminPasswordController.text)).toString();
      }

      // Update local SQLite.
      await appState.updateEventConfig(updates);

      // Try to sync to server (best-effort).
      if (config.serverEventId != null) {
        try {
          final db = DatabaseService();
          final api = ApiService(db);
          await api.updateEvent(config.serverEventId!, {
            'name1': updates['name1'],
            'name2': updates['name2'],
            'eventDate': updates['event_date'],
            'overlayTemplate': updates['overlay_template'],
            'timerDuration': updates['timer_duration'],
          });
        } catch (_) {
          // Non-blocking: local save succeeded, server sync will retry later.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration enregistrée'),
            backgroundColor: Colors.green,
          ),
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
    final appState = context.watch<AppState>();

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
          'Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Prénoms'),
            _Field(
              controller: _name1Controller,
              label: 'Prénom 1',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _name2Controller,
              label: 'Prénom 2',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),

            const SizedBox(height: 20),
            _SectionLabel("Date de l'événement"),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Color(0xFF667EEA), size: 18),
                    const SizedBox(width: 12),
                    Text(
                      _eventDate != null
                          ? '${_eventDate!.day.toString().padLeft(2, '0')}/'
                              '${_eventDate!.month.toString().padLeft(2, '0')}/'
                              '${_eventDate!.year}'
                          : 'Choisir une date',
                      style: TextStyle(
                        color: _eventDate != null
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _SectionLabel('Modèle de cadre'),
            Row(
              children: _overlayOptions.map((option) {
                final locked = !appState.canUseOverlay(option);
                final selected = _overlayTemplate == option;
                return Expanded(
                  child: GestureDetector(
                    onTap: locked
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Disponible en Premium / Pro')),
                            )
                        : () => setState(() => _overlayTemplate = option),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF667EEA).withAlpha(40)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF667EEA)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (locked)
                            const Icon(Icons.lock,
                                color: Colors.white38, size: 14)
                          else
                            const SizedBox(height: 14),
                          const SizedBox(height: 4),
                          Text(
                            option[0].toUpperCase() + option.substring(1),
                            style: TextStyle(
                              color: locked ? Colors.white38 : Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _SectionLabel('Durée du compte à rebours'),
            Row(
              children: _timerOptions.map((seconds) {
                final selected = _timerDuration == seconds;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _timerDuration = seconds),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF667EEA).withAlpha(40)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF667EEA)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${seconds}s',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF667EEA)
                              : Colors.white,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _SectionLabel('Code administrateur (laisser vide pour ne pas changer)'),
            TextFormField(
              controller: _adminPasswordController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '4 à 6 chiffres',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null; // Optional
                if (v.length < 4) return 'Minimum 4 chiffres';
                return null;
              },
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
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
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }
}
