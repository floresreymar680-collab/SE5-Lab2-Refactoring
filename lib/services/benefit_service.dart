// lib/services/benefit_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// BenefitService — CRUD for /benefit_records, duplicate detection client-side
// Free tier optimized: no composite indexes, sort client-side
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/benefit_record_model.dart';
import '../utils/benefit_utils.dart';
import 'audit_log_service.dart';

class BenefitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _collection = 'benefit_records';

  // ── CREATE ─────────────────────────────────────────────────────────────────
  Future<String> createBenefitRecord({
    required BenefitRecordModel record,
    required String actorUserId,
    required String actorFullName,
    required String actorRole,
  }) async {
    final docRef = _firestore.collection(_collection).doc();

    await docRef.set(record.toMap());

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: actorRole,
      actionType: 'BENEFIT_RECORDED',
      affectedTable: 'benefit_records',
      affectedRecordId: docRef.id,
    );

    return docRef.id;
  }

  // ── DUPLICATE CHECK ────────────────────────────────────────────────────────
  /// Returns true if same pwdId + benefitType + benefitPeriod already exists.
  Future<bool> checkDuplicate({
    required String pwdId,
    required String benefitType,
    required DateTime dateReceived,
    String? excludeBenefitId,
  }) async {
    final period = computeBenefitPeriod(dateReceived);

    final snapshot = await _firestore
        .collection(_collection)
        .where('pwdId', isEqualTo: pwdId)
        .where('benefitType', isEqualTo: benefitType)
        .where('benefitPeriod', isEqualTo: period)
        .limit(2)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeBenefitId != null && doc.id == excludeBenefitId) continue;
      return true;
    }
    return false;
  }

  // ── FETCH for a specific PWD ───────────────────────────────────────────────
  /// No orderBy → no composite index needed (free tier friendly).
  /// Sorted client-side by dateReceived descending.
  Future<List<BenefitRecordModel>> fetchBenefitsForPWD(String pwdId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('pwdId', isEqualTo: pwdId)
        .get();

    final list =
        snapshot.docs.map((d) => BenefitRecordModel.fromDocument(d)).toList();

    // Client-side sort — newest first
    list.sort((a, b) => b.dateReceived.compareTo(a.dateReceived));

    return list;
  }

  // ── FETCH all (paginated) ─────────────────────────────────────────────────
  Future<List<BenefitRecordModel>> fetchAllBenefits({
    String? barangay,
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .orderBy('dateReceived', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => BenefitRecordModel.fromDocument(d))
        .toList();
  }

  // ── DELETE (Admin only) ────────────────────────────────────────────────────
  Future<void> deleteBenefitRecord({
    required String benefitId,
    required String actorUserId,
    required String actorFullName,
  }) async {
    await _firestore.collection(_collection).doc(benefitId).delete();

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: 'Administrator',
      actionType: 'BENEFIT_DELETED',
      affectedTable: 'benefit_records',
      affectedRecordId: benefitId,
    );
  }
}
