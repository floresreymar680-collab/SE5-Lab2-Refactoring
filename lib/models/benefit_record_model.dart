// lib/models/benefit_record_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// BenefitRecordModel — maps to Firestore /benefit_records/{benefitId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/benefit_utils.dart';

class BenefitRecordModel {
  final String benefitId;
  final String pwdId;
  final String pwdFullName; // denormalized for display
  final String benefitType;
  final double? amount; // null if non-monetary benefit
  final String sourceAgency;
  final DateTime dateReceived;
  final String benefitPeriod; // auto-computed e.g. 'Q1-2026'
  final String recordedBy; // userId
  final DateTime createdAt;

  BenefitRecordModel({
    required this.benefitId,
    required this.pwdId,
    required this.pwdFullName,
    required this.benefitType,
    this.amount,
    required this.sourceAgency,
    required this.dateReceived,
    required this.recordedBy,
    required this.createdAt,
  }) : benefitPeriod = computeBenefitPeriod(dateReceived);

  // Named constructor with explicit period (used when reading from Firestore)
  BenefitRecordModel._withPeriod({
    required this.benefitId,
    required this.pwdId,
    required this.pwdFullName,
    required this.benefitType,
    this.amount,
    required this.sourceAgency,
    required this.dateReceived,
    required this.benefitPeriod,
    required this.recordedBy,
    required this.createdAt,
  });

  // ── Firestore → Model ──────────────────────────────────────────────────────
  factory BenefitRecordModel.fromMap(Map<String, dynamic> map, String docId) {
    final dateReceived = map['dateReceived'] is Timestamp
        ? (map['dateReceived'] as Timestamp).toDate()
        : DateTime.now();

    return BenefitRecordModel._withPeriod(
      benefitId: docId,
      pwdId: map['pwdId'] as String? ?? '',
      pwdFullName: map['pwdFullName'] as String? ?? '',
      benefitType: map['benefitType'] as String? ?? '',
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      sourceAgency: map['sourceAgency'] as String? ?? '',
      dateReceived: dateReceived,
      benefitPeriod:
          map['benefitPeriod'] as String? ?? computeBenefitPeriod(dateReceived),
      recordedBy: map['recordedBy'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory BenefitRecordModel.fromDocument(DocumentSnapshot doc) {
    return BenefitRecordModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── Model → Firestore ──────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'pwdId': pwdId,
      'pwdFullName': pwdFullName,
      'benefitType': benefitType,
      'amount': amount,
      'sourceAgency': sourceAgency,
      'dateReceived': Timestamp.fromDate(dateReceived),
      'benefitPeriod': benefitPeriod,
      'recordedBy': recordedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  BenefitRecordModel copyWith({
    String? benefitId,
    String? pwdId,
    String? pwdFullName,
    String? benefitType,
    double? amount,
    String? sourceAgency,
    DateTime? dateReceived,
    String? recordedBy,
    DateTime? createdAt,
  }) {
    return BenefitRecordModel(
      benefitId: benefitId ?? this.benefitId,
      pwdId: pwdId ?? this.pwdId,
      pwdFullName: pwdFullName ?? this.pwdFullName,
      benefitType: benefitType ?? this.benefitType,
      amount: amount ?? this.amount,
      sourceAgency: sourceAgency ?? this.sourceAgency,
      dateReceived: dateReceived ?? this.dateReceived,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'BenefitRecordModel(benefitId: $benefitId, pwdId: $pwdId, benefitType: $benefitType, period: $benefitPeriod)';
}
