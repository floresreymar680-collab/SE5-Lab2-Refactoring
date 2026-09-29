// lib/utils/benefit_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Benefit period computation (client-side)
// ─────────────────────────────────────────────────────────────────────────────

/// Derives the benefit distribution period from [dateReceived].
///
/// Q1 = Jan–Mar, Q2 = Apr–Jun, Q3 = Jul–Sep, Q4 = Oct–Dec
/// Format: 'Q1-2026', 'Q2-2026', etc.
String computeBenefitPeriod(DateTime dateReceived) {
  final month = dateReceived.month;
  final year = dateReceived.year;

  int quarter;
  if (month <= 3) {
    quarter = 1;
  } else if (month <= 6) {
    quarter = 2;
  } else if (month <= 9) {
    quarter = 3;
  } else {
    quarter = 4;
  }

  return 'Q$quarter-$year';
}

/// Returns a human-readable label for a quarter period.
/// e.g. 'Q1-2026' → 'Q1 2026 (Jan–Mar)'
String benefitPeriodLabel(String period) {
  if (period.isEmpty) return period;
  final parts = period.split('-');
  if (parts.length != 2) return period;

  final q = parts[0];
  final year = parts[1];

  String months;
  switch (q) {
    case 'Q1':
      months = 'Jan–Mar';
      break;
    case 'Q2':
      months = 'Apr–Jun';
      break;
    case 'Q3':
      months = 'Jul–Sep';
      break;
    case 'Q4':
      months = 'Oct–Dec';
      break;
    default:
      months = '';
  }

  return '$q $year ($months)';
}
