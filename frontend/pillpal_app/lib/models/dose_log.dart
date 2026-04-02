import 'package:flutter/material.dart';

enum DoseStatus { pending, taken, missed }

class DoseLog {
  final String id;
  final String userId;
  final String medicineId;
  final String medicineName;
  final DateTime scheduledDate;
  final TimeOfDay scheduledTime;
  final DoseStatus status;
  final DateTime? takenAt;
  final DateTime createdAt;

  DoseLog({
    required this.id,
    required this.userId,
    required this.medicineId,
    required this.medicineName,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.takenAt,
    required this.createdAt,
  });

  factory DoseLog.fromJson(Map<String, dynamic> json) {
    final timeParts = json['scheduled_time'].toString().split(':');
    return DoseLog(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      medicineId: json['medicine_id'].toString(),
      medicineName: json['medicine_name'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      status: DoseStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String),
        orElse: () => DoseStatus.pending,
      ),
      takenAt: json['taken_at'] != null
          ? DateTime.parse(json['taken_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get scheduledTimeString {
    final h = scheduledTime.hourOfPeriod == 0 ? 12 : scheduledTime.hourOfPeriod;
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    final period = scheduledTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  bool get isPending => status == DoseStatus.pending;
  bool get isTaken => status == DoseStatus.taken;
  bool get isMissed => status == DoseStatus.missed;
}
