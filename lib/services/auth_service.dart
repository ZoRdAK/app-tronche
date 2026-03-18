import '../models/event_config.dart';
import 'api_service.dart';
import 'database_service.dart';

class AuthService {
  final DatabaseService _db;
  final ApiService _api;

  AuthService(this._db, this._api);

  /// Returns true if an EventConfig (with a valid token) exists in SQLite.
  Future<bool> get isLoggedIn async {
    final config = await _db.getEventConfig();
    return config != null && config.jwtToken.isNotEmpty;
  }

  /// Returns the current JWT token, or null if not logged in.
  Future<String?> getToken() async {
    final config = await _db.getEventConfig();
    return config?.jwtToken;
  }

  /// Registers a new account.
  /// Saves the returned tokens and creates a minimal EventConfig shell in SQLite.
  Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final data = await _api.register(email, password);

    final token = data['token'] as String? ?? '';
    final refreshToken = data['refreshToken'] as String? ?? '';

    // Create a minimal EventConfig shell so isLoggedIn returns true.
    // The user will complete event setup on the next screen.
    final shell = EventConfig(
      userEmail: email,
      jwtToken: token,
      refreshToken: refreshToken,
      name1: '',
      name2: '',
      eventDate: '',
      adminPasswordHash: '',
      shareCode: '',
      plan: data['plan'] as String? ?? 'free',
    );
    await _db.saveEventConfig(shell);

    return data;
  }

  /// Logs in with an existing account.
  /// Saves tokens and loads the first existing event if any.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.login(email, password);

    final token = data['token'] as String? ?? '';
    final refreshToken = data['refreshToken'] as String? ?? '';

    // Check if a config already exists (e.g. from a previous session).
    final existing = await _db.getEventConfig();
    if (existing != null) {
      await _db.saveEventConfig(
        existing.copyWith(jwtToken: token, refreshToken: refreshToken),
      );
    } else {
      // Store tokens in a minimal shell; event data will be fetched/set later.
      final shell = EventConfig(
        userEmail: email,
        jwtToken: token,
        refreshToken: refreshToken,
        name1: '',
        name2: '',
        eventDate: '',
        adminPasswordHash: '',
        shareCode: '',
        plan: data['plan'] as String? ?? 'free',
      );
      await _db.saveEventConfig(shell);
    }

    return data;
  }

  /// Clears all local data (logs out).
  Future<void> logout() async {
    await _db.clearEventConfig();
  }

  /// Refreshes the JWT using the stored refresh token.
  /// Updates the stored tokens and returns the new JWT.
  Future<String> refreshToken() async {
    final data = await _api.refreshToken();
    final token = data['token'] as String? ?? '';
    final refreshToken = data['refreshToken'] as String?;

    await _db.updateEventConfig({
      'jwt_token': token,
      if (refreshToken != null) 'refresh_token': refreshToken,
    });

    return token;
  }
}
