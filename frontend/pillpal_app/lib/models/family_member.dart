import 'package:flutter/material.dart';

class FamilyMember {
  final String id;
  final String name;
  final String relationship; // 'Self', 'Spouse', 'Parent', 'Child', 'Sibling', 'Other'
  final String avatarEmoji;
  final int avatarColorValue; // stored as int for serialization
  final DateTime createdAt;
  final bool isSelf;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.avatarEmoji,
    required this.avatarColorValue,
    required this.createdAt,
    this.isSelf = false,
  });

  Color get avatarColor => Color(avatarColorValue);

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      avatarEmoji: json['avatar_emoji'] as String,
      avatarColorValue: json['avatar_color'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSelf: json['is_self'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'avatar_emoji': avatarEmoji,
      'avatar_color': avatarColorValue,
      'created_at': createdAt.toIso8601String(),
      'is_self': isSelf,
    };
  }

  FamilyMember copyWith({
    String? name,
    String? relationship,
    String? avatarEmoji,
    int? avatarColorValue,
  }) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      createdAt: createdAt,
      isSelf: isSelf,
    );
  }

  static const List<String> relationships = [
    'Self',
    'Spouse',
    'Parent',
    'Child',
    'Sibling',
    'Other',
  ];

  static const List<String> availableEmojis = [
    '👤', '👴', '👵', '👨', '👩', '👦',
    '👧', '👶', '🧓', '🧑', '💊', '❤️',
  ];

  static const List<int> avatarColors = [
    0xFF0284C7, // Blue
    0xFFEF4444, // Red
    0xFF10B981, // Green
    0xFFF59E0B, // Amber
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFFF97316, // Orange
  ];
}
