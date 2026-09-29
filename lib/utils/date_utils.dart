// lib/utils/date_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Date utility functions used across the app (all client-side, no Functions)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:intl/intl.dart';

/// Computes age in full years from [dateOfBirth] to today.
int computeAge(DateTime dateOfBirth) {
  final today = DateTime.now();
  int age = today.year - dateOfBirth.year;
  // Subtract 1 if birthday hasn't occurred yet this year
  if (today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/// Formats a [DateTime] to a human-readable string.
/// Default: 'MMM d, yyyy'  → e.g. "Jan 5, 2026"
String formatDate(DateTime? date, {String pattern = 'MMM d, yyyy'}) {
  if (date == null) return '—';
  return DateFormat(pattern).format(date);
}

/// Formats a [DateTime] to include time.
/// e.g. "Jan 5, 2026 09:30 AM"
String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '—';
  return DateFormat('MMM d, yyyy hh:mm a').format(dateTime);
}

/// Returns true if [date] is today or in the past.
bool isDateInPastOrToday(DateTime date) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final checkDate = DateTime(date.year, date.month, date.day);
  return !checkDate.isAfter(todayDate);
}

/// Returns true if [date] is strictly in the future (after today).
bool isDateInFuture(DateTime date) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final checkDate = DateTime(date.year, date.month, date.day);
  return checkDate.isAfter(todayDate);
}

/// Returns the number of days between today and [date].
/// Negative = past, Positive = future.
int daysFromToday(DateTime date) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final checkDate = DateTime(date.year, date.month, date.day);
  return checkDate.difference(todayDate).inDays;
}
