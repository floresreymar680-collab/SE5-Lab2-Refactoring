// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../constants/firebase_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/stat_card_widget.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loadingStats = true;
  bool _loadingLogs = true;
  String? _statsError;
  String? _logsError;

  int _totalPwds = 0;
  int _overdueCount = 0;
  int _upcomingCount = 0;
  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchRecentLogs();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });
    try {
      final pwdSnap = await _db
          .collection(FirebaseConstants.pwdRecordsCollection)
          .count()
          .get();

      final overdueSnap = await _db
          .collection(FirebaseConstants.healthCheckupsCollection)
          .where('status', isEqualTo: 'overdue')
          .count()
          .get();

      final upcomingSnap = await _db
          .collection(FirebaseConstants.healthCheckupsCollection)
          .where('status', isEqualTo: 'upcoming')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalPwds = pwdSnap.count ?? 0;
          _overdueCount = overdueSnap.count ?? 0;
          _upcomingCount = upcomingSnap.count ?? 0;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = 'Failed to load statistics.';
          _loadingStats = false;
        });
      }
    }
  }

  Future<void> _fetchRecentLogs() async {
    setState(() {
      _loadingLogs = true;
      _logsError = null;
    });
    try {
      final snap = await _db
          .collection(FirebaseConstants.auditLogsCollection)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (mounted) {
        setState(() {
          _recentLogs =
              snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _loadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logsError = 'Failed to load audit log.';
          _loadingLogs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/admin/dashboard'),
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetchStats(), _fetchRecentLogs()]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeBanner(context),
              const SizedBox(height: 24),
              if (_statsError != null) _buildErrorBanner(_statsError!),
              if (_logsError != null) _buildErrorBanner(_logsError!),
              _buildSectionLabel('Summary'),
              const SizedBox(height: 12),
              _buildStatCards(),
              const SizedBox(height: 28),
              _buildSectionLabel('Quick Actions'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 28),
              _buildSectionLabel('Recent Activity'),
              const SizedBox(height: 12),
              _buildRecentLogs(),
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
          tooltip: 'Navigation menu',
        ),
      ),
      title: Row(
        children: [
          const Icon(Icons.accessibility_new_rounded, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                'Administrator Dashboard',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Refresh',
          onPressed: () async {
            await Future.wait([_fetchStats(), _fetchRecentLogs()]);
          },
        ),
        const SizedBox(width: 4),
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
        gradient: LinearGradient(
          colors: [
            const Color(AppConstants.navyBlue),
            const Color(AppConstants.navyBlue).withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${user?.fullName.split(' ').first ?? 'Admin'}!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
              'Administrator',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxis = constraints.maxWidth > 600 ? 3 : 1;
        return GridView.count(
          crossAxisCount: crossAxis,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxis == 3 ? 2.2 : 3.5,
          children: [
            StatCardWidget(
              title: 'Total Registered PWDs',
              value: _totalPwds.toString(),
              icon: Icons.people_alt_outlined,
              accentColor: const Color(AppConstants.navyBlue),
              isLoading: _loadingStats,
              onTap: () => Navigator.of(context).pushNamed('/pwd/list'),
            ),
            StatCardWidget(
              title: 'Overdue Checkups',
              value: _overdueCount.toString(),
              icon: Icons.warning_amber_outlined,
              accentColor: const Color(AppConstants.dangerRed),
              isLoading: _loadingStats,
              onTap: () => Navigator.of(context).pushNamed('/health/checkups'),
            ),
            StatCardWidget(
              title: 'Upcoming (≤14 days)',
              value: _upcomingCount.toString(),
              icon: Icons.event_outlined,
              accentColor: const Color(AppConstants.warningYellow),
              isLoading: _loadingStats,
              onTap: () => Navigator.of(context).pushNamed('/health/checkups'),
            ),
          ],
        );
      },
    );
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
        icon: Icons.history_outlined,
        label: 'View Audit Log',
        color: const Color(0xFF5C35A0),
        route: '/admin/audit-log',
      ),
      (
        icon: Icons.bar_chart_outlined,
        label: 'Generate Report',
        color: const Color(AppConstants.successGreen),
        route: '/reports',
      ),
      (
        icon: Icons.manage_accounts_outlined,
        label: 'User Management',
        color: const Color(0xFF0277BD),
        route: '/admin/users',
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

  Widget _buildRecentLogs() {
    if (_loadingLogs) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recentLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        message: 'No recent activity found.',
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 3, child: _tableHeader('Timestamp')),
                Expanded(flex: 2, child: _tableHeader('User')),
                Expanded(flex: 2, child: _tableHeader('Action')),
                Expanded(flex: 2, child: _tableHeader('Affected')),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade200, height: 1),
          ...List.generate(_recentLogs.length, (i) {
            final log = _recentLogs[i];
            final ts = log['timestamp'];
            String timeStr = '—';
            if (ts is Timestamp) {
              timeStr = DateFormat('MM/dd HH:mm').format(ts.toDate());
            }

            // FIX: use userFullName, fall back to userId if old log
            final String displayUser =
                (log['userFullName'] as String?)?.isNotEmpty == true
                    ? log['userFullName'] as String
                    : log['userId'] as String? ?? '—';

            return _LogRow(
              isEven: i.isEven,
              timestamp: timeStr,
              user: displayUser, // FIX: was log['userId']
              action: log['actionType'] ?? '—',
              affected: log['affectedTable'] ?? '—',
            );
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/admin/audit-log'),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text(
                'View Full Audit Log',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(AppConstants.navyBlue),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: Colors.grey.shade300, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
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
          color: const Color(AppConstants.dangerRed).withValues(alpha: 0.3),
        ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final bool isEven;
  final String timestamp;
  final String user;
  final String action;
  final String affected;

  const _LogRow({
    required this.isEven,
    required this.timestamp,
    required this.user,
    required this.action,
    required this.affected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.grey.shade50 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              timestamp,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: _ActionChip(action: action),
          ),
          Expanded(
            flex: 2,
            child: Text(
              affected,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (action) {
      case AppConstants.actionLogin:
        color = const Color(AppConstants.navyBlue);
        break;
      case AppConstants.actionPwdCreated:
        color = const Color(AppConstants.successGreen);
        break;
      case AppConstants.actionPwdUpdated:
        color = const Color(AppConstants.warningYellow);
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.replaceAll('_', ' '),
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
