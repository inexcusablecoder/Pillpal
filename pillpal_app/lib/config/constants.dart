class AppConstants {
  AppConstants._();

  // Change this to your deployed backend URL.
  // For Android emulator use 10.0.2.2 (maps to host localhost).
  // For physical device use your machine's LAN IP.
  static const String apiBaseUrl = 'http://10.0.2.2:8000';
  static const String apiPrefix = '/api/v1';

  static const String tokenKey = 'pillpal_jwt_token';
  static const String userKey = 'pillpal_user';

  static const Duration animDuration = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 60);
}
