import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Calls the FastAPI backend (`backend/app`) with Firebase ID tokens.
/// Firestore is still used in the app for real-time reads (streams).
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  factory ApiService() => instance;

  Uri _uri(String path) => Uri.parse('${ApiConfig.origin}$path');

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('No ID token');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  String _errorBody(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return res.body.isNotEmpty ? res.body : 'HTTP ${res.statusCode}';
  }

  /// POST /v1/logs/startup — generate today’s logs + auto-mark missed.
  Future<void> logsStartup() async {
    final res = await http.post(
      _uri('/v1/logs/startup'),
      headers: await _headers(),
    );
    if (res.statusCode >= 400) {
      throw Exception(_errorBody(res));
    }
  }

  /// POST /v1/logs/mark-taken
  Future<void> markTaken({
    required String logId,
    required String medicineId,
  }) async {
    final res = await http.post(
      _uri('/v1/logs/mark-taken'),
      headers: await _headers(),
      body: jsonEncode({
        'log_id': logId,
        'medicine_id': medicineId,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception(_errorBody(res));
    }
  }

  /// POST /v1/medicines — returns new Firestore document id.
  Future<String> createMedicine({
    required String name,
    required String dosage,
    required String scheduledTime,
    String frequency = 'daily',
    List<int> daysOfWeek = const [],
    int pillCount = 30,
    int refillAt = 5,
    String memberName = 'Self',
    bool active = true,
  }) async {
    final res = await http.post(
      _uri('/v1/medicines'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'dosage': dosage,
        'scheduled_time': scheduledTime,
        'frequency': frequency,
        'days_of_week': daysOfWeek,
        'pill_count': pillCount,
        'refill_at': refillAt,
        'member_name': memberName,
        'active': active,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception(_errorBody(res));
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('API did not return medicine id');
    }
    return id;
  }
}
