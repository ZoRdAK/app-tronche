import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';
import '../../config.dart';
import '../../providers/app_state.dart';
import 'dashboard_screen.dart';

/// Admin gate: numeric PIN entry (4-6 digits) that verifies against the
/// stored admin password hash in EventConfig.
class AdminGateScreen extends StatefulWidget {
  const AdminGateScreen({super.key});

  @override
  State<AdminGateScreen> createState() => _AdminGateScreenState();
}

class _AdminGateScreenState extends State<AdminGateScreen>
    with SingleTickerProviderStateMixin {
  String _input = '';
  AnimationController? _shakeController;
  Animation<double>? _shakeAnim;

  // Bug 9: Support 4-6 digit PINs
  static const int _minDigits = 4;
  static const int _maxDigits = 6;

  @override
  void initState() {
    super.initState();
    // Disable wakelock when entering admin screens.
    WakelockPlus.disable();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _shakeController!, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    super.dispose();
  }

  void _onKey(String digit) {
    if (_input.length >= _maxDigits) return;
    setState(() => _input += digit);
    // Bug 9: Auto-submit after each digit from 4 onwards
    if (_input.length >= _minDigits) {
      _trySubmit();
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  /// Check if PIN was never properly set (empty hash or default "0000" hash)
  bool get _needsSetup {
    final config = context.read<AppState>().eventConfig;
    if (config == null) return true;
    final defaultHash = sha256.convert(utf8.encode('0000')).toString();
    return config.adminPasswordHash.isEmpty || config.adminPasswordHash == defaultHash;
  }

  void _trySubmit() {
    final config = context.read<AppState>().eventConfig;
    if (config == null) return;

    if (_needsSetup) {
      // First time: save this PIN as the new admin code
      _saveNewPin();
      return;
    }

    final inputHash = sha256.convert(utf8.encode(_input)).toString();
    if (inputHash == config.adminPasswordHash) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (_input.length >= _maxDigits) {
      _failedAttempt();
    }
  }

  Future<void> _saveNewPin() async {
    final pinHash = sha256.convert(utf8.encode(_input)).toString();
    await context.read<AppState>().updateEventConfig({'admin_password_hash': pinHash});
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _failedAttempt() {
    HapticFeedback.heavyImpact();
    _shakeController?.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _input = '');
    });
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
          'Administration',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _needsSetup ? 'Créez votre code' : 'Code administrateur',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _needsSetup
                  ? 'Choisissez un code PIN (4-6 chiffres) pour protéger l\'espace admin'
                  : 'Saisissez votre code PIN (4-6 chiffres)',
              style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Bug 9: PIN dots (4-6) with shake animation
            AnimatedBuilder(
              animation: _shakeAnim ?? const AlwaysStoppedAnimation(0),
              builder: (_, __) => Transform.translate(
                offset: Offset(
                  _shakeAnim != null
                      ? (_shakeAnim!.value * ((_shakeController!.value > 0.5) ? -1 : 1))
                      : 0,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_maxDigits, (i) {
                    final filled = i < _input.length;
                    // Dots 0-3 are always visible, dots 4-5 appear when needed
                    final isOptional = i >= _minDigits;
                    final showDot = !isOptional || _input.length > i - 1;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: showDot ? 1.0 : 0.3,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? AppColors.primaryPink
                              : AppColors.inputBorderLight,
                          border: Border.all(
                            color: filled
                                ? AppColors.primaryPink
                                : AppColors.inputBorderLight,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 48),
            // Numeric keypad
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        children: [
          _buildKeyRow(['1', '2', '3']),
          _buildKeyRow(['4', '5', '6']),
          _buildKeyRow(['7', '8', '9']),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80),
              _buildKey('0'),
              SizedBox(
                width: 80,
                height: 64,
                child: IconButton(
                  onPressed: _onDelete,
                  icon: const Icon(Icons.backspace_outlined,
                      color: AppColors.textDarkSecondary, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map(_buildKey).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: () => _onKey(digit),
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          foregroundColor: AppColors.textDark,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
