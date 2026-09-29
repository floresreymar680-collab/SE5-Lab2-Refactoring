// lib/screens/shared/health_checkup_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 6 — Health Check-Up Schedule Screen
// SDS §3.2.8
// Accessible by: Administrator, Barangay Staff, Health Center Staff
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/health_checkup_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/health_checkup_service.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/status_badge_widget.dart';

class HealthCheckupScreen extends StatefulWidget {
  const HealthCheckupScreen({super.key});

  @override
  State<HealthCheckupScreen> createState() => _HealthCheckupScreenState();
}

class _HealthCheckupScreenState extends State<HealthCheckupScreen> {
  final HealthCheckupService _service = HealthCheckupService();

  // ── Filter state ──────────────────────────────────────────────────────────
  String? _statusFilter; // null = All
  String? _barangayFilter;

  // ── Pagination state ──────────────────────────────────────────────────────
  List<HealthCheckupModel> _checkups = [];
  CheckupPage? _currentPage;
  bool _isLoading = false;
  bool _hasMore = false;
  int _pageNum = 1;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _pageNum = 1;
    });
    try {
      final page = await _service.fetchCheckupPage(
        statusFilter: _statusFilter,
        barangay: _barangayFilter,
      );
      setState(() {
        _checkups = page.checkups;
        _currentPage = page;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      _showError('Failed to load check-ups: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_currentPage?.lastDocument == null || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final page = await _service.fetchCheckupPage(
        statusFilter: _statusFilter,
        barangay: _barangayFilter,
        lastDocument: _currentPage!.lastDocument,
      );
      setState(() {
        _checkups = page.checkups;
        _currentPage = page;
        _hasMore = page.hasMore;
        _pageNum++;
      });
    } catch (e) {
      _showError('Failed to load next page: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: const Color(AppConstants.dangerRed)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer:
          isWide ? null : const SidebarWidget(currentRoute: '/health/checkups'),
      appBar: AppBar(
        title: const Text('Health Check-Up Schedule'),
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
      ),
      body: isWide
          ? Row(
              children: [
                const SidebarWidget(currentRoute: '/health/checkups'),
                Expanded(child: _buildContent()),
              ],
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _isLoading && _checkups.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _checkups.isEmpty
                  ? _buildEmptyState()
                  : _buildTable(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Status filter
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'All Statuses',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Statuses')),
                ...AppConstants.checkupStatuses.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(_capitalize(s)),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _loadFirstPage();
              },
            ),
          ),
          const SizedBox(width: 12),
          // Barangay filter
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: _barangayFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'All Barangays',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All Barangays')),
                ...AppConstants.barangays.map(
                  (b) => DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _barangayFilter = v);
                _loadFirstPage();
              },
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _barangayFilter = null;
              });
              _loadFirstPage();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Clear'),
          ),
          const Spacer(),
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(const Color(AppConstants.dangerRed), 'Overdue'),
        const SizedBox(width: 12),
        _legendDot(const Color(AppConstants.warningYellow), 'Upcoming'),
        const SizedBox(width: 12),
        _legendDot(const Color(AppConstants.successGreen), 'Scheduled'),
        const SizedBox(width: 12),
        _legendDot(Colors.grey, 'Completed'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Table
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    return Column(
      children: [
        // Header bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                'Showing ${_checkups.length} record(s)  •  Page $_pageNum',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(AppConstants.navyBlue)
                              .withValues(alpha: 0.05),
                        ),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(AppConstants.navyBlue),
                          fontSize: 13,
                        ),
                        dataTextStyle: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('No.')),
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Barangay')),
                          DataColumn(label: Text('Scheduled Date')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Last Result Date')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _checkups.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final c = entry.value;
                          final rowNum =
                              (_pageNum - 1) * AppConstants.pageSize + idx + 1;
                          return _buildRow(c, rowNum);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPagination(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(HealthCheckupModel c, int rowNum) {
    final schedStr = DateFormat('MMM d, yyyy').format(c.scheduledDate);
    final resultStr = c.completedDate != null
        ? DateFormat('MMM d, yyyy').format(c.completedDate!)
        : '—';

    return DataRow(
      cells: [
        DataCell(
            Text('$rowNum', style: TextStyle(color: Colors.grey.shade500))),
        DataCell(Text(c.pwdFullName,
            style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(c.barangay)),
        DataCell(Text(schedStr)),
        DataCell(StatusBadgeWidget(status: c.status)),
        DataCell(Text(resultStr,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        DataCell(
          ElevatedButton(
            onPressed: c.status == AppConstants.statusCompleted
                ? null
                : () => _showLogResultSheet(c),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Log Result'),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pagination
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _pageNum > 1 && !_isLoading ? _loadFirstPage : null,
          icon: const Icon(Icons.first_page, size: 18),
          label: const Text('First'),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(AppConstants.navyBlue),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Page $_pageNum',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _hasMore && !_isLoading ? _loadNextPage : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.navigate_next, size: 18),
          label: const Text('Next'),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Log Result Bottom Sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showLogResultSheet(HealthCheckupModel checkup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LogResultSheet(
        checkup: checkup,
        onSaved: () {
          Navigator.of(ctx).pop();
          _loadFirstPage();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-up result recorded successfully.'),
              backgroundColor: Color(AppConstants.successGreen),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _statusFilter != null || _barangayFilter != null
                ? 'No check-ups found for selected filters.'
                : 'No health check-up records yet.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          if (_statusFilter != null || _barangayFilter != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _statusFilter = null;
                  _barangayFilter = null;
                });
                _loadFirstPage();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Result Bottom Sheet Widget
// ─────────────────────────────────────────────────────────────────────────────
class _LogResultSheet extends StatefulWidget {
  final HealthCheckupModel checkup;
  final VoidCallback onSaved;

  const _LogResultSheet({
    required this.checkup,
    required this.onSaved,
  });

  @override
  State<_LogResultSheet> createState() => _LogResultSheetState();
}

class _LogResultSheetState extends State<_LogResultSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  DateTime? _completedDate;
  bool _isSaving = false;
  String? _dateError;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate:
          widget.checkup.scheduledDate.subtract(const Duration(days: 365)),
      lastDate: DateTime.now(), // cannot be future
    );
    if (picked != null) {
      setState(() {
        _completedDate = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _save() async {
    // Validate date
    if (_completedDate == null) {
      setState(() => _dateError = 'Please select a completed date.');
      return;
    }
    if (_completedDate!.isAfter(DateTime.now())) {
      setState(() => _dateError = 'Completed date cannot be a future date.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      await HealthCheckupService().recordCheckupResult(
        checkupId: widget.checkup.checkupId,
        completedDate: _completedDate!,
        resultNotes: _notesCtrl.text.trim(),
        actorUserId: user.userId,
        actorFullName: user.fullName,
        actorRole: user.role,
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving result: $e'),
            backgroundColor: const Color(AppConstants.dangerRed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    color: Color(AppConstants.navyBlue)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Log Check-Up Result — ${widget.checkup.pwdFullName}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(AppConstants.navyBlue)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Scheduled date info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(AppConstants.backgroundGray),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Scheduled: ${DateFormat('MMMM d, yyyy').format(widget.checkup.scheduledDate)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(width: 16),
                  StatusBadgeWidget(status: widget.checkup.status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Completed Date picker
            const Text(
              'Completed Date *',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _dateError != null
                        ? const Color(AppConstants.dangerRed)
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: _completedDate != null
                          ? const Color(AppConstants.navyBlue)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _completedDate != null
                          ? DateFormat('MMMM d, yyyy').format(_completedDate!)
                          : 'Select completed date',
                      style: TextStyle(
                        color: _completedDate != null
                            ? Colors.black87
                            : Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_dateError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _dateError!,
                  style: const TextStyle(
                      color: Color(AppConstants.dangerRed), fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),

            // Health findings / notes
            const Text(
              'Health Findings / Notes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter health findings, observations, or notes...',
              ),
            ),
            const SizedBox(height: 24),

            // Save / Cancel buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Result'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
