// lib/screens/health_center/health_center_dashboard.dart
// ─────────────────────────────────────────────────────────────────────────────
// Health Center Staff Dashboard — SDS wireframe 3.2.4
//
// Displays:
//   • PWDs with overdue health checkups
//   • PWDs with upcoming checkups within 14 days
//   • Sidebar: Health Check-Ups, PWD Records (read-only except health fields)
//   • Button: Record Check-Up Result per PWD
//
// FREE TIER rules: one-time .get(), limit 25, no real-time listeners
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../constants/firebase_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/stat_card_widget.dart';
import '../../widgets/status_badge_widget.dart';

class HealthCenterDashboard extends StatefulWidget {
  const HealthCenterDashboard({super.key});

  @override
  State<HealthCenterDashboard> createState() => _HealthCenterDashboardState();
}

class _HealthCenterDashboardState extends State<HealthCenterDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _overdueList = [];
  List<Map<String, dynamic>> _upcomingList = [];

  @override
  void initState() {
    super.initState();
    _fetchCheckups();
  }

  Future<void> _fetchCheckups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Overdue — sorted most overdue first
      final overdueSnap = await _db
          .collection(FirebaseConstants.healthCheckupsCollection)
          .where('status', isEqualTo: 'overdue')
          .orderBy('scheduledDate')
          .limit(25)
          .get();

      // Upcoming within 14 days
      final upcomingSnap = await _db
          .collection(FirebaseConstants.healthCheckupsCollection)
          .where('status', isEqualTo: 'upcoming')
          .orderBy('scheduledDate')
          .limit(25)
          .get();

      if (mounted) {
        setState(() {
          _overdueList =
              overdueSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _upcomingList =
              upcomingSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load checkup data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/health/dashboard'),
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _fetchCheckups,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeBanner(context),
                    const SizedBox(height: 24),

                    if (_error != null) _buildErrorBanner(_error!),

                    // Stat cards
                    _buildSectionLabel('Overview'),
                    const SizedBox(height: 12),
                    _buildStatCards(),
                    const SizedBox(height: 28),

                    // Quick action
                    _buildSectionLabel('Quick Action'),
                    const SizedBox(height: 12),
                    _buildRecordResultButton(context),
                    const SizedBox(height: 28),

                    // Overdue list
                    _buildSectionLabel('PWDs with Overdue Checkups'),
                    const SizedBox(height: 12),
                    _buildCheckupCard(
                      list: _overdueList,
                      status: 'overdue',
                      emptyMessage: 'No overdue checkups.',
                      emptyIcon: Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 28),

                    // Upcoming list
                    _buildSectionLabel(
                        'PWDs with Upcoming Checkups (within 14 days)'),
                    const SizedBox(height: 12),
                    _buildCheckupCard(
                      list: _upcomingList,
                      status: 'upcoming',
                      emptyMessage: 'No upcoming checkups in 14 days.',
                      emptyIcon: Icons.event_available_outlined,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(AppConstants.navyBlue),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.accessibility_new_rounded, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(AppConstants.appName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Health Center Dashboard',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: _fetchCheckups,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  // ── Welcome banner ────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00695C),
            const Color(0xFF00695C).withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${user?.fullName.split(' ').first ?? 'Staff'}!',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Health Center Staff',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat cards ────────────────────────────────────────────────────────────
  Widget _buildStatCards() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxis = constraints.maxWidth > 500 ? 2 : 1;
      return GridView.count(
        crossAxisCount: crossAxis,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: crossAxis == 2 ? 2.8 : 3.5,
        children: [
          StatCardWidget(
            title: 'Overdue Checkups',
            value: _overdueList.length.toString(),
            icon: Icons.warning_amber_outlined,
            accentColor: const Color(AppConstants.dangerRed),
            isLoading: _loading,
          ),
          StatCardWidget(
            title: 'Upcoming (≤14 days)',
            value: _upcomingList.length.toString(),
            icon: Icons.schedule_outlined,
            accentColor: const Color(AppConstants.warningYellow),
            isLoading: _loading,
          ),
        ],
      );
    });
  }

  // ── Record result CTA ─────────────────────────────────────────────────────
  Widget _buildRecordResultButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pushNamed('/health/checkups'),
        icon: const Icon(Icons.medical_services_outlined),
        label: const Text(
          'Record Check-Up Result',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ── Checkup card list ─────────────────────────────────────────────────────
  Widget _buildCheckupCard({
    required List<Map<String, dynamic>> list,
    required String status,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    if (list.isEmpty) {
      return _buildEmptyState(icon: emptyIcon, message: emptyMessage);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: list.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final sDate = item['scheduledDate'];
          String dateStr = '—';
          if (sDate is Timestamp) {
            dateStr = DateFormat('MMM d, y').format(sDate.toDate());
          }

          return Column(
            children: [
              if (i > 0) Divider(color: Colors.grey.shade100, height: 1),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: status == 'overdue'
                      ? const Color(AppConstants.dangerRed)
                          .withValues(alpha: 0.1)
                      : const Color(AppConstants.warningYellow)
                          .withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_outline,
                    color: status == 'overdue'
                        ? const Color(AppConstants.dangerRed)
                        : const Color(AppConstants.warningYellow),
                    size: 18,
                  ),
                ),
                title: Text(
                  item['pwdId'] ?? '—',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Scheduled: $dateStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadgeWidget(status: status),
                    const SizedBox(width: 8),
                    // Record result mini-button
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/health/checkups'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF00695C),
                      ),
                      child:
                          const Text('Record', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(AppConstants.navyBlue)),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: Colors.grey.shade300, size: 40),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(AppConstants.dangerRed).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(AppConstants.dangerRed).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(AppConstants.dangerRed), size: 16),
          const SizedBox(width: 8),
          Text(message,
              style: const TextStyle(
                  color: Color(AppConstants.dangerRed), fontSize: 13)),
        ],
      ),
    );
  }
}
