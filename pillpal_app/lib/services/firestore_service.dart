import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/log_entry.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ─── USER ────────────────────────────────────────────────────────────

  Stream<UserModel?> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  // ─── MEDICINES ───────────────────────────────────────────────────────

  Stream<List<Medicine>> getMedicinesStream(String userId) {
    return _db
        .collection('medicines')
        .where('userId', isEqualTo: userId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Medicine.fromDoc).toList());
  }

  Future<String> addMedicine(Medicine medicine) async {
    final ref = await _db.collection('medicines').add(medicine.toMap());
    return ref.id;
  }

  Future<void> updateMedicine(String medicineId, Map<String, dynamic> data) async {
    await _db.collection('medicines').doc(medicineId).update(data);
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _db.collection('medicines').doc(medicineId).delete();
  }

  Future<Medicine?> getMedicine(String medicineId) async {
    final doc = await _db.collection('medicines').doc(medicineId).get();
    if (!doc.exists) return null;
    return Medicine.fromDoc(doc);
  }

  // ─── LOGS ────────────────────────────────────────────────────────────

  Stream<List<LogEntry>> getTodayLogsStream(String userId) {
    return _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('date', isEqualTo: _today)
        .snapshots()
        .map((snap) => snap.docs.map(LogEntry.fromDoc).toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime)));
  }

  Stream<List<LogEntry>> getHistoryLogsStream(String userId) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final fromDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);
    return _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: fromDate)
        .snapshots()
        .map((snap) => snap.docs.map(LogEntry.fromDoc).toList()
          ..sort((a, b) => b.date.compareTo(a.date)));
  }

  Future<bool> logExistsForToday(String userId, String medicineId) async {
    final snap = await _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('medicineId', isEqualTo: medicineId)
        .where('date', isEqualTo: _today)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> createLog(LogEntry log) async {
    await _db.collection('logs').add(log.toMap());
  }

  Future<void> updateLog(String logId, Map<String, dynamic> data) async {
    await _db.collection('logs').doc(logId).update(data);
  }

  Future<List<LogEntry>> getLogsForDateRange(String userId, String from, String to) async {
    final snap = await _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: from)
        .where('date', isLessThanOrEqualTo: to)
        .get();
    return snap.docs.map(LogEntry.fromDoc).toList();
  }
}
