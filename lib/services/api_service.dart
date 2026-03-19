import 'package:dio/dio.dart';
import '../config.dart';
import 'database_service.dart';

class ApiService {
  late final Dio _dio;
  final DatabaseService _db;

  // Track whether we're currently refreshing to avoid infinite loops
  bool _isRefreshing = false;

  ApiService(this._db) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final config = await _db.getEventConfig();
        if (config != null && config.jwtToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${config.jwtToken}';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final newToken = await _doRefreshToken();
            if (newToken != null) {
              // Retry the original request with the new token
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(opts);
              handler.resolve(response);
              return;
            }
          } catch (_) {
            // Refresh failed — pass through the original error
          } finally {
            _isRefreshing = false;
          }
        }
        handler.next(error);
      },
    ));
  }

  // Internal refresh that returns the new token string or null
  Future<String?> _doRefreshToken() async {
    final config = await _db.getEventConfig();
    if (config == null || config.refreshToken.isEmpty) return null;

    final response = await _dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': config.refreshToken},
      options: Options(headers: {'Authorization': null}),
    );
    final token = response.data['accessToken'] as String?;
    final refreshToken = response.data['refreshToken'] as String?;
    if (token != null) {
      await _db.updateEventConfig({
        'jwt_token': token,
        if (refreshToken != null) 'refresh_token': refreshToken,
      });
    }
    return token;
  }

  // Auth

  Future<Map<String, dynamic>> register(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'email': email,
        'password': password,
        'cguAccepted': true,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Login failed');
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final config = await _db.getEventConfig();
      if (config == null) throw Exception('Not logged in');
      final response = await _dio.post('/api/auth/refresh', data: {
        'refreshToken': config.refreshToken,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Token refresh failed');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('/api/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw _formatError(e, 'Forgot password request failed');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _dio.post('/api/auth/reset-password', data: {
        'token': token,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw _formatError(e, 'Password reset failed');
    }
  }

  // Events

  Future<Map<String, dynamic>> createEvent({
    required String name1,
    required String name2,
    required String eventDate,
    required String adminPassword,
    required String overlayTemplate,
    required int timerDuration,
  }) async {
    try {
      final response = await _dio.post('/api/events', data: {
        'name1': name1,
        'name2': name2,
        'eventDate': eventDate,
        'adminPassword': adminPassword,
        'overlayTemplate': overlayTemplate,
        'timerDuration': timerDuration,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Event creation failed');
    }
  }

  Future<Map<String, dynamic>> updateEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.put('/api/events/$eventId', data: updates);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Event update failed');
    }
  }

  Future<List<dynamic>> getEvents() async {
    try {
      final response = await _dio.get('/api/events');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Failed to fetch events');
    }
  }

  // Photos

  /// Fetches the list of photos for an event from the server.
  Future<List<dynamic>> getEventPhotos(String eventId) async {
    try {
      final response = await _dio.get('/api/events/$eventId/photos');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Failed to fetch photos');
    }
  }

  /// Downloads a photo file from the server and saves it locally.
  /// Returns the local file path.
  Future<String> downloadPhoto(String photoCode, String savePath) async {
    try {
      await _dio.download(
        '/api/gallery/photo/$photoCode/full',
        savePath,
      );
      return savePath;
    } on DioException catch (e) {
      throw _formatError(e, 'Failed to download photo');
    }
  }

  /// Downloads a thumbnail from the server and saves it locally.
  Future<String> downloadThumbnail(String photoCode, String savePath) async {
    try {
      await _dio.download(
        '/api/gallery/photo/$photoCode/thumb',
        savePath,
      );
      return savePath;
    } on DioException catch (e) {
      throw _formatError(e, 'Failed to download thumbnail');
    }
  }

  Future<Map<String, dynamic>> uploadPhoto({
    required String eventId,
    required String filePath,
    required String takenAt,
  }) async {
    try {
      final formData = FormData.fromMap({
        'takenAt': takenAt,
        'photo': await MultipartFile.fromFile(
          filePath,
          contentType: DioMediaType('image', filePath.endsWith('.gif') ? 'gif' : 'jpeg'),
        ),
      });
      final response = await _dio.post(
        '/api/events/$eventId/photos',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Photo upload failed');
    }
  }

  // Queue

  Future<void> queueEmail({
    required String photoId,
    required String recipient,
  }) async {
    try {
      await _dio.post('/api/send-queue', data: {
        'type': 'email',
        'photoId': photoId,
        'recipient': recipient,
      });
    } on DioException catch (e) {
      throw _formatError(e, 'Email queue failed');
    }
  }

  // Account

  Future<void> changeEmail(String newEmail, String password) async {
    try {
      await _dio.put('/api/auth/email', data: {
        'newEmail': newEmail,
        'password': password,
      });
    } on DioException catch (e) {
      throw _formatError(e, 'Email change failed');
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _dio.put('/api/auth/password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw _formatError(e, 'Password change failed');
    }
  }

  Future<void> deleteAccount(String password) async {
    try {
      await _dio.delete('/api/auth/account', data: {'password': password});
    } on DioException catch (e) {
      throw _formatError(e, 'Account deletion failed');
    }
  }

  Future<Map<String, dynamic>> exportData() async {
    try {
      final response = await _dio.get('/api/auth/export');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw _formatError(e, 'Data export failed');
    }
  }

  // Helpers

  Exception _formatError(DioException e, String fallback) {
    final statusCode = e.response?.statusCode;
    final message = e.response?.data is Map
        ? (e.response!.data['message'] ?? e.response!.data['error'] ?? fallback)
        : fallback;
    if (statusCode == 409) {
      return Exception('Cet email est déjà utilisé.');
    }
    if (statusCode == 401) {
      return Exception('Email ou mot de passe incorrect.');
    }
    if (statusCode == 400) {
      return Exception('Vérifiez les informations saisies.');
    }
    if (statusCode == 403) {
      return Exception('Limite atteinte pour votre offre.');
    }
    if (statusCode == 404) {
      return Exception('Ressource introuvable.');
    }
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
      return Exception('Impossible de se connecter au serveur. Vérifiez votre connexion.');
    }
    return Exception(message);
  }
}
