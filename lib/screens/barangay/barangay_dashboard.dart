// lib/screens/barangay/barangay_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/health_checkup_service.dart';
import '../../models/health_checkup_model.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/stat_card_widget.dart';
import '../../widgets/status_badge_widget.dart';

class BarangayDashboard extends StatefulWidget {
  const BarangayDashboard({super.key});

  @override
  State<BarangayDashboard> createState() => _BarangayDashboardState();
}

class _BarangayDashboardState extends State<BarangayDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final HealthCheckupService _checkupService = HealthCheckupService();

  bool _loading = true;
  String? _error;

  int _overdueCount = 0;
  int _upcomingCount = 0;
  List<HealthCheckupModel> _overdueList = [];
  List<HealthCheckupModel> _upcomingList = [];
  List<Map<String, dynamic>> _recentPwds = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _fetchCheckups(),
        _fetchRecentPwds(),
      ]);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load dashboard data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCheckups() async {
    // Uses HealthCheckupService which filters client-side by isCompleted bool
    // No composite index required
    final overdue = await _checkupService.fetchOverdueCheckups(limit: 25);
    final upcoming = await _checkupService.fetchUpcomingCheckups(limit: 25);

    if (mounted) {
      setState(() {
        _overdueList = overdue;
        _upcomingList = upcoming;
        _overdueCount = overdue.length;
        _upcomingCount = upcoming.length;
      });
    }
  }

  Future<void> _fetchRecentPwds() async {
    final snap = await _db
        .collection('pwd_records')
        .orderBy('updatedAt', descending: true)
        .limit(5)
        .get();

    if (mounted) {
      setState(() {
        _recentPwds = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/barangay/dashboard'),
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
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
                    _buildSectionLabel('Overview'),
                    const SizedBox(height: 12),
                    _buildStatCards(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Quick Actions'),
                    const SizedBox(height: 12),
                    _buildQuickActions(context),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Overdue Checkups'),
                    const SizedBox(height: 12),
                    _buildCheckupList(_overdueList, 'overdue'),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Upcoming Checkups (within 14 days)'),
                    const SizedBox(height: 12),
                    _buildCheckupList(_upcomingList, 'upcoming'),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Recently Updated PWD Records'),
                    const SizedBox(height: 12),
                    _buildRecentPwds(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppConstants.appName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('Barangay Staff Dashboard',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: _fetchAll,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

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
        color: const Color(AppConstants.navyBlue),
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
              'Barangay Staff',
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
            value: _overdueCount.toString(),
            icon: Icons.warning_amber_outlined,
            accentColor: const Color(AppConstants.dangerRed),
            isLoading: _loading,
          ),
          StatCardWidget(
            title: 'Upcoming (≤14 days)',
            value: _upcomingCount.toString(),
            icon: Icons.event_outlined,
            accentColor: const Color(AppConstants.warningYellow),
            isLoading: _loading,
          ),
        ],
      );
    });
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        icon: Icons.person_add_outlined,
        label: 'Register New PWD',
        color: const Color(AppConstants.navyBlue),
        route: '/pwd/register',
      ),
      (
        icon: Icons.search_outlined,
        label: 'Search PWD Records',
        color: const Color(0xFF0277BD),
        route: '/pwd/list',
      ),
      (
        icon: Icons.medical_services_outlined,
        label: 'Record Check-Up Result',
        color: const Color(AppConstants.successGreen),
        route: '/health/checkups',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions.map((a) {
        return _QuickActionButton(
          icon: a.icon,
          label: a.label,
          color: a.color,
          onTap: () => Navigator.of(context).pushNamed(a.route),
        );
      }).toList(),
    );
  }

  Widget _buildCheckupList(List<HealthCheckupModel> list, String status) {
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: status == 'overdue'
            ? Icons.check_circle_outline
            : Icons.event_available_outlined,
        message: status == 'overdue'
            ? 'No overdue checkups.'
            : 'No upcoming checkups in the next 14 days.',
      );
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
          final dateStr = DateFormat('MMM d, y').format(item.scheduledDate);

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
                    status == 'overdue'
                        ? Icons.warning_outlined
                        : Icons.schedule_outlined,
                    color: status == 'overdue'
                        ? const Color(AppConstants.dangerRed)
                        : const Color(AppConstants.warningYellow),
                    size: 18,
                  ),
                ),
                title: Text(
                  item.pwdFullName.isNotEmpty ? item.pwdFullName : item.pwdId,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${item.barangay.isNotEmpty ? '${item.barangay} • ' : ''}Scheduled: $dateStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: StatusBadgeWidget(status: status),
                onTap: () =>
                    Navigator.of(context).pushNamed('/health/checkups'),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentPwds() {
    if (_recentPwds.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outlined,
        message: 'No PWD records found.',
      );
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
        children: _recentPwds.asMap().entries.map((entry) {
          final i = entry.key;
          final pwd = entry.value;
          final updatedAt = pwd['updatedAt'];
          String updatedStr = '—';
          if (updatedAt is Timestamp) {
            updatedStr = DateFormat('MMM d, y').format(updatedAt.toDate());
          }
          return Column(
            children: [
              if (i > 0) Divider(color: Colors.grey.shade100, height: 1),
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      const Color(AppConstants.navyBlue).withValues(alpha: 0.1),
                  child: Text(
                    ((pwd['firstName'] as String?) ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                        color: Color(AppConstants.navyBlue),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                title: Text(
                  '${pwd['firstName'] ?? ''} ${pwd['lastName'] ?? ''}'.trim(),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${pwd['barangay'] ?? '—'} • Updated $updatedStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 18),
                onTap: () => Navigator.of(context).pushNamed('/pwd/list'),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

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

// ── Quick action button ───────────────────────────────────────────────────────
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
