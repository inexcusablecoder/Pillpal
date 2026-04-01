/// FastAPI base URL (no trailing slash).
///
/// **Android emulator:** `10.0.2.2` maps to your PC’s localhost where uvicorn runs.
///
/// **Physical phone:** same Wi‑Fi as PC, use PC LAN IP, e.g.
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`
///
/// **Production:** your deployed HTTPS API.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get origin => baseUrl.replaceAll(RegExp(r'/$'), '');
}
