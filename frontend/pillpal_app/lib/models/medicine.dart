import 'package:flutter/material.dart';

class Medicine {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final TimeOfDay scheduledTime;
  final String frequency;
  final bool active;
  final bool reminderEnabled;
  final int? pillCount;
  final String? labelImageKey;
  final String? labelAnalysisText;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.scheduledTime,
    required this.frequency,
    required this.active,
    this.reminderEnabled = true,
    this.pillCount,
    this.labelImageKey,
    this.labelAnalysisText,
    required this.createdAt,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final timeParts = json['scheduled_time'].toString().split(':');
    return Medicine(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      scheduledTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      frequency: json['frequency'] as String,
      active: json['active'] as bool,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      pillCount: json['pill_count'] as int?,
      labelImageKey: json['label_image_key'] as String?,
      labelAnalysisText: json['label_analysis_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get scheduledTimeString {
    final h = scheduledTime.hourOfPeriod == 0 ? 12 : scheduledTime.hourOfPeriod;
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    final period = scheduledTime.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String get timeApiFormat {
    final h = scheduledTime.hour.toString().padLeft(2, '0');
    final m = scheduledTime.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }
}
