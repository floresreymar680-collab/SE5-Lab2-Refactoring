// lib/constants/app_constants.dart
// All fixed application constants — roles, disability types, barangay list, etc.

class AppConstants {
  // ─── User Roles ─────────────────────────────────────────────────────────────
  static const String roleAdmin = 'Administrator';
  static const String roleBarangay = 'Barangay Staff';
  static const String roleHealth = 'Health Center Staff';

  static const List<String> allRoles = [
    roleAdmin,
    roleBarangay,
    roleHealth,
  ];

  // ─── Barangays of District IV Sibalom, Antique ───────────────────────────────
  static const List<String> barangays = [
    'Alegria',
    'Araneta',
    'Arebasore',
    'Bagumbayan',
    'Balatucan',
    'Bonga',
    'Bulanao',
    'Cansadan',
    'Cubay Norte',
    'Cubay Sur',
    'Daan Banwa',
    'Dalid',
    'Don Esteban',
    'Durog',
    'Guia',
    'Igcabugao',
    'Igporo',
    'Igtumarom',
    'Ilongbukid',
    'Inayawan',
    'Indag-an',
    'Joyao-Joyao',
    'Lag-an',
    'Liwanag',
    'Lombayan',
    'Mac-Arthur',
    'Manhanip',
    'Maralag',
    'Mararison',
    'Morales',
    'Mostro',
    'Nauring',
    'Osorio',
    'Pajo',
    'Paloc Bigao',
    'Patlabawon',
    'Pawa',
    'Poblacion',
    'Salngan',
    'San Antonio',
    'San Fernando',
    'San Roque',
    'Silakat-Nonok',
    'Siljagon',
    'Sulanga',
    'Tigbalabag',
    'Tigbalogo',
    'Tinio-an',
    'Toya',
    'Tuburan',
    'Ugsod',
    'Valderama',
  ];

  // ─── Disability Types (per RA 7277) ──────────────────────────────────────────
  static const List<String> disabilityTypes = [
    'Visual Impairment',
    'Deaf or Hard of Hearing',
    'Speech and Language Impairment',
    'Orthopedic or Physical Disability',
    'Mental or Psychiatric Disability',
    'Intellectual Disability',
    'Learning Disability',
    'Autism Spectrum Disorder',
    'Chronic Illness',
    'Multiple Disabilities',
  ];

  // ─── Disability Classifications ──────────────────────────────────────────────
  static const List<String> disabilityClassifications = [
    'Mild',
    'Moderate',
    'Severe',
    'Total or Profound',
  ];

  // ─── Gender Options ──────────────────────────────────────────────────────────
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Other',
  ];

  // ─── Civil Status Options ────────────────────────────────────────────────────
  static const List<String> civilStatusOptions = [
    'Single',
    'Married',
    'Widowed',
    'Separated',
    'Live-in',
  ];

  // ─── Educational Background Options ─────────────────────────────────────────
  static const List<String> educationalOptions = [
    'No Formal Education',
    'Elementary Level',
    'Elementary Graduate',
    'High School Level',
    'High School Graduate',
    'Vocational / Technical',
    'College Level',
    'College Graduate',
    'Post-Graduate',
  ];

  // ─── Benefit Types ───────────────────────────────────────────────────────────
  static const List<String> benefitTypes = [
    'DSWD Cash Assistance',
    'Medical Equipment / Assistive Device',
    'PhilHealth Subsidy',
    'Educational Assistance',
    'Livelihood Program',
    'LGU Cash Assistance',
    'Medicines / Medical Supplies',
    'Housing Assistance',
    'Other',
  ];

  // ─── Checkup Statuses ────────────────────────────────────────────────────────
  static const String statusScheduled = 'scheduled';
  static const String statusUpcoming = 'upcoming';
  static const String statusOverdue = 'overdue';
  static const String statusCompleted = 'completed';

  static const List<String> checkupStatuses = [
    statusScheduled,
    statusUpcoming,
    statusOverdue,
    statusCompleted,
  ];

  // ─── Age Groups (for filtering) ──────────────────────────────────────────────
  static const String ageGroupChild = 'Child (0–12)';
  static const String ageGroupYouth = 'Youth (13–24)';
  static const String ageGroupAdult = 'Adult (25–59)';
  static const String ageGroupSenior = 'Senior (60+)';

  static const List<String> ageGroups = [
    ageGroupChild,
    ageGroupYouth,
    ageGroupAdult,
    ageGroupSenior,
  ];

  // ─── Document Types (link-based, no Storage needed) ──────────────────────────
  static const List<String> documentTypes = [
    'PDF',
    'Image',
    'Spreadsheet',
    'Other',
  ];

  // ─── Audit Action Types ──────────────────────────────────────────────────────
  static const String actionLogin = 'LOGIN';
  static const String actionLoginFailed = 'LOGIN_FAILED';
  static const String actionLogout = 'LOGOUT';
  static const String actionPwdCreated = 'PWD_CREATED';
  static const String actionPwdUpdated = 'PWD_UPDATED';
  static const String actionCheckupRecorded = 'CHECKUP_RESULT_RECORDED';
  static const String actionBenefitRecorded = 'BENEFIT_RECORDED';
  static const String actionDocumentLinked = 'DOCUMENT_LINKED';
  static const String actionAccountChanged = 'ACCOUNT_CHANGED';

  // ─── Pagination ──────────────────────────────────────────────────────────────
  static const int pageSize = 25;
  static const int auditLogPageSize = 50;
  static const int dashboardRecentCount = 5;
  static const int dashboardAuditCount = 10;

  // ─── Inactivity Timer ────────────────────────────────────────────────────────
  static const int inactivityMinutes = 10;

  // ─── Upcoming Checkup Threshold ──────────────────────────────────────────────
  static const int upcomingCheckupDays = 14;

  // ─── App Info ────────────────────────────────────────────────────────────────
  static const String appName = 'PWD Registry System';
  static const String appSubtitle = 'District IV — Sibalom, Antique';
  static const String appVersion = '1.0.0';

  // ─── UI Colors ───────────────────────────────────────────────────────────────
  static const int navyBlue = 0xFF1A3A6B;
  static const int lightBlue = 0xFF2E5FA3;
  static const int accentGold = 0xFFF5A623;
  static const int successGreen = 0xFF27AE60;
  static const int warningYellow = 0xFFF39C12;
  static const int dangerRed = 0xFFE74C3C;
  static const int neutralGray = 0xFF7F8C8D;
  static const int backgroundGray = 0xFFF5F6FA;
}
