import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';
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
    if (_input.length >= 6) return;
    setState(() => _input += digit);
    if (_input.length >= 4) {
      _trySubmit();
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _trySubmit() {
    final config = context.read<AppState>().eventConfig;
    if (config == null) return;

    final inputHash = sha256.convert(utf8.encode(_input)).toString();
    if (inputHash == config.adminPasswordHash) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else if (_input.length >= 6) {
      _failedAttempt();
    }
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
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Administration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Code administrateur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Saisissez votre code PIN',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 40),
            // PIN dots with shake animation
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
                  children: List.generate(6, (i) {
                    final filled = i < _input.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? const Color(0xFF667EEA)
                            : const Color(0xFF2A2A2A),
                        border: Border.all(
                          color: filled
                              ? const Color(0xFF667EEA)
                              : const Color(0xFF444444),
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
                      color: Colors.white70, size: 24),
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
          foregroundColor: Colors.white,
        ),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
