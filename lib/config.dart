class AppConfig {
  static const String apiBaseUrl = 'https://tronche.zordak.fr';
  static const String appName = 'Tronche!';
  static const Duration syncInterval = Duration(seconds: 30);
  static const Duration qrAutoReturnDelay = Duration(seconds: 15);
  static const Duration emailAutoReturnDelay = Duration(seconds: 5);
  static const Duration idleReturnDelay = Duration(seconds: 15);
  static const int defaultTimerDuration = 3;
}
