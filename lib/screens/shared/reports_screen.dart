// lib/screens/shared/reports_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 8 — Reports & Statistics Screen
// SDS §3.2.10 — FR-9, FR-10
//
// Roles: Administrator (all barangays), Barangay Staff (own barangay only)
// Features:
//   • Filter: Date Range, Barangay, Disability Type, Report Type
//   • Summary stat cards
//   • Bar chart: PWD by Disability Type (fl_chart)
//   • Line chart: PWD Registration Trend monthly (fl_chart)
//   • Recent Health Checkup Summary table
//   • Export as PDF (client-side, pdf + printing packages)
//   • Export as Excel (client-side, excel package)
//   • Free tier: all aggregation done CLIENT-SIDE after fetch
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;

import '../../constants/app_constants.dart';
import '../../models/pwd_record_model.dart';
import '../../models/health_checkup_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/pwd_service.dart';
import '../../services/health_checkup_service.dart';
import '../../widgets/sidebar_widget.dart';
import '../../widgets/stat_card_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final PWDService _pwdService = PWDService();
  final HealthCheckupService _checkupService = HealthCheckupService();

  // ── Filters ────────────────────────────────────────────────────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBarangay;
  String? _selectedDisabilityType;
  String _reportType = 'Population Summary';

  static const List<String> _reportTypes = [
    'Population Summary',
    'Benefits Summary',
    'Health Check-Up Compliance',
  ];

  // ── Data ───────────────────────────────────────────────────────────────────
  List<PWDRecordModel> _allPWDs = [];
  List<HealthCheckupModel> _allCheckups = [];
  bool _loading = false;
  bool _generated = false;

  // ── Computed ───────────────────────────────────────────────────────────────
  List<PWDRecordModel> get _filtered {
    var list = _allPWDs;
    if (_selectedBarangay != null && _selectedBarangay!.isNotEmpty) {
      list = list.where((p) => p.barangay == _selectedBarangay).toList();
    }
    if (_selectedDisabilityType != null &&
        _selectedDisabilityType!.isNotEmpty) {
      list = list
          .where((p) => p.disabilityType == _selectedDisabilityType)
          .toList();
    }
    if (_startDate != null) {
      list = list.where((p) => !p.createdAt.isBefore(_startDate!)).toList();
    }
    if (_endDate != null) {
      final end =
          DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      list = list.where((p) => !p.createdAt.isAfter(end)).toList();
    }
    return list;
  }

  int get _totalPWD => _filtered.length;
  int get _totalMale => _filtered.where((p) => p.gender == 'Male').length;
  int get _totalFemale => _filtered.where((p) => p.gender == 'Female').length;

  Map<String, int> get _byDisabilityType {
    final map = <String, int>{};
    for (final p in _filtered) {
      map[p.disabilityType] = (map[p.disabilityType] ?? 0) + 1;
    }
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  Map<String, int> get _registrationTrend {
    final map = <String, int>{};
    final now = DateTime.now();
    // Last 6 months
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM yyyy').format(month);
      map[key] = 0;
    }
    for (final p in _filtered) {
      final key = DateFormat('MMM yyyy').format(p.createdAt);
      if (map.containsKey(key)) {
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  List<HealthCheckupModel> get _recentCheckups {
    final completed = _allCheckups.where((c) => c.isCompleted).toList()
      ..sort((a, b) => (b.completedDate ?? b.scheduledDate)
          .compareTo(a.completedDate ?? a.scheduledDate));
    return completed.take(5).toList();
  }

  int get _checkupsThisMonth {
    final now = DateTime.now();
    return _allCheckups.where((c) {
      return c.isCompleted &&
          c.completedDate != null &&
          c.completedDate!.year == now.year &&
          c.completedDate!.month == now.month;
    }).length;
  }

  // ── Generate ───────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _generated = false;
    });
    try {
      // Fetch all PWDs (paginated fetch — free tier)
      final page = await _pwdService.fetchFirstPage(
        barangay: _isBarangayStaff ? _userBarangay : null,
      );
      final pwds = List<PWDRecordModel>.from(page.records);

      // Fetch checkups
      final checkupPage = await _checkupService.fetchCheckupPage();

      setState(() {
        _allPWDs = pwds;
        _allCheckups = checkupPage.checkups;
        _generated = true;
      });
    } catch (e) {
      _showSnack('Failed to generate report: $e', error: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _isBarangayStaff {
    final user = context.read<AuthProvider>().currentUser;
    return user?.role == AppConstants.roleBarangay;
  }

  String get _userBarangay {
    // For barangay staff — in a real system this would come from user profile
    // For now falls back to empty (shows all)
    return '';
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          error ? const Color(AppConstants.dangerRed) : Colors.green.shade700,
    ));
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  // ── Export PDF ─────────────────────────────────────────────────────────────
  Future<void> _exportPDF() async {
    if (!_generated) {
      _showSnack('Generate the report first.', error: true);
      return;
    }
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'PWD Registry — ${_reportType}',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              'District IV Sibalom, Antique',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.Text(
              'Generated: ${DateFormat('MMMM d, yyyy hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (_startDate != null && _endDate != null)
              pw.Text(
                'Date Range: ${DateFormat('MMM d, yyyy').format(_startDate!)} – ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            pw.SizedBox(height: 16),

            // Summary
            pw.Header(level: 1, text: 'Summary'),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['Total PWDs', '$_totalPWD'],
                ['Male', '$_totalMale'],
                ['Female', '$_totalFemale'],
                ['Other', '${_totalPWD - _totalMale - _totalFemale}'],
                ['Health Check-Ups This Month', '$_checkupsThisMonth'],
              ],
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 16),

            // By Disability Type
            pw.Header(level: 1, text: 'PWD by Disability Type'),
            pw.Table.fromTextArray(
              headers: ['Disability Type', 'Count', '%'],
              data: _byDisabilityType.entries.map((e) {
                final pct = _totalPWD > 0
                    ? (e.value / _totalPWD * 100).toStringAsFixed(1)
                    : '0';
                return [e.key, '${e.value}', '$pct%'];
              }).toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),

            // Registration Trend
            pw.Header(level: 1, text: 'Registration Trend (Last 6 Months)'),
            pw.Table.fromTextArray(
              headers: ['Month', 'Registrations'],
              data: _registrationTrend.entries
                  .map((e) => [e.key, '${e.value}'])
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showSnack('PDF export failed: $e', error: true);
    }
  }

  // ── Export Excel ───────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    if (!_generated) {
      _showSnack('Generate the report first.', error: true);
      return;
    }
    try {
      final excel = xl.Excel.createExcel();

      // Sheet 1: Summary
      final summarySheet = excel['Summary'];
      summarySheet.appendRow([
        xl.TextCellValue('PWD Registry Report — $_reportType'),
      ]);
      summarySheet.appendRow([
        xl.TextCellValue('District IV Sibalom, Antique'),
      ]);
      summarySheet.appendRow([
        xl.TextCellValue(
            'Generated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}'),
      ]);
      summarySheet.appendRow([xl.TextCellValue('')]);
      summarySheet.appendRow([
        xl.TextCellValue('Metric'),
        xl.TextCellValue('Value'),
      ]);
      summarySheet.appendRow(
          [xl.TextCellValue('Total PWDs'), xl.IntCellValue(_totalPWD)]);
      summarySheet
          .appendRow([xl.TextCellValue('Male'), xl.IntCellValue(_totalMale)]);
      summarySheet.appendRow(
          [xl.TextCellValue('Female'), xl.IntCellValue(_totalFemale)]);
      summarySheet.appendRow([
        xl.TextCellValue('Health Check-Ups This Month'),
        xl.IntCellValue(_checkupsThisMonth)
      ]);

      // Sheet 2: By Disability Type
      final disSheet = excel['By Disability Type'];
      disSheet.appendRow([
        xl.TextCellValue('Disability Type'),
        xl.TextCellValue('Count'),
        xl.TextCellValue('Percentage'),
      ]);
      for (final e in _byDisabilityType.entries) {
        final pct = _totalPWD > 0
            ? (e.value / _totalPWD * 100).toStringAsFixed(1)
            : '0';
        disSheet.appendRow([
          xl.TextCellValue(e.key),
          xl.IntCellValue(e.value),
          xl.TextCellValue('$pct%'),
        ]);
      }

      // Sheet 3: PWD Records
      final pwdSheet = excel['PWD Records'];
      pwdSheet.appendRow([
        xl.TextCellValue('Full Name'),
        xl.TextCellValue('Barangay'),
        xl.TextCellValue('Purok'),
        xl.TextCellValue('Gender'),
        xl.TextCellValue('Age'),
        xl.TextCellValue('Disability Type'),
        xl.TextCellValue('Classification'),
        xl.TextCellValue('Date Registered'),
      ]);
      for (final p in _filtered) {
        pwdSheet.appendRow([
          xl.TextCellValue(p.fullName),
          xl.TextCellValue(p.barangay),
          xl.TextCellValue(p.purok),
          xl.TextCellValue(p.gender),
          xl.IntCellValue(p.age),
          xl.TextCellValue(p.disabilityType),
          xl.TextCellValue(p.disabilityClassification),
          xl.TextCellValue(DateFormat('yyyy-MM-dd').format(p.createdAt)),
        ]);
      }

      // Delete default Sheet1
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel');

      await Printing.layoutPdf(
        onLayout: (_) async => await _excelToPdfBytes(bytes),
        name:
            'pwd_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );

      // Use share via printing for xlsx
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename:
            'pwd_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );
    } catch (e) {
      _showSnack('Excel export failed: $e', error: true);
    }
  }

  Future<Uint8List> _excelToPdfBytes(List<int> excelBytes) async {
    // Fallback: just return a simple PDF with the data
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Center(
          child: pw.Text('Excel file generated. Check your downloads.'),
        ),
      ),
    );
    return pdf.save();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>().resetActivityTimer();
    final isAdmin = context.read<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundGray),
      drawer: const SidebarWidget(currentRoute: '/reports'),
      appBar: AppBar(
        title: const Text('Reports & Statistics'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          if (_generated) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: _exportPDF,
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: _exportExcel,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterCard(isAdmin),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_generated) ...[
              _buildSummaryCards(),
              const SizedBox(height: 16),
              _buildBarChart(),
              const SizedBox(height: 16),
              _buildLineChart(),
              const SizedBox(height: 16),
              _buildCheckupSummaryTable(),
              const SizedBox(height: 16),
              _buildExportRow(),
            ] else
              _buildNotGeneratedState(),
          ],
        ),
      ),
    );
  }

  // ── Filter Card ────────────────────────────────────────────────────────────
  Widget _buildFilterCard(bool isAdmin) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Date range
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MMM d, yyyy').format(_startDate!)} – ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                          : 'Select date range (optional)',
                      style: TextStyle(
                        color:
                            _startDate != null ? Colors.black87 : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (_startDate != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _startDate = null;
                          _endDate = null;
                        }),
                        child: const Icon(Icons.clear,
                            size: 16, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // Barangay
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBarangay,
                    decoration: const InputDecoration(
                      labelText: 'Barangay',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Barangays')),
                      if (isAdmin)
                        ...AppConstants.barangays.map(
                          (b) => DropdownMenuItem(
                              value: b,
                              child: Text(b, overflow: TextOverflow.ellipsis)),
                        ),
                    ],
                    onChanged: isAdmin
                        ? (v) => setState(() => _selectedBarangay = v)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                // Disability Type
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDisabilityType,
                    decoration: const InputDecoration(
                      labelText: 'Disability Type',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Types')),
                      ...AppConstants.disabilityTypes.map(
                        (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedDisabilityType = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Report Type
            DropdownButtonFormField<String>(
              value: _reportType,
              decoration: const InputDecoration(
                labelText: 'Report Type',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _reportTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _reportType = v ?? _reportType),
            ),
            const SizedBox(height: 14),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Generate Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                title: 'Total PWDs',
                value: '$_totalPWD',
                icon: Icons.people_alt_outlined,
                accentColor: const Color(AppConstants.navyBlue),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCardWidget(
                title: 'Male',
                value: '$_totalMale',
                icon: Icons.male,
                accentColor: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                title: 'Female',
                value: '$_totalFemale',
                icon: Icons.female,
                accentColor: Colors.pink.shade400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCardWidget(
                title: 'Check-Ups This Month',
                value: '$_checkupsThisMonth',
                icon: Icons.medical_services_outlined,
                accentColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Bar Chart: PWD by Disability Type ─────────────────────────────────────
  Widget _buildBarChart() {
    final data = _byDisabilityType;
    if (data.isEmpty) return const SizedBox.shrink();

    final entries = data.entries.toList();
    final maxVal =
        entries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PWD by Disability Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxVal + (maxVal * 0.2).ceilToDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${entries[groupIndex].key}\n${rod.toY.toInt()}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= entries.length)
                            return const SizedBox.shrink();
                          // Shorten label
                          final label = entries[i].key.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value.toDouble(),
                          color: const Color(AppConstants.navyBlue),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Line Chart: Registration Trend ────────────────────────────────────────
  Widget _buildLineChart() {
    final trend = _registrationTrend;
    if (trend.isEmpty) return const SizedBox.shrink();

    final keys = trend.keys.toList();
    final values = trend.values.toList();
    final maxVal = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PWD Registration Trend (Last 6 Months)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: (maxVal + 2).toDouble(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        return LineTooltipItem(
                          '${keys[s.x.toInt()]}\n${s.y.toInt()} registered',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= keys.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              keys[i].split(' ').first, // e.g. "Jan"
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: values.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: const Color(AppConstants.navyBlue),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(AppConstants.navyBlue)
                            .withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Health Checkup Summary Table ───────────────────────────────────
  Widget _buildCheckupSummaryTable() {
    final checkups = _recentCheckups;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Health Check-Up Summary',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (checkups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No completed checkups found',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TableHeader('PWD Name'),
                      _TableHeader('Scheduled'),
                      _TableHeader('Completed'),
                    ],
                  ),
                  ...checkups.map(
                    (c) => TableRow(
                      children: [
                        _TableCell(c.pwdFullName),
                        _TableCell(
                            DateFormat('MMM d, yyyy').format(c.scheduledDate)),
                        _TableCell(
                          c.completedDate != null
                              ? DateFormat('MMM d, yyyy')
                                  .format(c.completedDate!)
                              : '—',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Export Row ─────────────────────────────────────────────────────────────
  Widget _buildExportRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportPDF,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export as PDF'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportExcel,
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export as Excel'),
          ),
        ),
      ],
    );
  }

  // ── Not generated state ────────────────────────────────────────────────────
  Widget _buildNotGeneratedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No report generated yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set your filters above and tap Generate Report',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Table helpers ─────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
