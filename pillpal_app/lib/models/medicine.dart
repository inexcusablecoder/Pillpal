import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String userId;
  final String memberName;
  final String name;
  final String dosage;
  final String scheduledTime;
  final String frequency;
  final List<int> daysOfWeek;
  final int pillCount;
  final int refillAt;
  final bool active;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.userId,
    this.memberName = 'Self',
    required this.name,
    required this.dosage,
    required this.scheduledTime,
    this.frequency = 'daily',
    this.daysOfWeek = const [],
    this.pillCount = 30,
    this.refillAt = 5,
    this.active = true,
    required this.createdAt,
  });

  factory Medicine.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medicine(
      id: doc.id,
      userId: data['userId'] ?? '',
      memberName: data['memberName'] ?? 'Self',
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      scheduledTime: data['scheduledTime'] ?? '08:00',
      frequency: data['frequency'] ?? 'daily',
      daysOfWeek: List<int>.from(data['daysOfWeek'] ?? []),
      pillCount: data['pillCount'] ?? 30,
      refillAt: data['refillAt'] ?? 5,
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'memberName': memberName,
      'name': name,
      'dosage': dosage,
      'scheduledTime': scheduledTime,
      'frequency': frequency,
      'daysOfWeek': daysOfWeek,
      'pillCount': pillCount,
      'refillAt': refillAt,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Medicine copyWith({int? pillCount, bool? active}) {
    return Medicine(
      id: id,
      userId: userId,
      memberName: memberName,
      name: name,
      dosage: dosage,
      scheduledTime: scheduledTime,
      frequency: frequency,
      daysOfWeek: daysOfWeek,
      pillCount: pillCount ?? this.pillCount,
      refillAt: refillAt,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
