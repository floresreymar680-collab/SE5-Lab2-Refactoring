// lib/screens/admin/audit_log_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sidebar_widget.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  String? _filterAction;
  DateTime? _fromDate;
  DateTime? _toDate;

  final List<String> _actionTypes = [
    'LOGIN',
    'LOGIN_FAILED',
    'LOGOUT',
    'PWD_CREATED',
    'PWD_UPDATED',
    'CHECKUP_RESULT_RECORDED',
    'BENEFIT_RECORDED',
    'DOCUMENT_LINKED',
    'ACCOUNT_CHANGED',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs(reset: true);
  }

  Future<void> _loadLogs({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _logs = [];
      _lastDocument = null;
      _hasMore = true;
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(AppConstants.auditLogPageSize);

      if (_filterAction != null && _filterAction!.isNotEmpty) {
        query = query.where('actionType', isEqualTo: _filterAction);
      }
      if (_fromDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_fromDate!));
      }
      if (_toDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo:
                Timestamp.fromDate(_toDate!.add(const Duration(days: 1))));
      }
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final newLogs =
          snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();

      setState(() {
        _logs = reset ? newLogs : [..._logs, ...newLogs];
        _hasMore = newLogs.length == AppConstants.auditLogPageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audit logs: $e'),
            backgroundColor: const Color(AppConstants.dangerRed),
          ),
        );
      }
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  void _applyFilters() => _loadLogs(reset: true);

  void _resetFilters() {
    setState(() {
      _filterAction = null;
      _fromDate = null;
      _toDate = null;
    });
    _loadLogs(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>().resetActivityTimer();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/admin/audit-log'),
      appBar: AppBar(
        title: const Text('Audit Log'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _logs.isEmpty && !_loading
                ? _buildEmptyState()
                : _buildLogList(),
          ),
        ],
      ),
    );
  }

  // ── FIXED FILTER BAR — no fixed widths, uses LayoutBuilder ───────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 600;

          final dropdownField = DropdownButtonFormField<String>(
            value: _filterAction,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Action Type',
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All')),
              ..._actionTypes.map(
                (a) => DropdownMenuItem(value: a, child: Text(a)),
              ),
            ],
            onChanged: (v) => setState(() => _filterAction = v),
          );

          final dateRow = Row(
            children: [
              Expanded(
                child: _DateChip(
                  label:
                      _fromDate == null ? 'From Date' : _formatDate(_fromDate!),
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateChip(
                  label: _toDate == null ? 'To Date' : _formatDate(_toDate!),
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ],
          );

          final actionRow = Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Apply'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Reset'),
                ),
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 3, child: dropdownField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: dateRow),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: actionRow),
              ],
            );
          }

          // Narrow layout — stack vertically
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(AppConstants.navyBlue),
                ),
              ),
              const SizedBox(height: 10),
              dropdownField,
              const SizedBox(height: 8),
              dateRow,
              const SizedBox(height: 8),
              actionRow,
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length + (_hasMore || _loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _logs.length) {
          return _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _loadLogs(),
                      icon: const Icon(Icons.expand_more, size: 16),
                      label: const Text('Load more'),
                    ),
                  ),
                );
        }
        return _buildLogCard(_logs[index]);
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final String action = log['actionType'] as String? ?? '';
    final String user = log['userFullName'] as String? ?? log['userId'] ?? '';
    final String role = log['role'] as String? ?? '';
    final String table = log['affectedTable'] as String? ?? '';
    final String? recordId = log['affectedRecordId'] as String?;
    final DateTime? ts = log['timestamp'] is Timestamp
        ? (log['timestamp'] as Timestamp).toDate()
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _actionColor(action).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                action,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _actionColor(action),
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.isNotEmpty ? user : 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (ts != null)
                        Text(
                          _formatDateTime(ts),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(label: role),
                      _InfoChip(label: 'Table: $table'),
                      if (recordId != null && recordId.isNotEmpty)
                        _InfoChip(
                          label:
                              'ID: ${recordId.length > 12 ? '${recordId.substring(0, 12)}…' : recordId}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No audit logs found',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'LOGIN':
        return const Color(AppConstants.successGreen);
      case 'LOGIN_FAILED':
        return const Color(AppConstants.dangerRed);
      case 'LOGOUT':
        return const Color(AppConstants.neutralGray);
      case 'PWD_CREATED':
        return const Color(AppConstants.lightBlue);
      case 'PWD_UPDATED':
        return const Color(AppConstants.warningYellow);
      case 'ACCOUNT_CHANGED':
        return const Color(AppConstants.accentGold);
      case 'BENEFIT_RECORDED':
        return const Color(AppConstants.successGreen);
      case 'CHECKUP_RESULT_RECORDED':
        return const Color(AppConstants.lightBlue);
      default:
        return const Color(AppConstants.neutralGray);
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _formatDateTime(DateTime dt) =>
      '${_formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Color(AppConstants.navyBlue)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(AppConstants.navyBlue),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );
  }
}
