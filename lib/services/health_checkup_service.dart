// lib/services/health_checkup_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_checkup_model.dart';
import 'audit_log_service.dart';

class HealthCheckupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _collection = 'health_checkups';
  static const int _pageSize = 25;

  // ── CREATE checkup schedule ────────────────────────────────────────────────
  Future<String> createCheckup({
    required String pwdId,
    required String pwdFullName,
    required String barangay,
    required DateTime scheduledDate,
    required String actorUserId,
    required String actorFullName,
    required String actorRole,
  }) async {
    final docRef = _firestore.collection(_collection).doc();

    final checkup = HealthCheckupModel(
      checkupId: docRef.id,
      pwdId: pwdId,
      pwdFullName: pwdFullName,
      barangay: barangay,
      scheduledDate: scheduledDate,
      isCompleted: false,
      resultNotes: '',
      recordedBy: '',
      recordedByName: '',
      createdAt: DateTime.now(),
    );

    await docRef.set(checkup.toMap());

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: actorRole,
      actionType: 'PWD_UPDATED',
      affectedTable: 'health_checkups',
      affectedRecordId: docRef.id,
    );

    return docRef.id;
  }

  // ── RECORD result ──────────────────────────────────────────────────────────
  Future<void> recordCheckupResult({
    required String checkupId,
    required DateTime completedDate,
    required String resultNotes,
    required String actorUserId,
    required String actorFullName,
    required String actorRole,
  }) async {
    await _firestore.collection(_collection).doc(checkupId).update({
      'completedDate': Timestamp.fromDate(completedDate),
      'isCompleted': true,
      'resultNotes': resultNotes,
      'recordedBy': actorUserId,
      'recordedByName': actorFullName,
    });

    await AuditLogService().insertLog(
      userId: actorUserId,
      userFullName: actorFullName,
      role: actorRole,
      actionType: 'CHECKUP_RESULT_RECORDED',
      affectedTable: 'health_checkups',
      affectedRecordId: checkupId,
    );
  }

  // ── FETCH for a specific PWD ───────────────────────────────────────────────
  Future<List<HealthCheckupModel>> fetchCheckupsForPWD(String pwdId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('pwdId', isEqualTo: pwdId)
        .get();

    final list =
        snapshot.docs.map((d) => HealthCheckupModel.fromDocument(d)).toList();

    // Sort client-side — no composite index needed
    list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    return list;
  }

  // ── FETCH overdue (dashboard) ──────────────────────────────────────────────
  // Only filters by isCompleted == false (single-field index, auto-created)
  // Sorting and overdue detection done client-side — NO composite index needed
  Future<List<HealthCheckupModel>> fetchOverdueCheckups({
    String? barangay,
    int limit = 25,
  }) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Single-field filter only — no orderBy — avoids composite index
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: false)
        .limit(200)
        .get();

    var checkups =
        snapshot.docs.map((d) => HealthCheckupModel.fromDocument(d)).toList();

    // Client-side: keep only overdue
    checkups = checkups.where((c) {
      final schedDate = DateTime(
          c.scheduledDate.year, c.scheduledDate.month, c.scheduledDate.day);
      return schedDate.isBefore(todayDate);
    }).toList();

    // Client-side barangay filter
    if (barangay != null && barangay.isNotEmpty) {
      checkups = checkups.where((c) => c.barangay == barangay).toList();
    }

    // Sort most overdue first
    checkups.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return checkups.take(limit).toList();
  }

  // ── FETCH upcoming within 14 days (dashboard) ─────────────────────────────
  Future<List<HealthCheckupModel>> fetchUpcomingCheckups({
    String? barangay,
    int limit = 25,
  }) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final fourteenDaysLater = todayDate.add(const Duration(days: 14));

    // Single-field filter only — no orderBy — avoids composite index
    final snapshot = await _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: false)
        .limit(200)
        .get();

    var checkups =
        snapshot.docs.map((d) => HealthCheckupModel.fromDocument(d)).toList();

    // Client-side: keep only upcoming (today to +14 days)
    checkups = checkups.where((c) {
      final schedDate = DateTime(
          c.scheduledDate.year, c.scheduledDate.month, c.scheduledDate.day);
      return !schedDate.isBefore(todayDate) &&
          schedDate.compareTo(fourteenDaysLater) <= 0;
    }).toList();

    // Client-side barangay filter
    if (barangay != null && barangay.isNotEmpty) {
      checkups = checkups.where((c) => c.barangay == barangay).toList();
    }

    // Sort soonest first
    checkups.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return checkups.take(limit).toList();
  }

  // ── FETCH paginated (Health Checkup Screen) ────────────────────────────────
  // No orderBy in Firestore query — sort client-side to avoid composite index
  Future<CheckupPage> fetchCheckupPage({
    String? statusFilter,
    String? barangay,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore.collection(_collection).limit(_pageSize);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    var checkups =
        snapshot.docs.map((d) => HealthCheckupModel.fromDocument(d)).toList();

    // Client-side barangay filter
    if (barangay != null && barangay.isNotEmpty) {
      checkups = checkups.where((c) => c.barangay == barangay).toList();
    }

    // Client-side status filter
    if (statusFilter != null && statusFilter.isNotEmpty) {
      checkups = checkups.where((c) => c.status == statusFilter).toList();
    }

    // Sort by scheduledDate client-side
    checkups.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    return CheckupPage(
      checkups: checkups,
      lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == _pageSize,
    );
  }

  // ── Counts for dashboard ───────────────────────────────────────────────────
  Future<int> countOverdue() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final snapshot = await _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: false)
        .get();

    return snapshot.docs
        .map((d) => HealthCheckupModel.fromDocument(d))
        .where((c) {
      final schedDate = DateTime(
          c.scheduledDate.year, c.scheduledDate.month, c.scheduledDate.day);
      return schedDate.isBefore(todayDate);
    }).length;
  }

  Future<int> countUpcoming() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final fourteenDaysLater = todayDate.add(const Duration(days: 14));

    final snapshot = await _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: false)
        .get();

    return snapshot.docs
        .map((d) => HealthCheckupModel.fromDocument(d))
        .where((c) {
      final schedDate = DateTime(
          c.scheduledDate.year, c.scheduledDate.month, c.scheduledDate.day);
      return !schedDate.isBefore(todayDate) &&
          schedDate.compareTo(fourteenDaysLater) <= 0;
    }).length;
  }
}

// ── Pagination result ──────────────────────────────────────────────────────
class CheckupPage {
  final List<HealthCheckupModel> checkups;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  CheckupPage({
    required this.checkups,
    required this.lastDocument,
    required this.hasMore,
  });
}
