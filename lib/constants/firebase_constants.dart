// lib/constants/firebase_constants.dart
// Firestore collection and field name constants — avoids typos throughout the app.

class FirebaseConstants {
  // ─── Collection Names ────────────────────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String pwdRecordsCollection = 'pwd_records';
  static const String healthCheckupsCollection = 'health_checkups';
  static const String benefitRecordsCollection = 'benefit_records';
  static const String documentsCollection = 'documents';
  static const String auditLogsCollection = 'audit_logs';

  // ─── User Document Fields ────────────────────────────────────────────────────
  static const String fieldUserId = 'userId';
  static const String fieldFullName = 'fullName';
  static const String fieldUsername = 'username';
  static const String fieldEmail = 'email';
  static const String fieldRole = 'role';
  static const String fieldIsActive = 'isActive';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldCreatedBy = 'createdBy';

  // ─── PWD Record Fields ───────────────────────────────────────────────────────
  static const String fieldPwdId = 'pwdId';
  static const String fieldFirstName = 'firstName';
  static const String fieldLastName = 'lastName';
  static const String fieldDateOfBirth = 'dateOfBirth';
  static const String fieldAge = 'age';
  static const String fieldGender = 'gender';
  static const String fieldCivilStatus = 'civilStatus';
  static const String fieldAddress = 'address';
  static const String fieldBarangay = 'barangay';
  static const String fieldPurok = 'purok';
  static const String fieldDisabilityType = 'disabilityType';
  static const String fieldDisabilityClassification =
      'disabilityClassification';
  static const String fieldEducationalBackground = 'educationalBackground';
  static const String fieldHealthCondition = 'healthCondition';
  static const String fieldUpdatedAt = 'updatedAt';

  // ─── Health Checkup Fields ───────────────────────────────────────────────────
  static const String fieldCheckupId = 'checkupId';
  static const String fieldScheduledDate = 'scheduledDate';
  static const String fieldCompletedDate = 'completedDate';
  static const String fieldResultNotes = 'resultNotes';
  static const String fieldRecordedBy = 'recordedBy';
  static const String fieldStatus = 'status';

  // ─── Benefit Record Fields ───────────────────────────────────────────────────
  static const String fieldBenefitId = 'benefitId';
  static const String fieldBenefitType = 'benefitType';
  static const String fieldAmount = 'amount';
  static const String fieldSourceAgency = 'sourceAgency';
  static const String fieldDateReceived = 'dateReceived';
  static const String fieldBenefitPeriod = 'benefitPeriod';

  // ─── Document Fields (link-based, no Firebase Storage) ───────────────────────
  static const String fieldDocumentId = 'documentId';
  static const String fieldDocPwdId = 'pwdId';
  static const String fieldFileName = 'fileName';
  static const String fieldFileLink = 'fileLink';
  static const String fieldFileType = 'fileType';
  static const String fieldDescription = 'description';
  static const String fieldUploadedBy = 'uploadedBy';
  static const String fieldUploadedAt = 'uploadedAt';

  // ─── Audit Log Fields ────────────────────────────────────────────────────────
  static const String fieldLogId = 'logId';
  static const String fieldActionType = 'actionType';
  static const String fieldAffectedTable = 'affectedTable';
  static const String fieldAffectedRecordId = 'affectedRecordId';
  static const String fieldTimestamp = 'timestamp';
  static const String fieldIpAddress = 'ipAddress';
}
