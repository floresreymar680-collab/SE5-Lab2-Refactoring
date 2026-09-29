// lib/screens/shared/pwd_profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 5 + Phase 10 — PWD Profile View and Edit Screen
// SDS §3.2.6 — Tab bar: Personal Data, Disability, Education, Health,
//              Checkup Schedule, Documents.
// Role restrictions enforced: Health Center Staff → health fields only.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/pwd_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pwd_service.dart';
import '../../widgets/sidebar_widget.dart';
import 'document_screen.dart';

class PWDProfileScreen extends StatefulWidget {
  const PWDProfileScreen({super.key});

  @override
  State<PWDProfileScreen> createState() => _PWDProfileScreenState();
}

class _PWDProfileScreenState extends State<PWDProfileScreen>
    with SingleTickerProviderStateMixin {
  final PWDService _pwdService = PWDService();

  late TabController _tabController;

  // ── Data ──────────────────────────────────────────────────────────────────
  PWDRecordModel? _record;
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  String? _pwdId;

  // ── Edit controllers ──────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _purokCtrl = TextEditingController();
  final _healthConditionCtrl = TextEditingController();

  DateTime? _editDob;
  String? _editGender;
  String? _editCivilStatus;
  String? _editBarangay;
  String? _editDisabilityType;
  String? _editDisabilityClassification;
  String? _editEducationalBackground;

  String? _dobError;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 6 tabs: Personal, Disability, Education, Health, Checkup Schedule, Documents
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pwdId == null) {
      _pwdId = ModalRoute.of(context)?.settings.arguments as String?;
      if (_pwdId != null) _loadRecord();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _purokCtrl.dispose();
    _healthConditionCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadRecord() async {
    if (_pwdId == null) return;
    setState(() => _isLoading = true);
    try {
      final record = await _pwdService.fetchPWDById(_pwdId!);
      if (record != null) {
        setState(() {
          _record = record;
          _populateEditControllers(record);
        });
      }
    } catch (e) {
      _showSnack('Error loading record: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateEditControllers(PWDRecordModel r) {
    _firstNameCtrl.text = r.firstName;
    _lastNameCtrl.text = r.lastName;
    _addressCtrl.text = r.address;
    _purokCtrl.text = r.purok;
    _healthConditionCtrl.text = r.healthCondition;
    _editDob = r.dateOfBirth;
    _editGender = r.gender;
    _editCivilStatus = r.civilStatus;
    _editBarangay = r.barangay;
    _editDisabilityType = r.disabilityType;
    _editDisabilityClassification = r.disabilityClassification;
    _editEducationalBackground = r.educationalBackground;
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
    if (_record == null) return;
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser!;
    final isHealthStaff = authProvider.isHealthStaff;

    bool hasError = false;
    if (!isHealthStaff && _editDob == null) {
      setState(() => _dobError = 'Date of birth is required');
      hasError = true;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || hasError) return;

    setState(() => _isSaving = true);
    try {
      PWDRecordModel updated;

      if (isHealthStaff) {
        await _pwdService.updateHealthFields(
          pwdId: _record!.pwdId,
          healthCondition: _healthConditionCtrl.text.trim(),
          actorUserId: user.userId,
          actorFullName: user.fullName,
        );
        updated = _record!.copyWith(
          healthCondition: _healthConditionCtrl.text.trim(),
          updatedAt: DateTime.now(),
        );
      } else {
        updated = _record!.copyWith(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          dateOfBirth: _editDob,
          gender: _editGender,
          civilStatus: _editCivilStatus,
          address: _addressCtrl.text.trim(),
          barangay: _editBarangay,
          purok: _purokCtrl.text.trim(),
          disabilityType: _editDisabilityType,
          disabilityClassification: _editDisabilityClassification,
          educationalBackground: _editEducationalBackground,
          healthCondition: _healthConditionCtrl.text.trim(),
          updatedAt: DateTime.now(),
        );
        await _pwdService.updatePWDRecord(
          record: updated,
          actorUserId: user.userId,
          actorFullName: user.fullName,
          actorRole: user.role,
        );
      }

      setState(() {
        _record = updated;
        _isEditMode = false;
      });
      _showSnack('Record updated successfully.');
    } catch (e) {
      _showSnack('Error saving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEdit() {
    if (_record != null) _populateEditControllers(_record!);
    setState(() {
      _isEditMode = false;
      _dobError = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();
    final authProvider = context.watch<AuthProvider>();
    final isHealthStaff = authProvider.isHealthStaff;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: isWide ? null : const SidebarWidget(currentRoute: '/pwd/list'),
      appBar: _buildAppBar(isWide, isHealthStaff),
      body: isWide
          ? Row(
              children: [
                const SidebarWidget(currentRoute: '/pwd/list'),
                Expanded(child: _buildBody(isHealthStaff)),
              ],
            )
          : _buildBody(isHealthStaff),
    );
  }

  AppBar _buildAppBar(bool isWide, bool isHealthStaff) {
    return AppBar(
      title: Text(_record != null ? _record!.fullName : 'PWD Profile'),
      leading: isWide
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
      actions: [
        if (_record != null && !_isEditMode)
          TextButton.icon(
            onPressed: () => setState(() => _isEditMode = true),
            icon:
                const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
            label: const Text('Edit', style: TextStyle(color: Colors.white)),
          ),
        if (_isEditMode) ...[
          TextButton(
            onPressed: _isSaving ? null : _cancelEdit,
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveChanges,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, color: Colors.white, size: 18),
            label: Text(
              _isSaving ? 'Saving...' : 'Save Changes',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        const SizedBox(width: 8),
      ],
      bottom: _record != null
          ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Disability'),
                Tab(text: 'Education'),
                Tab(text: 'Health'),
                Tab(text: 'Checkup Schedule'),
                Tab(text: 'Documents'),
              ],
            )
          : null,
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(bool isHealthStaff) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_record == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Record not found.',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildPersonalTab(isHealthStaff),
          _buildDisabilityTab(isHealthStaff),
          _buildEducationTab(isHealthStaff),
          _buildHealthTab(),
          _buildCheckupPlaceholderTab(),
          _buildDocumentsTab(),
        ],
      ),
    );
  }

  // ── TAB 1 — Personal ──────────────────────────────────────────────────────
  Widget _buildPersonalTab(bool isHealthStaff) {
    final canEdit = _isEditMode && !isHealthStaff;
    return _tabScroll([
      _profileHeader(),
      const SizedBox(height: 16),
      _infoCard(
        title: 'Personal Information',
        icon: Icons.person_outline,
        children: [
          _fieldRow(
            label: 'First Name *',
            child: canEdit
                ? TextFormField(
                    controller: _firstNameCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'First name is required'
                        : null,
                  )
                : _readOnlyField(_record!.firstName),
          ),
          _fieldRow(
            label: 'Last Name *',
            child: canEdit
                ? TextFormField(
                    controller: _lastNameCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Last name is required'
                        : null,
                  )
                : _readOnlyField(_record!.lastName),
          ),
          _fieldRow(
            label: 'Date of Birth *',
            child: canEdit
                ? _dobPickerField()
                : _readOnlyField(
                    DateFormat('MMMM d, yyyy').format(_record!.dateOfBirth)),
          ),
          _fieldRow(
            label: 'Age',
            child: _readOnlyField('${_record!.age} years old'),
          ),
          _fieldRow(
            label: 'Gender *',
            child: canEdit
                ? _dropdownField(
                    value: _editGender!,
                    items: AppConstants.genderOptions,
                    onChanged: (v) => setState(() => _editGender = v),
                  )
                : _readOnlyField(_record!.gender),
          ),
          _fieldRow(
            label: 'Civil Status *',
            child: canEdit
                ? _dropdownField(
                    value: _editCivilStatus!,
                    items: AppConstants.civilStatusOptions,
                    onChanged: (v) => setState(() => _editCivilStatus = v),
                  )
                : _readOnlyField(_record!.civilStatus),
          ),
          _fieldRow(
            label: 'Complete Address *',
            child: canEdit
                ? TextFormField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  )
                : _readOnlyField(_record!.address),
          ),
          _fieldRow(
            label: 'Barangay *',
            child: canEdit
                ? _dropdownField(
                    value: _editBarangay!,
                    items: AppConstants.barangays,
                    onChanged: (v) => setState(() => _editBarangay = v),
                  )
                : _readOnlyField(_record!.barangay),
          ),
          _fieldRow(
            label: 'Purok / Zone',
            child: canEdit
                ? TextFormField(controller: _purokCtrl)
                : _readOnlyField(
                    _record!.purok.isNotEmpty ? _record!.purok : '—'),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 2 — Disability ────────────────────────────────────────────────────
  Widget _buildDisabilityTab(bool isHealthStaff) {
    final canEdit = _isEditMode && !isHealthStaff;
    return _tabScroll([
      _infoCard(
        title: 'Disability Information',
        icon: Icons.accessibility_new_outlined,
        children: [
          _fieldRow(
            label: 'Disability Type *',
            child: canEdit
                ? _dropdownField(
                    value: _editDisabilityType!,
                    items: AppConstants.disabilityTypes,
                    onChanged: (v) => setState(() => _editDisabilityType = v),
                  )
                : _readOnlyField(_record!.disabilityType),
          ),
          _fieldRow(
            label: 'Classification *',
            child: canEdit
                ? _dropdownField(
                    value: _editDisabilityClassification!,
                    items: AppConstants.disabilityClassifications,
                    onChanged: (v) =>
                        setState(() => _editDisabilityClassification = v),
                  )
                : _disabilityBadge(_record!.disabilityClassification),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 3 — Education ─────────────────────────────────────────────────────
  Widget _buildEducationTab(bool isHealthStaff) {
    final canEdit = _isEditMode && !isHealthStaff;
    return _tabScroll([
      _infoCard(
        title: 'Educational Background',
        icon: Icons.school_outlined,
        children: [
          _fieldRow(
            label: 'Highest Level Attained *',
            child: canEdit
                ? _dropdownField(
                    value: _editEducationalBackground!,
                    items: AppConstants.educationalOptions,
                    onChanged: (v) =>
                        setState(() => _editEducationalBackground = v),
                  )
                : _readOnlyField(_record!.educationalBackground),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 4 — Health ────────────────────────────────────────────────────────
  Widget _buildHealthTab() {
    final canEdit = _isEditMode;
    return _tabScroll([
      if (_isEditMode)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(AppConstants.lightBlue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(AppConstants.lightBlue).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Color(AppConstants.lightBlue)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Health Center Staff can only edit the Health Condition field.',
                  style: TextStyle(
                      fontSize: 12, color: Color(AppConstants.lightBlue)),
                ),
              ),
            ],
          ),
        ),
      _infoCard(
        title: 'Health Condition',
        icon: Icons.health_and_safety_outlined,
        children: [
          _fieldRow(
            label: 'Health Condition / Remarks',
            child: canEdit
                ? TextFormField(
                    controller: _healthConditionCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          'Describe health condition, medications, or remarks...',
                    ),
                  )
                : _readOnlyField(
                    _record!.healthCondition.isNotEmpty
                        ? _record!.healthCondition
                        : 'No health condition recorded.',
                    multiline: true,
                  ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 5 — Checkup Schedule ──────────────────────────────────────────────
  Widget _buildCheckupPlaceholderTab() {
    return _tabScroll([
      _infoCard(
        title: 'Checkup Schedule',
        icon: Icons.calendar_month_outlined,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Checkup schedules are managed in the\nHealth Check-Ups module.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/health/checkups'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Go to Health Check-Ups'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 6 — Documents (Phase 10) ──────────────────────────────────────────
  Widget _buildDocumentsTab() {
    if (_record == null) return const SizedBox.shrink();
    return _tabScroll([
      _infoCard(
        title: 'Attached Documents',
        icon: Icons.folder_outlined,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.lightBlue)
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(AppConstants.lightBlue)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.folder_shared_outlined,
                          size: 18, color: Color(AppConstants.lightBlue)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Store document links from Google Drive or OneDrive. '
                          'No file size limits — completely free.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(AppConstants.lightBlue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Open documents button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DocumentScreen(
                            pwdId: _record!.pwdId,
                            pwdFullName: _record!.fullName,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('View / Manage Documents'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  // ── Profile header ────────────────────────────────────────────────────────
  Widget _profileHeader() {
    if (_record == null) return const SizedBox.shrink();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  const Color(AppConstants.navyBlue).withValues(alpha: 0.1),
              child: Text(
                _record!.firstName.isNotEmpty
                    ? _record!.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConstants.navyBlue),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _record!.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(AppConstants.navyBlue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _record!.disabilityType,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(Icons.location_on_outlined, _record!.barangay),
                      const SizedBox(width: 8),
                      _chip(Icons.cake_outlined, '${_record!.age} yrs'),
                      const SizedBox(width: 8),
                      _chip(Icons.person_outline, _record!.gender),
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

  // ── Shared UI helpers ─────────────────────────────────────────────────────
  Widget _tabScroll(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(AppConstants.navyBlue)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConstants.navyBlue),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _fieldRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _readOnlyField(String value, {bool multiline = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        maxLines: multiline ? null : 1,
        overflow: multiline ? null : TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dobPickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _editDob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _editDob = picked;
                _dobError = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: _dobError != null
                    ? const Color(AppConstants.dangerRed)
                    : Colors.grey.shade400,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  _editDob != null
                      ? DateFormat('MMMM d, yyyy').format(_editDob!)
                      : 'Select date',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        if (_dobError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _dobError!,
              style: const TextStyle(
                  color: Color(AppConstants.dangerRed), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(AppConstants.navyBlue).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(AppConstants.navyBlue)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(AppConstants.navyBlue),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _disabilityBadge(String classification) {
    final colors = {
      'Mild': Colors.green,
      'Moderate': Colors.orange,
      'Severe': Colors.red,
      'Total or Profound': Colors.purple,
    };
    final color = colors[classification] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        classification,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError
              ? const Color(AppConstants.dangerRed)
              : const Color(AppConstants.successGreen),
        ),
      );
    }
  }
}
