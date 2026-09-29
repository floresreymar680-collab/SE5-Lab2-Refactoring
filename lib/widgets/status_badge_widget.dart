// lib/widgets/status_badge_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// StatusBadgeWidget — color-coded pill badge for checkup / account status.
// Colors per SDS §3.2.8:
//   completed  → green
//   upcoming   → yellow/amber
//   overdue    → red
//   scheduled  → blue
//   active     → green
//   inactive   → grey
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class StatusBadgeWidget extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final _BadgeStyle style = _styleFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.border, width: 1),
      ),
      child: Text(
        _labelFor(status),
        style: TextStyle(
          color: style.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _labelFor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'upcoming':
        return 'Upcoming';
      case 'overdue':
        return 'Overdue';
      case 'scheduled':
        return 'Scheduled';
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      default:
        return status;
    }
  }

  _BadgeStyle _styleFor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'active':
        return _BadgeStyle(
          background:
              const Color(AppConstants.successGreen).withValues(alpha: 0.12),
          border: const Color(AppConstants.successGreen).withValues(alpha: 0.4),
          text: const Color(0xFF1B5E20),
        );
      case 'upcoming':
        return _BadgeStyle(
          background:
              const Color(AppConstants.warningYellow).withValues(alpha: 0.15),
          border:
              const Color(AppConstants.warningYellow).withValues(alpha: 0.5),
          text: const Color(0xFF7B5000),
        );
      case 'overdue':
        return _BadgeStyle(
          background:
              const Color(AppConstants.dangerRed).withValues(alpha: 0.1),
          border: const Color(AppConstants.dangerRed).withValues(alpha: 0.4),
          text: const Color(AppConstants.dangerRed),
        );
      case 'scheduled':
        return _BadgeStyle(
          background:
              const Color(AppConstants.navyBlue).withValues(alpha: 0.08),
          border: const Color(AppConstants.navyBlue).withValues(alpha: 0.3),
          text: const Color(AppConstants.navyBlue),
        );
      case 'inactive':
        return _BadgeStyle(
          background: Colors.grey.withValues(alpha: 0.12),
          border: Colors.grey.withValues(alpha: 0.4),
          text: Colors.grey.shade700,
        );
      default:
        return _BadgeStyle(
          background: Colors.grey.shade100,
          border: Colors.grey.shade300,
          text: Colors.grey.shade700,
        );
    }
  }
}

class _BadgeStyle {
  final Color background;
  final Color border;
  final Color text;
  const _BadgeStyle({
    required this.background,
    required this.border,
    required this.text,
  });
}
