// lib/services/pwd_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// PWDService — CRUD for /pwd_records, paginated (25/page), duplicate check
// Free tier optimized: one-time get(), limit queries, no real-time streams
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/pwd_record_model.dart';
import 'audit_log_service.dart';

class PWDService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _collection = 'pwd_records';
  static const int _pageSize = 25;

  // ── CREATE ─────────────────────────────────────────────────────────────────
  Future<String> createPWDRecord({
    required PWDRecordModel record,
    required String actorUserId,
    required String actorFullName,
    required String actorRole,
  }) async {
    final docRef = _firestore.collection(_collection).doc();
    final now = DateTime.now();

    final newRecord = record.copyWith(
      pwdId: docRef.id,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(newRecord.toMap());

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: actorRole,
      actionType: 'PWD_CREATED',
      affectedTable: 'pwd_records',
      affectedRecordId: docRef.id,
    );

    return docRef.id;
  }

  // ── READ — single record ───────────────────────────────────────────────────
  Future<PWDRecordModel?> fetchPWDById(String pwdId) async {
    final doc = await _firestore.collection(_collection).doc(pwdId).get();
    if (!doc.exists) return null;
    return PWDRecordModel.fromDocument(doc);
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────
  Future<void> updatePWDRecord({
    required PWDRecordModel record,
    required String actorUserId,
    required String actorFullName,
    required String actorRole,
  }) async {
    final updatedData = record.toMap();
    updatedData['updatedAt'] = Timestamp.fromDate(DateTime.now());

    await _firestore
        .collection(_collection)
        .doc(record.pwdId)
        .update(updatedData);

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: actorRole,
      actionType: 'PWD_UPDATED',
      affectedTable: 'pwd_records',
      affectedRecordId: record.pwdId,
    );
  }

  // ── UPDATE health fields only (Health Center Staff) ────────────────────────
  Future<void> updateHealthFields({
    required String pwdId,
    required String healthCondition,
    required String actorUserId,
    required String actorFullName,
  }) async {
    await _firestore.collection(_collection).doc(pwdId).update({
      'healthCondition': healthCondition,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: 'Health Center Staff',
      actionType: 'PWD_UPDATED',
      affectedTable: 'pwd_records',
      affectedRecordId: pwdId,
    );
  }

  // ── DELETE (Admin only) ────────────────────────────────────────────────────
  Future<void> deletePWDRecord({
    required String pwdId,
    required String actorUserId,
    required String actorFullName,
  }) async {
    await _firestore.collection(_collection).doc(pwdId).delete();

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: 'Administrator',
      actionType: 'PWD_DELETED',
      affectedTable: 'pwd_records',
      affectedRecordId: pwdId,
    );
  }

  // ── DUPLICATE CHECK ────────────────────────────────────────────────────────
  /// Returns true if a record with the same firstName + lastName + DOB + barangay exists.
  Future<bool> checkDuplicate({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String barangay,
    String? excludePwdId,
  }) async {
    final dobString = DateFormat('yyyy-MM-dd').format(dateOfBirth);

    final snapshot = await _firestore
        .collection(_collection)
        .where('firstName', isEqualTo: firstName)
        .where('lastName', isEqualTo: lastName)
        .where('barangay', isEqualTo: barangay)
        .limit(5)
        .get();

    for (final doc in snapshot.docs) {
      if (excludePwdId != null && doc.id == excludePwdId) continue;
      final data = doc.data();
      final docDob = data['dateOfBirth'] is Timestamp
          ? DateFormat('yyyy-MM-dd')
              .format((data['dateOfBirth'] as Timestamp).toDate())
          : '';
      if (docDob == dobString) return true;
    }
    return false;
  }

  // ── PAGINATED SEARCH & FILTER ──────────────────────────────────────────────
  /// Fetches first page with optional filters.
  Future<PWDPage> fetchFirstPage({
    String? barangay,
    String? disabilityType,
    String? ageGroup,
    String? searchName,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .limit(_pageSize);

    query = _applyFilters(
      query,
      barangay: barangay,
      disabilityType: disabilityType,
    );

    final snapshot = await query.get();
    var records =
        snapshot.docs.map((d) => PWDRecordModel.fromDocument(d)).toList();

    // Client-side filters (Firestore free tier doesn't support all compound queries)
    records = _clientSideFilter(
      records,
      ageGroup: ageGroup,
      searchName: searchName,
    );

    return PWDPage(
      records: records,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  /// Fetches next page.
  Future<PWDPage> fetchNextPage({
    required DocumentSnapshot lastDocument,
    String? barangay,
    String? disabilityType,
    String? ageGroup,
    String? searchName,
  }) async {
    Query query = _firestore
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(_pageSize);

    query = _applyFilters(
      query,
      barangay: barangay,
      disabilityType: disabilityType,
    );

    final snapshot = await query.get();
    var records =
        snapshot.docs.map((d) => PWDRecordModel.fromDocument(d)).toList();

    records = _clientSideFilter(
      records,
      ageGroup: ageGroup,
      searchName: searchName,
    );

    return PWDPage(
      records: records,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  /// Fetch most recently updated records (for dashboard widget).
  Future<List<PWDRecordModel>> fetchRecentlyUpdated({int limit = 5}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((d) => PWDRecordModel.fromDocument(d)).toList();
  }

  /// Count total PWD records (uses a counter document for free tier efficiency).
  /// Falls back to full collection count if counter not available.
  Future<int> getTotalCount() async {
    try {
      // Use AggregateQuery (available in Firestore SDK)
      final countQuery = await _firestore.collection(_collection).count().get();
      return countQuery.count ?? 0;
    } catch (_) {
      // Fallback for older SDK versions
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.length;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  Query _applyFilters(
    Query query, {
    String? barangay,
    String? disabilityType,
  }) {
    if (barangay != null && barangay.isNotEmpty) {
      query = query.where('barangay', isEqualTo: barangay);
    }
    if (disabilityType != null && disabilityType.isNotEmpty) {
      query = query.where('disabilityType', isEqualTo: disabilityType);
    }
    return query;
  }

  List<PWDRecordModel> _clientSideFilter(
    List<PWDRecordModel> records, {
    String? ageGroup,
    String? searchName,
  }) {
    var filtered = records;

    if (searchName != null && searchName.isNotEmpty) {
      final term = searchName.toLowerCase();
      filtered = filtered.where((r) {
        return r.fullName.toLowerCase().contains(term) ||
            r.pwdId.toLowerCase().contains(term);
      }).toList();
    }

    if (ageGroup != null && ageGroup.isNotEmpty) {
      filtered = filtered.where((r) => r.ageGroup == ageGroup).toList();
    }

    return filtered;
  }
}

// ── Pagination result ──────────────────────────────────────────────────────
class PWDPage {
  final List<PWDRecordModel> records;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  PWDPage({
    required this.records,
    required this.lastDocument,
    required this.hasMore,
  });
}
