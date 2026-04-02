class User {
  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get greeting => displayName ?? email.split('@').first;
}
