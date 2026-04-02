import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  AppConstants._();

  // Web uses localhost; Android emulator uses 10.0.2.2 (host loopback).
  // For a physical device, set your PC's LAN IP in a custom build or env.
  static String get apiBaseUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  static const String apiPrefix = '/api/v1';

  static const String tokenKey = 'pillpal_jwt_token';
  static const String userKey = 'pillpal_user';

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 60);
}
