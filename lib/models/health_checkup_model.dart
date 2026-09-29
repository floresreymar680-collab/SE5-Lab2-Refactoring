// lib/models/health_checkup_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// HealthCheckupModel — Firestore document for /health_checkups/{checkupId}
// Uses isCompleted: bool (NOT null checks) so Firestore can index it properly.
// Status is computed CLIENT-SIDE from scheduledDate vs today.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

class HealthCheckupModel {
  final String checkupId;
  final String pwdId;
  final String pwdFullName;
  final String barangay;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final bool isCompleted; // ← replaces isNull check; fully indexable
  final String resultNotes;
  final String recordedBy; // userId who recorded result
  final String recordedByName; // display name
  final DateTime createdAt;

  HealthCheckupModel({
    required this.checkupId,
    required this.pwdId,
    required this.pwdFullName,
    required this.barangay,
    required this.scheduledDate,
    this.completedDate,
    this.isCompleted = false,
    required this.resultNotes,
    required this.recordedBy,
    this.recordedByName = '',
    required this.createdAt,
  });

  // ── Status computed client-side ───────────────────────────────────────────
  String get status {
    if (isCompleted || completedDate != null)
      return AppConstants.statusCompleted;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final schedDate =
        DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    if (schedDate.isBefore(todayDate)) return AppConstants.statusOverdue;
    final threshold =
        todayDate.add(const Duration(days: AppConstants.upcomingCheckupDays));
    if (schedDate.compareTo(threshold) <= 0) return AppConstants.statusUpcoming;
    return AppConstants.statusScheduled;
  }

  // ── Firestore serialization ───────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'checkupId': checkupId,
        'pwdId': pwdId,
        'pwdFullName': pwdFullName,
        'barangay': barangay,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'completedDate':
            completedDate != null ? Timestamp.fromDate(completedDate!) : null,
        'isCompleted': isCompleted,
        'resultNotes': resultNotes,
        'recordedBy': recordedBy,
        'recordedByName': recordedByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory HealthCheckupModel.fromMap(Map<String, dynamic> m, String id) {
    DateTime? completedDate;
    if (m['completedDate'] != null) {
      completedDate = (m['completedDate'] as Timestamp).toDate();
    }
    return HealthCheckupModel(
      checkupId: id,
      pwdId: m['pwdId'] ?? '',
      pwdFullName: m['pwdFullName'] ?? '',
      barangay: m['barangay'] ?? '',
      scheduledDate: (m['scheduledDate'] as Timestamp).toDate(),
      completedDate: completedDate,
      isCompleted: m['isCompleted'] ?? false,
      resultNotes: m['resultNotes'] ?? '',
      recordedBy: m['recordedBy'] ?? '',
      recordedByName: m['recordedByName'] ?? '',
      createdAt: m['createdAt'] != null
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory HealthCheckupModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthCheckupModel.fromMap(data, doc.id);
  }

  HealthCheckupModel copyWith({
    DateTime? completedDate,
    bool? isCompleted,
    String? resultNotes,
    String? recordedBy,
    String? recordedByName,
  }) {
    return HealthCheckupModel(
      checkupId: checkupId,
      pwdId: pwdId,
      pwdFullName: pwdFullName,
      barangay: barangay,
      scheduledDate: scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      isCompleted: isCompleted ?? this.isCompleted,
      resultNotes: resultNotes ?? this.resultNotes,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedByName: recordedByName ?? this.recordedByName,
      createdAt: createdAt,
    );
  }
}
