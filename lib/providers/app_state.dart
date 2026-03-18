import 'package:flutter/foundation.dart';
import '../models/event_config.dart';
import '../services/database_service.dart';

class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  bool _isInitialized = false;
  bool _isLoggedIn = false;
  EventConfig? _eventConfig;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  EventConfig? get eventConfig => _eventConfig;

  /// The current plan name ('free', 'premium', 'pro').
  String get plan => _eventConfig?.plan ?? 'free';

  /// Maximum photos allowed for the current plan.
  int get maxPhotos {
    switch (plan) {
      case 'premium':
        return 500;
      case 'pro':
        return -1; // unlimited
      default:
        return 100; // free
    }
  }

  /// Whether the given overlay template is allowed on the current plan.
  bool canUseOverlay(String template) {
    switch (template) {
      case 'elegant':
        return true; // available on all plans
      case 'minimal':
      case 'festive':
        return plan == 'premium' || plan == 'pro';
      default:
        return false;
    }
  }

  /// Loads EventConfig from SQLite and sets initialized state.
  Future<void> init() async {
    _eventConfig = await _db.getEventConfig();
    _isLoggedIn = _eventConfig != null && _eventConfig!.jwtToken.isNotEmpty;
    _isInitialized = true;
    notifyListeners();
  }

  /// Saves a new EventConfig to SQLite and updates state.
  Future<void> setEventConfig(EventConfig config) async {
    await _db.saveEventConfig(config);
    _eventConfig = config;
    _isLoggedIn = config.jwtToken.isNotEmpty;
    notifyListeners();
  }

  /// Applies a partial update map to the stored EventConfig.
  Future<void> updateEventConfig(Map<String, dynamic> updates) async {
    await _db.updateEventConfig(updates);
    // Reload the full config after the update so state stays consistent.
    _eventConfig = await _db.getEventConfig();
    notifyListeners();
  }

  /// Clears all local data and resets auth state.
  Future<void> logout() async {
    await _db.clearEventConfig();
    _eventConfig = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
