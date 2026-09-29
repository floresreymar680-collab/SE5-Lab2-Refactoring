// lib/utils/checkup_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Health checkup status computation (client-side — no Cloud Functions needed)
// ─────────────────────────────────────────────────────────────────────────────

/// Computes the current status of a health checkup based on dates.
///
/// Rules (per SDS Section 3.1.3 and Phase 6 spec):
///   • completedDate != null              → 'completed'
///   • scheduledDate < today              → 'overdue'
///   • scheduledDate <= today + 14 days   → 'upcoming'
///   • else                              → 'scheduled'
String computeCheckupStatus(DateTime scheduledDate, DateTime? completedDate) {
  if (completedDate != null) return 'completed';

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final schedDate = DateTime(
    scheduledDate.year,
    scheduledDate.month,
    scheduledDate.day,
  );
  final fourteenDaysFromNow = todayDate.add(const Duration(days: 14));

  if (schedDate.isBefore(todayDate)) return 'overdue';
  if (!schedDate.isAfter(fourteenDaysFromNow)) return 'upcoming';
  return 'scheduled';
}

/// Returns a display-friendly label for a checkup status.
String checkupStatusLabel(String status) {
  switch (status) {
    case 'completed':
      return 'Completed';
    case 'overdue':
      return 'Overdue';
    case 'upcoming':
      return 'Upcoming';
    case 'scheduled':
      return 'Scheduled';
    default:
      return status;
  }
}
