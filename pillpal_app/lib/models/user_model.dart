import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final int streakCount;
  final int adherenceScore;
  final List<Map<String, String>> familyMembers;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.streakCount = 0,
    this.adherenceScore = 0,
    this.familyMembers = const [],
    required this.createdAt,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      streakCount: data['streakCount'] ?? 0,
      adherenceScore: data['adherenceScore'] ?? 0,
      familyMembers: List<Map<String, String>>.from(
        (data['familyMembers'] ?? []).map((e) => Map<String, String>.from(e)),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'streakCount': streakCount,
      'adherenceScore': adherenceScore,
      'familyMembers': familyMembers,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
