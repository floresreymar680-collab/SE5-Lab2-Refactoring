// lib/services/user_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// UserService — Admin-only CRUD for /users collection
// Free tier: one-time get() only, no real-time listeners
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'audit_log_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _collection = 'users';

  // ── Fetch all users (Admin only) ───────────────────────────────────────────
  Future<List<UserModel>> fetchAllUsers() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((d) => UserModel.fromDocument(d)).toList();
  }

  // ── Fetch single user by ID ────────────────────────────────────────────────
  Future<UserModel?> fetchUserById(String userId) async {
    final doc = await _firestore.collection(_collection).doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  // ── Check if username is already taken ────────────────────────────────────
  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;
    if (excludeUserId != null && snapshot.docs.first.id == excludeUserId) {
      return false;
    }
    return true;
  }

  // ── Update user (fullName, role, isActive) ─────────────────────────────────
  Future<void> updateUser({
    required String userId,
    required String fullName,
    required String role,
    required bool isActive,
    required String adminUserId,
    required String adminFullName,
  }) async {
    await _firestore.collection(_collection).doc(userId).update({
      'fullName': fullName,
      'role': role,
      'isActive': isActive,
    });

    await AuditLogService().insertLog(
      userId: adminUserId,
      userFullName: adminFullName,
      role: 'Administrator',
      actionType: 'ACCOUNT_CHANGED',
      affectedTable: 'users',
      affectedRecordId: userId,
    );
  }

  // ── Deactivate account ─────────────────────────────────────────────────────
  Future<void> deactivateUser({
    required String targetUserId,
    required String adminUserId,
    required String adminFullName,
  }) async {
    await _firestore.collection(_collection).doc(targetUserId).update({
      'isActive': false,
    });

    await AuditLogService().insertLog(
      userId: adminUserId,
      userFullName: adminFullName,
      role: 'Administrator',
      actionType: 'ACCOUNT_CHANGED',
      affectedTable: 'users',
      affectedRecordId: targetUserId,
    );
  }

  // ── Reactivate account ─────────────────────────────────────────────────────
  Future<void> reactivateUser({
    required String targetUserId,
    required String adminUserId,
    required String adminFullName,
  }) async {
    await _firestore.collection(_collection).doc(targetUserId).update({
      'isActive': true,
    });

    await AuditLogService().insertLog(
      userId: adminUserId,
      userFullName: adminFullName,
      role: 'Administrator',
      actionType: 'ACCOUNT_CHANGED',
      affectedTable: 'users',
      affectedRecordId: targetUserId,
    );
  }
}
