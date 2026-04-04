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

  Future<Map<String, dynamic>> updateMe({
    String? displayName,
    bool? alarmRemindersEnabled,
    String? phoneE164,
    String? language,
    bool clearPhone = false,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (alarmRemindersEnabled != null) {
      data['alarm_reminders_enabled'] = alarmRemindersEnabled;
    }
    if (language != null) data['language'] = language;
    if (clearPhone) {
      data['phone_e164'] = null;
    } else if (phoneE164 != null) {
      data['phone_e164'] = phoneE164;
    }
    final response = await _dio.patch('/users/me', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<String> getLanguage() async {
    final response = await _dio.get('/translate/get-language');
    return response.data['lang'] as String;
  }

  Future<List<String>> translate(List<String> texts, String lang) async {
    final response = await _dio.post('/translate/translate', data: {
      'texts': texts,
      'lang': lang,
    });
    return (response.data['translated'] as List).map((e) => e.toString()).toList();
  }

  // ── Medicines ─────────────────────────────────────

  Future<List<dynamic>> listMedicines({bool activeOnly = false}) async {
    final response = await _dio.get('/medicines', queryParameters: {
      if (activeOnly) 'active_only': true,
    });
    return response.data as List<dynamic>;
  }

  /// Curated names from DB (`reference_medicines`) — same on Neon and local Postgres.
  Future<List<dynamic>> getMedicineCatalog() async {
    final response = await _dio.get('/medicines/catalog');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createMedicine({
    required String name,
    required String dosage,
    required String scheduledTime,
    String frequency = 'daily',
    bool active = true,
    bool reminderEnabled = true,
    int? pillCount,
  }) async {
    final response = await _dio.post('/medicines', data: {
      'name': name,
      'dosage': dosage,
      'scheduled_time': scheduledTime,
      'frequency': frequency,
      'active': active,
      'reminder_enabled': reminderEnabled,
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
    bool? reminderEnabled,
    int? pillCount,
  }) async {
    final response = await _dio.patch('/medicines/$id', data: {
      if (name != null) 'name': name,
      if (dosage != null) 'dosage': dosage,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      if (frequency != null) 'frequency': frequency,
      if (active != null) 'active': active,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
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

  // ── Twilio Call Schedules ───────────────────────

  Future<Map<String, dynamic>> scheduleCall({
    required String phone,
    required List<String> times,
    required String startDate,
    required String endDate,
    required String callType,
    String? message,
    String? audioUrl,
  }) async {
    final response = await _dio.post('/calls/schedule', data: {
      'phone': phone,
      'times': times,
      'start_date': startDate,
      'end_date': endDate,
      'call_type': callType,
      'message': message,
      'audio_url': audioUrl,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCallSchedule({
    required int id,
    required String phone,
    required List<String> times,
    required String startDate,
    required String endDate,
    required String callType,
    String? message,
    String? audioUrl,
  }) async {
    final response = await _dio.put('/calls/schedule/$id', data: {
      'phone': phone,
      'times': times,
      'start_date': startDate,
      'end_date': endDate,
      'call_type': callType,
      'message': message,
      'audio_url': audioUrl,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCallSchedules() async {
    final response = await _dio.get('/calls/schedules');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> deleteCallSchedule(int id) async {
    final response = await _dio.delete('/calls/schedule/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<String> sendChatMessage(List<Map<String, String>> messages) async {
    final response = await _dio.post('/ai/chat', data: {
      'messages': messages,
    });
    return response.data['response'] as String;
  }

  Future<List<dynamic>> getCallHistory() async {
    final response = await _dio.get('/calls/history');
    return response.data as List<dynamic>;
  }

  Future<String> getLastPhone() async {
    final response = await _dio.get('/calls/last-phone');
    return response.data['phone'] as String;
  }
}
