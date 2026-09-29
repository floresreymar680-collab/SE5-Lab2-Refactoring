// lib/screens/shared/pwd_list_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 5 — PWD Search and List Screen
// SDS §3.2.7 — Search bar, filter dropdowns, paginated results table (25/page),
// Export List (Admin only), View Profile link per row.
// Accessible by: Administrator, Barangay Staff, Health Center Staff (read-only)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/pwd_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pwd_service.dart';
import '../../widgets/sidebar_widget.dart';

class PWDListScreen extends StatefulWidget {
  const PWDListScreen({super.key});

  @override
  State<PWDListScreen> createState() => _PWDListScreenState();
}

class _PWDListScreenState extends State<PWDListScreen> {
  final PWDService _pwdService = PWDService();
  final _searchCtrl = TextEditingController();

  // ── Filter state ─────────────────────────────────────────────────────────────
  String? _selectedBarangay;
  String? _selectedDisabilityType;
  String? _selectedAgeGroup;
  String _searchTerm = '';

  // ── Pagination state ─────────────────────────────────────────────────────────
  List<PWDRecordModel> _records = [];
  PWDPage? _currentPage;
  bool _isLoading = false;
  bool _hasMore = false;
  int _currentPageNum = 1;
  int _totalShowing = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _currentPageNum = 1;
    });
    try {
      final page = await _pwdService.fetchFirstPage(
        barangay: _selectedBarangay,
        disabilityType: _selectedDisabilityType,
        ageGroup: _selectedAgeGroup,
        searchName: _searchTerm.isNotEmpty ? _searchTerm : null,
      );
      setState(() {
        _records = page.records;
        _currentPage = page;
        _hasMore = page.hasMore;
        _totalShowing = page.records.length;
      });
    } catch (e) {
      _showError('Failed to load records: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    if (_currentPage?.lastDocument == null || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final page = await _pwdService.fetchNextPage(
        lastDocument: _currentPage!.lastDocument!,
        barangay: _selectedBarangay,
        disabilityType: _selectedDisabilityType,
        ageGroup: _selectedAgeGroup,
        searchName: _searchTerm.isNotEmpty ? _searchTerm : null,
      );
      setState(() {
        _records = page.records;
        _currentPage = page;
        _hasMore = page.hasMore;
        _currentPageNum++;
        _totalShowing =
            (_currentPageNum - 1) * AppConstants.pageSize + page.records.length;
      });
    } catch (e) {
      _showError('Failed to load next page: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    setState(() => _searchTerm = _searchCtrl.text.trim());
    _loadFirstPage();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchTerm = '';
      _selectedBarangay = null;
      _selectedDisabilityType = null;
      _selectedAgeGroup = null;
    });
    _loadFirstPage();
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(AppConstants.dangerRed),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;
    final isHealthStaff = authProvider.isHealthStaff;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: isWide ? null : const SidebarWidget(currentRoute: '/pwd/list'),
      appBar: _buildAppBar(isWide, isAdmin, isHealthStaff),
      body: isWide
          ? Row(
              children: [
                const SidebarWidget(currentRoute: '/pwd/list'),
                Expanded(child: _buildContent(isAdmin, isHealthStaff)),
              ],
            )
          : _buildContent(isAdmin, isHealthStaff),
    );
  }

  AppBar _buildAppBar(bool isWide, bool isAdmin, bool isHealthStaff) {
    return AppBar(
      title: const Text('PWD Registry'),
      leading: isWide
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      actions: [
        if (!isHealthStaff)
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/pwd/register'),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add New PWD',
                style: TextStyle(color: Colors.white)),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildContent(bool isAdmin, bool isHealthStaff) {
    return Column(
      children: [
        _buildFilterPanel(),
        Expanded(
          child: _isLoading && _records.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
                  ? _buildEmptyState()
                  : _buildTableSection(isAdmin, isHealthStaff),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Filter panel
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFilterPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or PWD ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applySearch();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _applySearch(),
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applySearch,
                child: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter dropdowns
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  hint: 'All Barangays',
                  value: _selectedBarangay,
                  items: AppConstants.barangays,
                  onChanged: (v) => setState(() => _selectedBarangay = v),
                ),
                const SizedBox(width: 10),
                _buildFilterDropdown(
                  hint: 'All Disability Types',
                  value: _selectedDisabilityType,
                  items: AppConstants.disabilityTypes,
                  onChanged: (v) => setState(() => _selectedDisabilityType = v),
                ),
                const SizedBox(width: 10),
                _buildFilterDropdown(
                  hint: 'All Age Groups',
                  value: _selectedAgeGroup,
                  items: AppConstants.ageGroups,
                  onChanged: (v) => setState(() => _selectedAgeGroup = v),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          ...items.map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (v) {
          onChanged(v);
          _loadFirstPage();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Table section
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTableSection(bool isAdmin, bool isHealthStaff) {
    return Column(
      children: [
        // Table header bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                'Showing ${_records.length} record(s)  •  Page $_currentPageNum',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Spacer(),
              if (isAdmin)
                OutlinedButton.icon(
                  onPressed: _showExportNotice,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Export List'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        // Table
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
                          DataColumn(label: Text('PWD ID')),
                          DataColumn(label: Text('Full Name')),
                          DataColumn(label: Text('Barangay')),
                          DataColumn(label: Text('Purok')),
                          DataColumn(label: Text('Disability Type')),
                          DataColumn(label: Text('Last Updated')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _records.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final r = entry.value;
                          final rowNum =
                              (_currentPageNum - 1) * AppConstants.pageSize +
                                  idx +
                                  1;
                          return _buildDataRow(r, rowNum);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaginationRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildDataRow(PWDRecordModel r, int rowNum) {
    final dateStr = DateFormat('MMM d, yyyy').format(r.updatedAt);
    final shortId = r.pwdId.length > 8 ? r.pwdId.substring(0, 8) : r.pwdId;

    return DataRow(
      cells: [
        DataCell(
            Text('$rowNum', style: TextStyle(color: Colors.grey.shade500))),
        DataCell(
          Tooltip(
            message: r.pwdId,
            child: Text(
              '...${shortId.toUpperCase()}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        DataCell(Text(r.fullName,
            style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(r.barangay)),
        DataCell(Text(r.purok.isNotEmpty ? r.purok : '—')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(AppConstants.navyBlue).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.disabilityType,
              style: const TextStyle(
                  fontSize: 11, color: Color(AppConstants.navyBlue)),
            ),
          ),
        ),
        DataCell(Text(dateStr,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        DataCell(
          TextButton(
            onPressed: () => _openProfile(r.pwdId),
            child: const Text('View Profile'),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Pagination row
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPaginationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed:
              (_currentPageNum > 1 && !_isLoading) ? _loadFirstPage : null,
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
            'Page $_currentPageNum',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: (_hasMore && !_isLoading) ? _loadNextPage : null,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.navigate_next, size: 18),
          label: const Text('Next'),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchTerm.isNotEmpty ||
                    _selectedBarangay != null ||
                    _selectedDisabilityType != null
                ? 'No records found matching your filters.'
                : 'No PWD records yet.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 16),
          if (_searchTerm.isNotEmpty || _selectedBarangay != null)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  void _openProfile(String pwdId) {
    Navigator.of(context)
        .pushNamed('/pwd/profile', arguments: pwdId)
        .then((_) => _loadFirstPage()); // refresh after returning
  }

  void _showExportNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Export to Excel — available in Phase 8 (Reports module).'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
