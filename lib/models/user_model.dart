// lib/models/user_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// UserModel — maps to Firestore /users/{userId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String fullName;
  final String username;
  final String email;
  final String
      role; // 'Administrator' | 'Barangay Staff' | 'Health Center Staff'
  final bool isActive;
  final DateTime createdAt;
  final String createdBy; // userId of the admin who created this account

  UserModel({
    required this.userId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  // ── Firestore → Model ──────────────────────────────────────────────────────
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      userId: docId,
      fullName: map['fullName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'Barangay Staff',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot doc) {
    return UserModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── Model → Firestore ──────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'username': username,
      'email': email,
      'role': role,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  UserModel copyWith({
    String? userId,
    String? fullName,
    String? username,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() =>
      'UserModel(userId: $userId, fullName: $fullName, role: $role, isActive: $isActive)';
}
