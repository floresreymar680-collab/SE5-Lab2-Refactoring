// lib/models/audit_log_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// AuditLogModel — maps to Firestore /audit_logs/{logId}
// INSERT ONLY — no update or delete ever allowed (enforced by Firestore rules)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String logId;
  final String userId;
  final String userFullName; // snapshot at time of action
  final String role; // snapshot at time of action
  final String actionType; // see AppConstants.auditActions
  final String
      affectedTable; // 'users' | 'pwd_records' | 'health_checkups' | etc.
  final String? affectedRecordId; // null for login events
  final DateTime timestamp;
  final String ipAddress; // 'unknown' when unavailable on client

  AuditLogModel({
    required this.logId,
    required this.userId,
    required this.userFullName,
    required this.role,
    required this.actionType,
    required this.affectedTable,
    this.affectedRecordId,
    required this.timestamp,
    required this.ipAddress,
  });

  // ── Firestore → Model ──────────────────────────────────────────────────────
  factory AuditLogModel.fromMap(Map<String, dynamic> map, String docId) {
    return AuditLogModel(
      logId: docId,
      userId: map['userId'] as String? ?? '',
      userFullName: map['userFullName'] as String? ?? '',
      role: map['role'] as String? ?? '',
      actionType: map['actionType'] as String? ?? '',
      affectedTable: map['affectedTable'] as String? ?? '',
      affectedRecordId: map['affectedRecordId'] as String?,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      ipAddress: map['ipAddress'] as String? ?? 'unknown',
    );
  }

  factory AuditLogModel.fromDocument(DocumentSnapshot doc) {
    return AuditLogModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── Model → Firestore ──────────────────────────────────────────────────────
  // Only used by AuditLogService.insertLog()
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userFullName': userFullName,
      'role': role,
      'actionType': actionType,
      'affectedTable': affectedTable,
      'affectedRecordId': affectedRecordId,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
    };
  }

  @override
  String toString() =>
      'AuditLogModel(logId: $logId, action: $actionType, user: $userFullName, timestamp: $timestamp)';
}
