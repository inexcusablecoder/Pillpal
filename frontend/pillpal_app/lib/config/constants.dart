import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  AppConstants._();

  // Web uses localhost; Android emulator uses 10.0.2.2 (host loopback).
  // Override at build time: --dart-define=API_BASE_URL=http://127.0.0.1:8001
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }
  static const String apiPrefix = '/api/v1';

  static const String tokenKey = 'pillpal_jwt_token';
  static const String userKey = 'pillpal_user';

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 60);
}
