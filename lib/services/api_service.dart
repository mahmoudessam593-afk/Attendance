import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Points at the public API on prodserver, reachable at its static public
  // IP over HTTPS with a real ZeroSSL certificate issued for that IP
  // directly (not a domain - see backend/deploy/README.md). Nginx there
  // terminates TLS on 8443 (port 443 itself is taken by an unrelated
  // service on that shared box); the router's port-forward maps external
  // 443 to internal 8443, so no port number is needed here. Before a real
  // production release this should come from build configuration (e.g.
  // --dart-define), not be hardcoded.
  static const String baseUrl = 'https://41.33.109.20/api';

  /// The API's unauthenticated liveness endpoint, sitting outside the /api
  /// prefix - used by the splash screen to detect "server unreachable /
  /// under maintenance" before the user attempts to log in or check in.
  static String get healthUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '/health');

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _storage.delete(key: 'auth_token');
        }
        return handler.next(error);
      },
    ));
  }

  Dio get client => _dio;
}