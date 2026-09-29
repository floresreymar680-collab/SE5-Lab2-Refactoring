// lib/services/auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// AuthService — Firebase Auth login / logout + Firestore user fetch.
// All logic is CLIENT-SIDE (Spark plan, no Firebase Functions).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/firebase_constants.dart';
import '../constants/app_constants.dart';
import 'audit_log_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLogService = AuditLogService();

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Sign in with Firebase Auth
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final String uid = credential.user!.uid;

      // 2. Fetch the user document from Firestore /users/{uid}
      final DocumentSnapshot doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid)
          .get();

      if (!doc.exists) {
        await _auth.signOut();
        await _auditLogService.logLoginFailed(email: email);
        throw 'Account not found in the system. Contact your Administrator.';
      }

      final UserModel user = UserModel.fromDocument(doc);

      // 3. Check if the account is active
      if (!user.isActive) {
        await _auth.signOut();
        await _auditLogService.logLoginFailed(email: email);
        throw 'Your account has been deactivated. Contact your Administrator.';
      }

      // 4. Write success audit log — now includes userFullName
      await _auditLogService.insertLog(
        userId: uid,
        userFullName: user.fullName, // FIX: save name instead of just UID
        role: user.role,
        actionType: AppConstants.actionLogin,
        affectedTable: FirebaseConstants.usersCollection,
        affectedRecordId: uid,
      );

      return user;
    } on FirebaseAuthException catch (e) {
      try {
        await _auditLogService.logLoginFailed(email: email);
      } catch (_) {}

      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-email':
          throw 'Invalid username or password.';
        case 'user-disabled':
          throw 'Your account has been deactivated. Contact your Administrator.';
        case 'too-many-requests':
          throw 'Too many failed attempts. Please try again later.';
        default:
          throw 'An error occurred. Please try again.';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'An error occurred. Please try again.';
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  // FIX: added userFullName parameter so the audit log shows the name
  Future<void> logout({
    String? userId,
    String? userFullName,
    String? role,
  }) async {
    try {
      if (userId != null && role != null) {
        await _auditLogService.insertLog(
          userId: userId,
          userFullName:
              userFullName ?? '', // FIX: save name instead of just UID
          role: role,
          actionType: AppConstants.actionLogout,
          affectedTable: FirebaseConstants.usersCollection,
          affectedRecordId: userId,
        );
      }
    } catch (_) {
      // Do not block logout if audit fails
    } finally {
      await _auth.signOut();
    }
  }

  // ── Re-fetch current user (used on app resume) ─────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final DocumentSnapshot doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) return null;

      final UserModel user = UserModel.fromDocument(doc);
      if (!user.isActive) {
        await _auth.signOut();
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }
}
