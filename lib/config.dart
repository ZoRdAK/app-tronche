import 'package:flutter/material.dart';

class AppConfig {
  static const String apiBaseUrl = 'https://tronche.net';
  static const String appName = 'Tronche!';
  static const Duration syncInterval = Duration(seconds: 30);
  static const Duration qrAutoReturnDelay = Duration(seconds: 15);
  static const Duration emailAutoReturnDelay = Duration(seconds: 5);
  static const Duration idleReturnDelay = Duration(seconds: 15);
  static const int defaultTimerDuration = 3;

  /// True only when running screenshot tests via --dart-define=SCREENSHOT_MODE=true
  static const bool isScreenshotMode =
      bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);
}

class AppColors {
  static const Color primaryPink = Color(0xFFE85B7A);
  static const Color orange = Color(0xFFF5A623);
  static const Color navy = Color(0xFF2C3E6B);
  static const Color turquoise = Color(0xFF5BC8C0);
  static const Color gold = Color(0xFFD4A843);
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1E1E2E);
  static const Color inputFill = Color(0xFF1A1A1A);
  static const Color inputBorder = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF555555);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFE57373);

  // Light theme colors (onboarding + admin)
  static const Color backgroundLight = Color(0xFFFDF8F4);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2C3E6B);
  static const Color textDarkSecondary = Color(0xFF555566);
  static const Color inputFillLight = Color(0xFFFFFFFF);
  static const Color inputBorderLight = Color(0xFFE0DDD8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, orange],
  );
}
