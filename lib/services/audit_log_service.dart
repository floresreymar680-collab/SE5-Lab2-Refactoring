// lib/services/audit_log_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// AuditLogService — insert-only.  Never updates or deletes.
// Matches Firestore security rules: allow create only; update/delete → false.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_constants.dart';
import '../utils/uuid_utils.dart'; // uses generateUUID() function

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── PRIMARY METHOD — used by auth_service.dart ─────────────────────────────
  Future<void> log({
    required String userId,
    required String role,
    required String actionType,
    required String affectedTable,
    String? affectedRecordId,
    String ipAddress = 'client',
  }) async {
    try {
      final String logId = generateUUID();
      await _firestore
          .collection(FirebaseConstants.auditLogsCollection)
          .doc(logId)
          .set({
        FirebaseConstants.fieldLogId: logId,
        'userId': userId,
        FirebaseConstants.fieldRole: role,
        FirebaseConstants.fieldActionType: actionType,
        FirebaseConstants.fieldAffectedTable: affectedTable,
        FirebaseConstants.fieldAffectedRecordId: affectedRecordId,
        FirebaseConstants.fieldTimestamp: FieldValue.serverTimestamp(),
        FirebaseConstants.fieldIpAddress: ipAddress,
      });
    } catch (e) {
      _debugPrint('audit_log_service [log]', e);
    }
  }

  // ── ALIAS — used by Phase 2 services (benefit, health, pwd, user) ──────────
  // Accepts userFullName as extra parameter and stores it in the log document.
  Future<void> insertLog({
    required String userId,
    required String userFullName,
    required String role,
    required String actionType,
    required String affectedTable,
    String? affectedRecordId,
    String ipAddress = 'client',
  }) async {
    try {
      final String logId = generateUUID();
      await _firestore
          .collection(FirebaseConstants.auditLogsCollection)
          .doc(logId)
          .set({
        FirebaseConstants.fieldLogId: logId,
        'userId': userId,
        'userFullName': userFullName,
        FirebaseConstants.fieldRole: role,
        FirebaseConstants.fieldActionType: actionType,
        FirebaseConstants.fieldAffectedTable: affectedTable,
        FirebaseConstants.fieldAffectedRecordId: affectedRecordId,
        FirebaseConstants.fieldTimestamp: FieldValue.serverTimestamp(),
        FirebaseConstants.fieldIpAddress: ipAddress,
      });
    } catch (e) {
      _debugPrint('audit_log_service [insertLog]', e);
    }
  }

  // ── LOGIN FAILED (no userId available) ────────────────────────────────────
  Future<void> logLoginFailed({required String email}) async {
    try {
      final String logId = generateUUID();
      await _firestore
          .collection(FirebaseConstants.auditLogsCollection)
          .doc(logId)
          .set({
        FirebaseConstants.fieldLogId: logId,
        'userId': 'unknown',
        'email': email,
        'userFullName': 'unknown',
        FirebaseConstants.fieldRole: 'unknown',
        FirebaseConstants.fieldActionType: 'LOGIN_FAILED',
        FirebaseConstants.fieldAffectedTable: FirebaseConstants.usersCollection,
        FirebaseConstants.fieldAffectedRecordId: null,
        FirebaseConstants.fieldTimestamp: FieldValue.serverTimestamp(),
        FirebaseConstants.fieldIpAddress: 'client',
      });
    } catch (_) {}
  }

  // ── PAGINATED FETCH (Admin — AuditLogScreen) ───────────────────────────────
  Future<List<Map<String, dynamic>>> fetchLogs({
    int limit = 50,
    DocumentSnapshot? lastDocument,
    String? actionTypeFilter,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      Query query = _firestore
          .collection(FirebaseConstants.auditLogsCollection)
          .orderBy(FirebaseConstants.fieldTimestamp, descending: true)
          .limit(limit);

      if (actionTypeFilter != null && actionTypeFilter.isNotEmpty) {
        query = query.where(
          FirebaseConstants.fieldActionType,
          isEqualTo: actionTypeFilter,
        );
      }

      if (fromDate != null) {
        query = query.where(
          FirebaseConstants.fieldTimestamp,
          isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate),
        );
      }

      if (toDate != null) {
        query = query.where(
          FirebaseConstants.fieldTimestamp,
          isLessThanOrEqualTo: Timestamp.fromDate(
            toDate.add(const Duration(days: 1)),
          ),
        );
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

void _debugPrint(String tag, Object error) {
  assert(() {
    // ignore: avoid_print
    print('[$tag] Audit log error: $error');
    return true;
  }());
}
