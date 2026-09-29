import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────
// Age Computation
// ─────────────────────────────────────────────

/// Computes age in full years from a date of birth.
int computeAge(DateTime dateOfBirth) {
  final today = DateTime.now();
  int age = today.year - dateOfBirth.year;
  final birthdayThisYear =
      DateTime(today.year, dateOfBirth.month, dateOfBirth.day);
  if (today.isBefore(birthdayThisYear)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

// ─────────────────────────────────────────────
// Age Group
// ─────────────────────────────────────────────

/// Returns an age group label based on age.
/// Child: 0-17, Youth: 18-35, Adult: 36-59, Senior: 60+
String getAgeGroup(int age) {
  if (age < 18) return 'Child';
  if (age <= 35) return 'Youth';
  if (age <= 59) return 'Adult';
  return 'Senior';
}

// ─────────────────────────────────────────────
// Benefit Period Computation
// ─────────────────────────────────────────────

/// Derives the benefit period quarter from a date.
/// Returns format: 'Q1-2026', 'Q2-2026', etc.
String computeBenefitPeriod(DateTime dateReceived) {
  final year = dateReceived.year;
  final month = dateReceived.month;

  String quarter;
  if (month >= 1 && month <= 3) {
    quarter = 'Q1';
  } else if (month >= 4 && month <= 6) {
    quarter = 'Q2';
  } else if (month >= 7 && month <= 9) {
    quarter = 'Q3';
  } else {
    quarter = 'Q4';
  }

  return '$quarter-$year';
}

// ─────────────────────────────────────────────
// Health Checkup Status Computation
// ─────────────────────────────────────────────

/// Computes the checkup status based on scheduled and completed dates.
/// - 'completed' : completedDate is not null
/// - 'overdue'   : scheduledDate < today (not completed)
/// - 'upcoming'  : today <= scheduledDate <= today + 14 days
/// - 'scheduled' : scheduledDate > today + 14 days
String computeCheckupStatus(DateTime scheduledDate, DateTime? completedDate) {
  if (completedDate != null) return 'completed';

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final scheduled =
      DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
  final upcoming = todayDate.add(const Duration(days: 14));

  if (scheduled.isBefore(todayDate)) return 'overdue';
  if (scheduled.compareTo(upcoming) <= 0) return 'upcoming';
  return 'scheduled';
}

// ─────────────────────────────────────────────
// Date Formatting
// ─────────────────────────────────────────────

/// Formats a DateTime to 'MM/dd/yyyy' (e.g., 04/26/2026).
String formatDate(DateTime date) {
  return DateFormat('MM/dd/yyyy').format(date);
}

/// Formats a DateTime to 'MMM dd, yyyy' (e.g., Apr 26, 2026).
String formatDateLong(DateTime date) {
  return DateFormat('MMM dd, yyyy').format(date);
}

/// Formats a DateTime to 'MMM dd, yyyy hh:mm a' (e.g., Apr 26, 2026 09:15 AM).
String formatDateTime(DateTime date) {
  return DateFormat('MMM dd, yyyy hh:mm a').format(date);
}

/// Formats a DateTime to 'yyyy-MM-dd' (e.g., 2026-04-26). Used for Firestore queries.
String formatDateISO(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

// ─────────────────────────────────────────────
// UUID Generation
// ─────────────────────────────────────────────

const _uuid = Uuid();

/// Generates a new UUID v4 string.
String generateUUID() {
  return _uuid.v4();
}

// ─────────────────────────────────────────────
// Input Validation Helpers
// ─────────────────────────────────────────────

/// Validates that a name contains only letters, spaces, hyphens.
bool isValidName(String name) {
  final regex = RegExp(r"^[a-zA-ZÀ-ÖØ-öø-ÿñÑ\s\-']+$");
  return regex.hasMatch(name.trim());
}

/// Validates that a date of birth is in the past.
bool isValidDateOfBirth(DateTime dob) {
  return dob.isBefore(DateTime.now());
}

/// Validates that a date is not in the future (e.g., date received, completed date).
bool isNotFutureDate(DateTime date) {
  final today = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  return !d.isAfter(t);
}

/// Validates password: min 12 chars, at least 1 uppercase, 1 digit, 1 special char.
bool isValidPassword(String password) {
  if (password.length < 12) return false;
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  return hasUpper && hasDigit && hasSpecial;
}

/// Validates username: alphanumeric, 6-50 chars.
bool isValidUsername(String username) {
  final regex = RegExp(r'^[a-zA-Z0-9_]{6,50}$');
  return regex.hasMatch(username);
}

/// Validates email format.
bool isValidEmail(String email) {
  final regex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
  return regex.hasMatch(email);
}

// ─────────────────────────────────────────────
// File Helpers
// ─────────────────────────────────────────────

/// Returns a safe storage path for a PWD document.
/// Format: documents/{pwdId}/{uuid}.{ext}
String buildStoragePath(String pwdId, String uuid, String mimeType) {
  String ext;
  switch (mimeType) {
    case 'application/pdf':
      ext = 'pdf';
      break;
    case 'image/jpeg':
      ext = 'jpg';
      break;
    case 'image/png':
      ext = 'png';
      break;
    default:
      ext = 'bin';
  }
  return 'documents/$pwdId/$uuid.$ext';
}

/// Returns the max allowed file size in bytes (10 MB).
int get maxFileSizeBytes => 10 * 1024 * 1024;

/// Returns the allowed MIME types for document upload.
List<String> get allowedMimeTypes => [
      'application/pdf',
      'image/jpeg',
      'image/png',
    ];
