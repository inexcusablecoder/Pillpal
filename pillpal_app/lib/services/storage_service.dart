import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── Token ──────────────────────────────────────────
  Future<void> saveToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(AppConstants.tokenKey);
  }

  Future<void> deleteToken() async {
    await _prefs.remove(AppConstants.tokenKey);
  }

  // ── User JSON ──────────────────────────────────────
  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    await _prefs.setString(AppConstants.userKey, jsonEncode(userJson));
  }

  Map<String, dynamic>? getUserJson() {
    final raw = _prefs.getString(AppConstants.userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> deleteUser() async {
    await _prefs.remove(AppConstants.userKey);
  }

  // ── Refill Threshold ───────────────────────────────
  Future<void> saveRefillThreshold(String medicineId, int threshold) async {
    await _prefs.setInt('refill_$medicineId', threshold);
  }

  int? getRefillThreshold(String medicineId) {
    return _prefs.getInt('refill_$medicineId');
  }

  Future<void> deleteRefillThreshold(String medicineId) async {
    await _prefs.remove('refill_$medicineId');
  }

  // ── Vitals (Member-Scoped) ─────────────────────────
  Future<void> saveVitals(List<Map<String, dynamic>> vitalsJson, {String? memberId}) async {
    final key = _vitalsKey(memberId);
    await _prefs.setString(key, jsonEncode(vitalsJson));
  }

  List<Map<String, dynamic>> getVitals({String? memberId}) {
    final key = _vitalsKey(memberId);
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  String _vitalsKey(String? memberId) {
    if (memberId == null || memberId.isEmpty) return 'vitals_list';
    return 'vitals_$memberId';
  }

  // ── Family Members ─────────────────────────────────
  Future<void> saveFamilyMembers(List<Map<String, dynamic>> membersJson) async {
    await _prefs.setString('family_members', jsonEncode(membersJson));
  }

  List<Map<String, dynamic>> getFamilyMembers() {
    final raw = _prefs.getString('family_members');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveActiveMemberId(String id) async {
    await _prefs.setString('active_member_id', id);
  }

  String? getActiveMemberId() {
    return _prefs.getString('active_member_id');
  }

  // ── Member Data Cleanup ────────────────────────────
  Future<void> clearMemberData(String memberId) async {
    await _prefs.remove('vitals_$memberId');
    // Future: also clean medicines_$memberId, doseLogs_$memberId, etc.
  }

  // ── Clear All ──────────────────────────────────────
  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.tokenKey);
    await _prefs.remove(AppConstants.userKey);
    await _prefs.remove('vitals_list');
    await _prefs.remove('family_members');
    await _prefs.remove('active_member_id');
  }
}
