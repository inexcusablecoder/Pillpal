// This service replaces Firebase Cloud Functions (free tier solution).
// All logic that would run server-side now runs in Flutter on app open.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../models/log_entry.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class BackendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Called every time the app opens.
  /// Generates today's log entries for all active medicines (replaces generateDailyLogs Cloud Function).
  Future<void> generateTodayLogs(String userId) async {
    final medicinesSnap = await _db
        .collection('medicines')
        .where('userId', isEqualTo: userId)
        .where('active', isEqualTo: true)
        .get();

    if (medicinesSnap.docs.isEmpty) return;

    final today = DateTime.now();
    final dayOfWeek = today.weekday % 7; // 0=Sun, 1=Mon ... 6=Sat

    for (final doc in medicinesSnap.docs) {
      final medicine = Medicine.fromDoc(doc);

      bool shouldLog = false;
      if (medicine.frequency == 'daily') {
        shouldLog = true;
      } else if (medicine.frequency == 'weekly' || medicine.frequency == 'custom') {
        shouldLog = medicine.daysOfWeek.contains(dayOfWeek);
      }

      if (!shouldLog) continue;

      final alreadyExists = await _firestoreService.logExistsForToday(userId, doc.id);
      if (alreadyExists) continue;

      final log = LogEntry(
        id: '',
        userId: userId,
        medicineId: doc.id,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        scheduledTime: medicine.scheduledTime,
        date: _today,
        status: 'pending',
        takenAt: null,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createLog(log);

      // Schedule a local notification for this medicine
      await _notificationService.scheduleMedicineReminder(
        medicineId: doc.id,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        scheduledTime: medicine.scheduledTime,
      );
    }
  }

  /// Called every time the app opens.
  /// Marks overdue pending logs as missed (replaces autoMarkMissed Cloud Function).
  Future<void> autoMarkMissed(String userId) async {
    final snap = await _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .where('date', isEqualTo: _today)
        .get();

    if (snap.docs.isEmpty) return;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final batch = _db.batch();
    int missedCount = 0;

    for (final doc in snap.docs) {
      final log = LogEntry.fromDoc(doc);
      final parts = log.scheduledTime.split(':');
      final scheduledMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final deadlineMinutes = scheduledMinutes + 60;

      if (currentMinutes > deadlineMinutes) {
        batch.update(doc.reference, {'status': 'missed'});
        missedCount++;
      }
    }

    if (missedCount > 0) {
      await batch.commit();
      await calculateAdherence(userId);
    }
  }

  /// Called when user taps "Mark as Taken".
  /// Replaces markAsTaken Cloud Function.
  Future<void> markAsTaken(String logId, String medicineId, String userId) async {
    await _db.runTransaction((transaction) async {
      final logRef = _db.collection('logs').doc(logId);
      final medRef = _db.collection('medicines').doc(medicineId);

      final logDoc = await transaction.get(logRef);
      final medDoc = await transaction.get(medRef);

      if (!logDoc.exists) throw Exception('Log not found');
      if (logDoc.data()!['status'] == 'taken') return;

      transaction.update(logRef, {
        'status': 'taken',
        'takenAt': FieldValue.serverTimestamp(),
      });

      if (medDoc.exists && (medDoc.data()!['pillCount'] ?? 0) > 0) {
        final newCount = (medDoc.data()!['pillCount'] as int) - 1;
        transaction.update(medRef, {'pillCount': newCount});

        final refillAt = medDoc.data()!['refillAt'] as int? ?? 5;
        final medName = medDoc.data()!['name'] as String? ?? 'Medicine';
        if (newCount <= refillAt) {
          await _notificationService.showRefillAlert(medName, newCount);
        }
      }
    });

    await calculateAdherence(userId);
  }

  /// Recalculates adherenceScore and streakCount for the user.
  /// Replaces calculateAdherence Cloud Function.
  Future<void> calculateAdherence(String userId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final fromDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);

    final snap = await _db
        .collection('logs')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: fromDate)
        .get();

    if (snap.docs.isEmpty) return;

    int total = 0;
    int taken = 0;

    final Map<String, Map<String, int>> dayMap = {};

    for (final doc in snap.docs) {
      final log = LogEntry.fromDoc(doc);
      total++;
      if (log.status == 'taken') taken++;

      dayMap[log.date] ??= {'total': 0, 'taken': 0};
      dayMap[log.date]!['total'] = (dayMap[log.date]!['total'] ?? 0) + 1;
      if (log.status == 'taken') {
        dayMap[log.date]!['taken'] = (dayMap[log.date]!['taken'] ?? 0) + 1;
      }
    }

    final adherenceScore = total > 0 ? ((taken / total) * 100).round() : 0;

    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final day = dayMap[dateStr];
      if (day != null && day['total']! > 0 && day['taken'] == day['total']) {
        streak++;
      } else {
        break;
      }
    }

    await _db.collection('users').doc(userId).update({
      'adherenceScore': adherenceScore,
      'streakCount': streak,
    });
  }

  /// Run all startup checks when the app opens.
  Future<void> runStartupChecks(String userId) async {
    await generateTodayLogs(userId);
    await autoMarkMissed(userId);
  }
}
