import 'package:cloud_firestore/cloud_firestore.dart';

class LogEntry {
  final String id;
  final String userId;
  final String medicineId;
  final String medicineName;
  final String dosage;
  final String scheduledTime;
  final String date;
  final String status; // "pending" | "taken" | "missed"
  final DateTime? takenAt;
  final DateTime createdAt;

  LogEntry({
    required this.id,
    required this.userId,
    required this.medicineId,
    required this.medicineName,
    required this.dosage,
    required this.scheduledTime,
    required this.date,
    required this.status,
    this.takenAt,
    required this.createdAt,
  });

  factory LogEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LogEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      medicineId: data['medicineId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      dosage: data['dosage'] ?? '',
      scheduledTime: data['scheduledTime'] ?? '',
      date: data['date'] ?? '',
      status: data['status'] ?? 'pending',
      takenAt: (data['takenAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'date': date,
      'status': status,
      'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isTaken => status == 'taken';
  bool get isMissed => status == 'missed';
  bool get isPending => status == 'pending';
}
