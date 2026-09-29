// lib/screens/shared/pwd_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/pwd_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pwd_service.dart';
import '../../services/health_checkup_service.dart';
import '../../widgets/sidebar_widget.dart';

class PWDRegistrationScreen extends StatefulWidget {
  const PWDRegistrationScreen({super.key});

  @override
  State<PWDRegistrationScreen> createState() => _PWDRegistrationScreenState();
}

class _PWDRegistrationScreenState extends State<PWDRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final PWDService _pwdService = PWDService();
  final HealthCheckupService _checkupService = HealthCheckupService();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController(); // ← textbox
  final _purokCtrl = TextEditingController();
  final _disabilityTypeCtrl = TextEditingController(); // ← textbox
  final _healthConditionCtrl = TextEditingController();

  // ── Form state ────────────────────────────────────────────────────────────
  DateTime? _dateOfBirth;
  int _computedAge = 0;
  String _gender = AppConstants.genderOptions.first;
  String _civilStatus = AppConstants.civilStatusOptions.first;
  String _disabilityClassification =
      AppConstants.disabilityClassifications.first;
  String _educationalBackground = AppConstants.educationalOptions.first;
  DateTime? _initialCheckupDate;

  bool _isSubmitting = false;
  bool _duplicateWarningShown = false;
  bool _overrideDuplicate = false;

  final _firstNameKey = GlobalKey();
  final _lastNameKey = GlobalKey();
  final _dobKey = GlobalKey();
  final _addressKey = GlobalKey();

  String? _dobError;
  String? _checkupDateError;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _barangayCtrl.dispose();
    _purokCtrl.dispose();
    _disabilityTypeCtrl.dispose();
    _healthConditionCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _computedAge = _calculateAge(picked);
        _dobError = null;
      });
    }
  }

  Future<void> _pickCheckupDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _initialCheckupDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select Initial Checkup Date',
    );
    if (picked != null) {
      setState(() {
        _initialCheckupDate = picked;
        _checkupDateError = null;
      });
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submit() async {
    bool hasError = false;
    if (_dateOfBirth == null) {
      setState(() => _dobError = 'Date of birth is required');
      hasError = true;
    }

    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || hasError) {
      _scrollToTop();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser!;

    if (!_overrideDuplicate) {
      setState(() => _isSubmitting = true);
      final isDuplicate = await _pwdService.checkDuplicate(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dateOfBirth: _dateOfBirth!,
        barangay: _barangayCtrl.text.trim(),
      );
      setState(() => _isSubmitting = false);

      if (isDuplicate && !_duplicateWarningShown) {
        _showDuplicateDialog();
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      final record = PWDRecordModel(
        pwdId: '',
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dateOfBirth: _dateOfBirth!,
        gender: _gender,
        civilStatus: _civilStatus,
        address: _addressCtrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        purok: _purokCtrl.text.trim(),
        disabilityType: _disabilityTypeCtrl.text.trim(),
        disabilityClassification: _disabilityClassification,
        educationalBackground: _educationalBackground,
        healthCondition: _healthConditionCtrl.text.trim(),
        createdBy: user.userId,
        createdAt: now,
        updatedAt: now,
      );

      final newPwdId = await _pwdService.createPWDRecord(
        record: record,
        actorUserId: user.userId,
        actorFullName: user.fullName,
        actorRole: user.role,
      );

      if (_initialCheckupDate != null) {
        await _checkupService.createCheckup(
          pwdId: newPwdId,
          pwdFullName:
              '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
          barangay: _barangayCtrl.text.trim(),
          scheduledDate: _initialCheckupDate!,
          actorUserId: user.userId,
          actorFullName: user.fullName,
          actorRole: user.role,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PWD record registered successfully.'),
            backgroundColor: Color(AppConstants.successGreen),
          ),
        );
        Navigator.of(context).pushReplacementNamed(
          '/pwd/profile',
          arguments: newPwdId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving record: $e'),
            backgroundColor: const Color(AppConstants.dangerRed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDuplicateDialog() {
    setState(() => _duplicateWarningShown = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: const Color(AppConstants.warningYellow), size: 24),
            const SizedBox(width: 8),
            const Text('Duplicate Record Found'),
          ],
        ),
        content: Text(
          'A PWD record with the same name, date of birth, and barangay '
          '(${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}, '
          '${DateFormat('MMM d, yyyy').format(_dateOfBirth!)}, '
          '${_barangayCtrl.text.trim()}) '
          'already exists.\n\nDo you want to proceed and save anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _duplicateWarningShown = false;
                _overrideDuplicate = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _overrideDuplicate = true);
              _submit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppConstants.warningYellow),
            ),
            child: const Text('Proceed Anyway'),
          ),
        ],
      ),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<AuthProvider>().resetActivityTimer();
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer:
          isWide ? null : const SidebarWidget(currentRoute: '/pwd/register'),
      appBar: _buildAppBar(isWide, context),
      body: isWide
          ? Row(
              children: [
                const SidebarWidget(currentRoute: '/pwd/register'),
                Expanded(child: _buildContent()),
              ],
            )
          : _buildContent(),
    );
  }

  AppBar _buildAppBar(bool isWide, BuildContext context) {
    return AppBar(
      title: const Text('Register New PWD'),
      leading: isWide
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      actions: [
        TextButton.icon(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
          label: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          _sectionCard(
            title: 'Section 1 — Personal Information',
            icon: Icons.person_outline,
            children: _buildPersonalInfoFields(),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Section 2 — Disability Information',
            icon: Icons.accessibility_new_outlined,
            children: _buildDisabilityFields(),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Section 3 — Educational Background',
            icon: Icons.school_outlined,
            children: _buildEducationFields(),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Section 4 — Health Condition',
            icon: Icons.health_and_safety_outlined,
            children: _buildHealthFields(),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Section 5 — Initial Checkup Schedule',
            icon: Icons.calendar_month_outlined,
            children: _buildCheckupFields(),
          ),
          const SizedBox(height: 24),
          _buildSubmitRow(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Section 1 — Personal Information ─────────────────────────────────────
  List<Widget> _buildPersonalInfoFields() {
    return [
      _requiredLabel('First Name'),
      const SizedBox(height: 6),
      TextFormField(
        key: _firstNameKey,
        controller: _firstNameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Enter first name'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'First name is required';
          if (v.trim().length < 2) return 'Must be at least 2 characters';
          return null;
        },
      ),
      const SizedBox(height: 14),

      _requiredLabel('Last Name'),
      const SizedBox(height: 6),
      TextFormField(
        key: _lastNameKey,
        controller: _lastNameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Enter last name'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Last name is required';
          if (v.trim().length < 2) return 'Must be at least 2 characters';
          return null;
        },
      ),
      const SizedBox(height: 14),

      // DOB + Age row
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _requiredLabel('Date of Birth'),
                const SizedBox(height: 6),
                GestureDetector(
                  key: _dobKey,
                  onTap: _pickDateOfBirth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                          _dateOfBirth != null
                              ? DateFormat('MMM d, yyyy').format(_dateOfBirth!)
                              : 'Select date',
                          style: TextStyle(
                            color: _dateOfBirth != null
                                ? Colors.black87
                                : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_dobError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      _dobError!,
                      style: const TextStyle(
                          color: Color(AppConstants.dangerRed), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Age (Auto)',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _dateOfBirth != null ? '$_computedAge years' : '—',
                    style: TextStyle(
                        fontSize: 14,
                        color: _dateOfBirth != null
                            ? Colors.black87
                            : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      _requiredLabel('Gender'),
      const SizedBox(height: 6),
      _buildDropdown<String>(
        value: _gender,
        items: AppConstants.genderOptions,
        onChanged: (v) => setState(() => _gender = v!),
      ),
      const SizedBox(height: 14),

      _requiredLabel('Civil Status'),
      const SizedBox(height: 6),
      _buildDropdown<String>(
        value: _civilStatus,
        items: AppConstants.civilStatusOptions,
        onChanged: (v) => setState(() => _civilStatus = v!),
      ),
      const SizedBox(height: 14),

      _requiredLabel('Complete Address'),
      const SizedBox(height: 6),
      TextFormField(
        key: _addressKey,
        controller: _addressCtrl,
        maxLines: 2,
        decoration:
            const InputDecoration(hintText: 'House No., Street, Sitio...'),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Address is required' : null,
      ),
      const SizedBox(height: 14),

      // ── BARANGAY — textbox ────────────────────────────────────────────────
      _requiredLabel('Barangay'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _barangayCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Enter barangay name',
          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Barangay is required' : null,
      ),
      const SizedBox(height: 14),

      const Text('Purok / Zone',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _purokCtrl,
        decoration: const InputDecoration(hintText: 'e.g. Purok 3, Zone A'),
      ),
    ];
  }

  // ── Section 2 — Disability ────────────────────────────────────────────────
  List<Widget> _buildDisabilityFields() {
    return [
      // ── DISABILITY TYPE — textbox ─────────────────────────────────────────
      _requiredLabel('Disability Type'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _disabilityTypeCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'e.g. Visual Impairment, Hearing Impairment...',
          prefixIcon: Icon(Icons.accessibility_new_outlined, size: 18),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'Disability type is required'
            : null,
      ),
      const SizedBox(height: 14),

      // Disability Classification stays as dropdown
      _requiredLabel('Disability Classification'),
      const SizedBox(height: 6),
      _buildDropdown<String>(
        value: _disabilityClassification,
        items: AppConstants.disabilityClassifications,
        onChanged: (v) => setState(() => _disabilityClassification = v!),
      ),
    ];
  }

  // ── Section 3 — Education ─────────────────────────────────────────────────
  List<Widget> _buildEducationFields() {
    return [
      _requiredLabel('Highest Level Attained'),
      const SizedBox(height: 6),
      _buildDropdown<String>(
        value: _educationalBackground,
        items: AppConstants.educationalOptions,
        onChanged: (v) => setState(() => _educationalBackground = v!),
      ),
    ];
  }

  // ── Section 4 — Health Condition ──────────────────────────────────────────
  List<Widget> _buildHealthFields() {
    return [
      const Text('Health Condition / Remarks',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(
        controller: _healthConditionCtrl,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText:
              'Describe current health condition, medications, or relevant medical history...',
        ),
      ),
    ];
  }

  // ── Section 5 — Checkup Schedule ─────────────────────────────────────────
  List<Widget> _buildCheckupFields() {
    return [
      const Text(
        'Initial Checkup Date (Optional)',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 4),
      Text(
        'If provided, a health checkup schedule will be created for this PWD.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickCheckupDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _checkupDateError != null
                  ? const Color(AppConstants.dangerRed)
                  : Colors.grey.shade400,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text(
                _initialCheckupDate != null
                    ? DateFormat('MMM d, yyyy').format(_initialCheckupDate!)
                    : 'Select checkup date (optional)',
                style: TextStyle(
                  color: _initialCheckupDate != null
                      ? Colors.black87
                      : Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_initialCheckupDate != null)
                GestureDetector(
                  onTap: () => setState(() => _initialCheckupDate = null),
                  child:
                      Icon(Icons.close, size: 16, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Submit row ────────────────────────────────────────────────────────────
  Widget _buildSubmitRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_isSubmitting ? 'Saving...' : 'Save Registration'),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionCard({
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

  Widget _requiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Color(AppConstants.dangerRed)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
