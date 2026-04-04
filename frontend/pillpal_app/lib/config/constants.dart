import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  AppConstants._();

  // Web: localhost; Android emulator: 10.0.2.2. Optional: --dart-define=API_BASE_URL=...
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }
  static const String apiPrefix = '/api/v1';

  static const String tokenKey = 'pillpal_jwt_token';
  static const String userKey = 'pillpal_user';

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 60);
}
