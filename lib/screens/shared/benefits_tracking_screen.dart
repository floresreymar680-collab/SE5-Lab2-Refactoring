// lib/screens/shared/benefits_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/benefit_record_model.dart';
import '../../models/pwd_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/benefit_service.dart';
import '../../services/pwd_service.dart';
import '../../utils/benefit_utils.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/stat_card_widget.dart';

class BenefitsTrackingScreen extends StatefulWidget {
  const BenefitsTrackingScreen({super.key});

  @override
  State<BenefitsTrackingScreen> createState() => _BenefitsTrackingScreenState();
}

class _BenefitsTrackingScreenState extends State<BenefitsTrackingScreen> {
  final BenefitService _benefitService = BenefitService();
  final PWDService _pwdService = PWDService();

  // ── All PWDs list (loaded on open) ────────────────────────────────────────
  List<PWDRecordModel> _allPwds = [];
  bool _loadingAll = true;

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Selected PWD ──────────────────────────────────────────────────────────
  PWDRecordModel? _selectedPWD;
  List<BenefitRecordModel> _benefits = [];
  bool _loadingBenefits = false;

  @override
  void initState() {
    super.initState();
    _loadAllPwds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load all PWDs on screen open ──────────────────────────────────────────
  Future<void> _loadAllPwds() async {
    setState(() => _loadingAll = true);
    try {
      final page = await _pwdService.fetchFirstPage();
      if (mounted) {
        setState(() => _allPwds = page.records);
      }
    } catch (e) {
      _showSnack('Failed to load PWD list: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  // ── Filtered list based on search query ───────────────────────────────────
  List<PWDRecordModel> get _filteredPwds {
    if (_searchQuery.trim().isEmpty) return _allPwds;
    final q = _searchQuery.trim().toLowerCase();
    return _allPwds.where((pwd) {
      return pwd.fullName.toLowerCase().contains(q) ||
          pwd.pwdId.toLowerCase().contains(q) ||
          pwd.barangay.toLowerCase().contains(q);
    }).toList();
  }

  // ── Select PWD & load benefits ────────────────────────────────────────────
  Future<void> _selectPWD(PWDRecordModel pwd) async {
    setState(() {
      _selectedPWD = pwd;
      _loadingBenefits = true;
    });
    try {
      final list = await _benefitService.fetchBenefitsForPWD(pwd.pwdId);
      setState(() => _benefits = list);
    } catch (e) {
      _showSnack('Failed to load benefits: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingBenefits = false);
    }
  }

  // ── Go back to PWD list ───────────────────────────────────────────────────
  void _clearSelection() {
    setState(() {
      _selectedPWD = null;
      _benefits = [];
    });
  }

  // ── Refresh benefits list ─────────────────────────────────────────────────
  Future<void> _refreshBenefits() async {
    if (_selectedPWD == null) return;
    setState(() => _loadingBenefits = true);
    try {
      final list =
          await _benefitService.fetchBenefitsForPWD(_selectedPWD!.pwdId);
      setState(() => _benefits = list);
    } catch (e) {
      _showSnack('Failed to refresh: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingBenefits = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            error ? const Color(AppConstants.dangerRed) : Colors.green.shade700,
      ),
    );
  }

  void _openAddBenefit() {
    if (_selectedPWD == null) {
      _showSnack('Please select a PWD first.', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddBenefitSheet(
        pwd: _selectedPWD!,
        onSaved: _refreshBenefits,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>().resetActivityTimer();

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/benefits'),
      appBar: AppBar(
        title: Text(
          _selectedPWD != null
              ? 'Benefits — ${_selectedPWD!.fullName}'
              : 'Benefits Tracking',
        ),
        leading: _selectedPWD != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelection,
                tooltip: 'Back to PWD list',
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        actions: [
          if (_selectedPWD != null)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              onPressed: _refreshBenefits,
              tooltip: 'Refresh',
            ),
        ],
      ),
      floatingActionButton: _selectedPWD != null
          ? FloatingActionButton.extended(
              onPressed: _openAddBenefit,
              backgroundColor: const Color(AppConstants.navyBlue),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Benefit'),
            )
          : null,
      body: _selectedPWD != null ? _buildBenefitsView() : _buildPWDListView(),
    );
  }

  // ── PWD List View (default view) ──────────────────────────────────────────
  Widget _buildPWDListView() {
    return Column(
      children: [
        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, ID, or barangay...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // Count bar
        Container(
          width: double.infinity,
          color: const Color(AppConstants.navyBlue).withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _loadingAll
                ? 'Loading PWD members...'
                : '${_filteredPwds.length} PWD member${_filteredPwds.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // List
        Expanded(
          child: _loadingAll
              ? const Center(child: CircularProgressIndicator())
              : _filteredPwds.isEmpty
                  ? _buildEmptyList()
                  : RefreshIndicator(
                      onRefresh: _loadAllPwds,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filteredPwds.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.grey.shade100, height: 1),
                        itemBuilder: (context, i) {
                          final pwd = _filteredPwds[i];
                          return _PWDListTile(
                            pwd: pwd,
                            onTap: () => _selectPWD(pwd),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No PWD found for "$_searchQuery"'
                : 'No PWD records found.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Benefits View (after selecting a PWD) ─────────────────────────────────
  Widget _buildBenefitsView() {
    return Column(
      children: [
        _buildSelectedPWDHeader(),
        _buildSummaryRow(),
        Expanded(child: _buildBenefitsList()),
      ],
    );
  }

  Widget _buildSelectedPWDHeader() {
    final pwd = _selectedPWD!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(AppConstants.navyBlue).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(AppConstants.navyBlue),
            child: Text(
              pwd.firstName.isNotEmpty ? pwd.firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pwd.fullName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pwd.barangay} · ${pwd.disabilityType}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                Text(
                  'Age: ${pwd.age} · ${pwd.gender}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              '${_benefits.length} benefit${_benefits.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalAmount =
        _benefits.fold<double>(0, (sum, b) => sum + (b.amount ?? 0));
    final monetary = _benefits.where((b) => b.amount != null).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: StatCardWidget(
              title: 'Total Records',
              value: '${_benefits.length}',
              icon: Icons.card_giftcard_outlined,
              accentColor: const Color(AppConstants.navyBlue),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCardWidget(
              title: 'Monetary',
              value: '$monetary',
              icon: Icons.attach_money,
              accentColor: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCardWidget(
              title: 'Total Amount',
              value: totalAmount > 0
                  ? '₱${NumberFormat('#,##0.00').format(totalAmount)}'
                  : '—',
              icon: Icons.savings_outlined,
              accentColor: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    if (_loadingBenefits) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_benefits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No benefits recorded yet',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + Add Benefit to record one',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshBenefits,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _benefits.length,
        itemBuilder: (context, i) => _BenefitCard(benefit: _benefits[i]),
      ),
    );
  }
}

// ── PWD List Tile ─────────────────────────────────────────────────────────────
class _PWDListTile extends StatelessWidget {
  final PWDRecordModel pwd;
  final VoidCallback onTap;

  const _PWDListTile({required this.pwd, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor:
            const Color(AppConstants.navyBlue).withValues(alpha: 0.12),
        child: Text(
          pwd.firstName.isNotEmpty ? pwd.firstName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(AppConstants.navyBlue),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        pwd.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${pwd.barangay} · ${pwd.disabilityType}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Age ${pwd.age}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── Benefit Card ──────────────────────────────────────────────────────────────
class _BenefitCard extends StatelessWidget {
  final BenefitRecordModel benefit;
  const _BenefitCard({required this.benefit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.navyBlue)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    benefit.benefitType,
                    style: const TextStyle(
                      color: Color(AppConstants.navyBlue),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    benefitPeriodLabel(benefit.benefitPeriod),
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                if (benefit.amount != null)
                  Text(
                    '₱${NumberFormat('#,##0.00').format(benefit.amount)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  )
                else
                  Text(
                    'Non-monetary',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.account_balance_outlined,
                  label: benefit.sourceAgency,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: DateFormat('MMM d, yyyy').format(benefit.dateReceived),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}

// ── Add Benefit Bottom Sheet ──────────────────────────────────────────────────
class _AddBenefitSheet extends StatefulWidget {
  final PWDRecordModel pwd;
  final VoidCallback onSaved;

  const _AddBenefitSheet({required this.pwd, required this.onSaved});

  @override
  State<_AddBenefitSheet> createState() => _AddBenefitSheetState();
}

class _AddBenefitSheetState extends State<_AddBenefitSheet> {
  final _formKey = GlobalKey<FormState>();
  final BenefitService _benefitService = BenefitService();

  String? _benefitType;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _agencyCtrl = TextEditingController();
  DateTime? _dateReceived;
  bool _isMonetary = true;

  bool _loading = false;
  bool _duplicateFound = false;
  bool _overrideConfirmed = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _agencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateReceived = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateReceived == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date received.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (!_overrideConfirmed) {
        final isDuplicate = await _benefitService.checkDuplicate(
          pwdId: widget.pwd.pwdId,
          benefitType: _benefitType!,
          dateReceived: _dateReceived!,
        );
        if (isDuplicate) {
          setState(() {
            _duplicateFound = true;
            _loading = false;
          });
          return;
        }
      }

      final auth = context.read<AuthProvider>();
      final user = auth.currentUser!;

      final record = BenefitRecordModel(
        benefitId: '',
        pwdId: widget.pwd.pwdId,
        pwdFullName: widget.pwd.fullName,
        benefitType: _benefitType!,
        amount: _isMonetary && _amountCtrl.text.isNotEmpty
            ? double.tryParse(_amountCtrl.text.replaceAll(',', ''))
            : null,
        sourceAgency: _agencyCtrl.text.trim(),
        dateReceived: _dateReceived!,
        recordedBy: user.userId,
        createdAt: DateTime.now(),
      );

      await _benefitService.createBenefitRecord(
        record: record,
        actorUserId: user.userId,
        actorFullName: user.fullName,
        actorRole: user.role,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Benefit recorded successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Add Benefit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              // PWD info chip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.navyBlue)
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Color(AppConstants.navyBlue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.pwd.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(AppConstants.navyBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Duplicate warning
              if (_duplicateFound && !_overrideConfirmed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Duplicate Detected',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A ${_benefitType ?? 'benefit'} record already exists '
                        'for this PWD in period ${_dateReceived != null ? benefitPeriodLabel(computeBenefitPeriod(_dateReceived!)) : ''}.',
                        style: TextStyle(
                            color: Colors.orange.shade800, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _duplicateFound = false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.orange.shade400),
                                foregroundColor: Colors.orange.shade800,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _overrideConfirmed = true;
                                  _duplicateFound = false;
                                });
                                _submit();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Confirm Override'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Benefit Type
              const Text('Benefit Type *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _benefitType,
                decoration:
                    const InputDecoration(hintText: 'Select benefit type'),
                items: AppConstants.benefitTypes
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _benefitType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Monetary toggle
              Row(
                children: [
                  const Text('Monetary Benefit',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Switch(
                    value: _isMonetary,
                    onChanged: (v) => setState(() => _isMonetary = v),
                    activeColor: const Color(AppConstants.navyBlue),
                  ),
                ],
              ),

              if (_isMonetary) ...[
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount (₱)',
                    prefixText: '₱ ',
                    hintText: '0.00',
                  ),
                  validator: (v) {
                    if (!_isMonetary) return null;
                    if (v == null || v.isEmpty) return 'Enter amount';
                    if (double.tryParse(v) == null) return 'Invalid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),

              // Source Agency
              const Text('Source Agency *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _agencyCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. DSWD, Municipal LGU, Barangay',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Date Received
              const Text('Date Received *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Select date',
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (_) => _dateReceived == null ? 'Required' : null,
                    controller: TextEditingController(
                      text: _dateReceived != null
                          ? DateFormat('MMMM d, yyyy').format(_dateReceived!)
                          : '',
                    ),
                  ),
                ),
              ),
              if (_dateReceived != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Period: ${benefitPeriodLabel(computeBenefitPeriod(_dateReceived!))}',
                    style:
                        TextStyle(color: Colors.amber.shade800, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Benefit Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
