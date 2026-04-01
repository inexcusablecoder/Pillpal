import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../models/user_model.dart';

/// Real-time reads from Firestore. Writes for medicines/logs go through [ApiService].
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Stream<UserModel?> getUserStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

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
}
