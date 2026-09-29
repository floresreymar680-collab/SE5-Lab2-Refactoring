// lib/models/pwd_record_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// PWDRecordModel — maps to Firestore /pwd_records/{pwdId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_utils.dart' as app_date;

class PWDRecordModel {
  final String pwdId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final int age; // auto-computed from dateOfBirth
  final String gender; // 'Male' | 'Female' | 'Other'
  final String
      civilStatus; // 'Single' | 'Married' | 'Widowed' | 'Separated' | 'Live-in'
  final String address;
  final String barangay;
  final String purok;
  final String disabilityType;
  final String disabilityClassification;
  final String educationalBackground;
  final String healthCondition;
  final String createdBy; // userId
  final DateTime createdAt;
  final DateTime updatedAt;

  PWDRecordModel({
    required this.pwdId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.civilStatus,
    required this.address,
    required this.barangay,
    required this.purok,
    required this.disabilityType,
    required this.disabilityClassification,
    required this.educationalBackground,
    required this.healthCondition,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : age = app_date.computeAge(dateOfBirth);

  // ── Convenience getters ───────────────────────────────────────────────────
  String get fullName => '$firstName $lastName';

  String get ageGroup {
    if (age < 18) return 'Child';
    if (age < 30) return 'Youth';
    if (age < 60) return 'Adult';
    return 'Senior';
  }

  // ── Firestore → Model ──────────────────────────────────────────────────────
  factory PWDRecordModel.fromMap(Map<String, dynamic> map, String docId) {
    final dob = map['dateOfBirth'] is Timestamp
        ? (map['dateOfBirth'] as Timestamp).toDate()
        : DateTime.now();

    return PWDRecordModel(
      pwdId: docId,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      dateOfBirth: dob,
      gender: map['gender'] as String? ?? 'Male',
      civilStatus: map['civilStatus'] as String? ?? 'Single',
      address: map['address'] as String? ?? '',
      barangay: map['barangay'] as String? ?? '',
      purok: map['purok'] as String? ?? '',
      disabilityType: map['disabilityType'] as String? ?? '',
      disabilityClassification:
          map['disabilityClassification'] as String? ?? '',
      educationalBackground: map['educationalBackground'] as String? ?? '',
      healthCondition: map['healthCondition'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory PWDRecordModel.fromDocument(DocumentSnapshot doc) {
    return PWDRecordModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ── Model → Firestore ──────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'fullNameLower': fullName.toLowerCase(), // for search indexing
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'age': age,
      'gender': gender,
      'civilStatus': civilStatus,
      'address': address,
      'barangay': barangay,
      'purok': purok,
      'disabilityType': disabilityType,
      'disabilityClassification': disabilityClassification,
      'educationalBackground': educationalBackground,
      'healthCondition': healthCondition,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  PWDRecordModel copyWith({
    String? pwdId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? civilStatus,
    String? address,
    String? barangay,
    String? purok,
    String? disabilityType,
    String? disabilityClassification,
    String? educationalBackground,
    String? healthCondition,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PWDRecordModel(
      pwdId: pwdId ?? this.pwdId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      civilStatus: civilStatus ?? this.civilStatus,
      address: address ?? this.address,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      disabilityType: disabilityType ?? this.disabilityType,
      disabilityClassification:
          disabilityClassification ?? this.disabilityClassification,
      educationalBackground:
          educationalBackground ?? this.educationalBackground,
      healthCondition: healthCondition ?? this.healthCondition,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'PWDRecordModel(pwdId: $pwdId, fullName: $fullName, barangay: $barangay)';
}
