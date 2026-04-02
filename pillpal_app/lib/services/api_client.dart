import 'package:dio/dio.dart';
import '../config/constants.dart';
import 'storage_service.dart';

class ApiClient {
  static ApiClient? _instance;
  late Dio _dio;
  StorageService? _storage;
  void Function()? onUnauthorized;

  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConstants.apiBaseUrl}${AppConstants.apiPrefix}',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          _storage ??= await StorageService.getInstance();
          final token = _storage!.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  Dio get dio => _dio;

  // ── Auth ──────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      if (displayName != null) 'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Users ─────────────────────────────────────────

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/users/me');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe({String? displayName}) async {
    final response = await _dio.patch('/users/me', data: {
      if (displayName != null) 'display_name': displayName,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Medicines ─────────────────────────────────────

  Future<List<dynamic>> listMedicines({bool activeOnly = false}) async {
    final response = await _dio.get('/medicines', queryParameters: {
      if (activeOnly) 'active_only': true,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createMedicine({
    required String name,
    required String dosage,
    required String scheduledTime,
    String frequency = 'daily',
    bool active = true,
    int? pillCount,
  }) async {
    final response = await _dio.post('/medicines', data: {
      'name': name,
      'dosage': dosage,
      'scheduled_time': scheduledTime,
      'frequency': frequency,
      'active': active,
      if (pillCount != null) 'pill_count': pillCount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMedicine(
    String id, {
    String? name,
    String? dosage,
    String? scheduledTime,
    String? frequency,
    bool? active,
    int? pillCount,
  }) async {
    final response = await _dio.patch('/medicines/$id', data: {
      if (name != null) 'name': name,
      if (dosage != null) 'dosage': dosage,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      if (frequency != null) 'frequency': frequency,
      if (active != null) 'active': active,
      if (pillCount != null) 'pill_count': pillCount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteMedicine(String id) async {
    await _dio.delete('/medicines/$id');
  }

  // ── Dose Logs ─────────────────────────────────────

  Future<Map<String, dynamic>> syncDoseLogs() async {
    final response = await _dio.post('/dose-logs/sync');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> todayDoseLogs() async {
    final response = await _dio.get('/dose-logs/today');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> historyDoseLogs({int days = 30}) async {
    final response = await _dio.get('/dose-logs/history', queryParameters: {
      'days': days,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> takeDose(String logId) async {
    final response = await _dio.post('/dose-logs/$logId/take');
    return response.data as Map<String, dynamic>;
  }
}
