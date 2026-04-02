class User {
  final String id;
  final String email;
  final String? displayName;
  final String? phoneE164;
  final bool alarmRemindersEnabled;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.phoneE164,
    this.alarmRemindersEnabled = false,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      phoneE164: json['phone_e164'] as String?,
      alarmRemindersEnabled: json['alarm_reminders_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'phone_e164': phoneE164,
      'alarm_reminders_enabled': alarmRemindersEnabled,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get greeting => displayName ?? email.split('@').first;
}
