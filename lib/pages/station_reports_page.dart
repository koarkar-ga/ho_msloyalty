import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/services/station_api_service.dart';
import 'package:intl/intl.dart';

class StationReportsPage extends StatefulWidget {
  const StationReportsPage({super.key});

  @override
  State<StationReportsPage> createState() => _StationReportsPageState();
}

class _StationReportsPageState extends State<StationReportsPage> {
  final HODataService _dataService = HODataService();
  final StationApiService _stationApi = StationApiService();

  bool _isLoading = false;

  // ── Date / Time ────────────────────────────────────────────────────────────
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);

  // ── Dropdown ───────────────────────────────────────────────────────────────
  /// Supabase station list: [{ id, station_id, name }]
  List<dynamic> _stations = [];

  /// Currently selected station_id (e.g. "M001") — used as MSSQL DB name
  String? _selectedStationId;

  /// Display name of the selected station
  String _selectedStationName = 'All Stations';

  /// Selected fuel type for client-side filtering
  String _selectedFuelType = 'ALL';

  // ── Data ───────────────────────────────────────────────────────────────────
  List<String> _fuelTypeOptions = ['ALL'];
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _filteredSalesData = [];

  /// Error message to display (null = no error)
  String? _errorMessage;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  /// Computed start DateTime combining date + time pickers
  DateTime get _effectiveStart => DateTime(
        _startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute, 0,
      );

  /// Computed end DateTime combining date + time pickers
  DateTime get _effectiveEnd => DateTime(
        _endDate.year, _endDate.month, _endDate.day,
        _endTime.hour, _endTime.minute, 59,
      );

  // ─── Load stations from Supabase ───────────────────────────────────────────
  Future<void> _loadStations() async {
    try {
      final list = await _dataService.getStationsForDropdown();
      if (mounted) setState(() => _stations = list);
    } catch (e) {
      _showError('Failed to load station list: $e');
    }
  }

  // ─── Fetch from Station API ────────────────────────────────────────────────
  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _stationApi.searchSales(
        startDate: _effectiveStart,
        endDate: _effectiveEnd,
        stationId: _selectedStationId,
      );

      setState(() {
        _salesData = data;
        // Rebuild fuel type options from fresh data
        final types = data
            .map((e) => (e['FuelTypeName'] ?? '').toString().trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _fuelTypeOptions = ['ALL', ...types];
        if (!_fuelTypeOptions.contains(_selectedFuelType)) {
          _selectedFuelType = 'ALL';
        }
        _applyFilters();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      _showError('Error fetching station data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Client-side fuel filter ───────────────────────────────────────────────
  void _applyFilters() {
    setState(() {
      _filteredSalesData = _selectedFuelType == 'ALL'
          ? List.from(_salesData)
          : _salesData
              .where((s) =>
                  (s['FuelTypeName'] ?? '').toString().trim() ==
                  _selectedFuelType)
              .toList();
    });
  }

  // ─── Date pickers ──────────────────────────────────────────────────────────
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: HOColors.accent,
            surface: HOColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: HOColors.accent,
            surface: HOColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ─── Computed totals ───────────────────────────────────────────────────────
  double get _grandTotalLiter => _filteredSalesData.fold(
      0.0, (s, i) => s + ((i['SALELITER'] ?? 0) as num).toDouble());

  double get _grandTotalAmount => _filteredSalesData.fold(
      0.0, (s, i) => s + ((i['TotalPrice'] ?? 0) as num).toDouble());

  Map<String, Map<String, double>> _calculateFuelSummary() {
    final Map<String, Map<String, double>> result = {};
    for (var s in _filteredSalesData) {
      final type = (s['FuelTypeName'] ?? 'Other').toString().trim();
      final liter = ((s['SALELITER'] ?? 0) as num).toDouble();
      final amount = ((s['TotalPrice'] ?? 0) as num).toDouble();
      result[type] ??= {'liters': 0.0, 'amount': 0.0};
      result[type]!['liters'] = result[type]!['liters']! + liter;
      result[type]!['amount'] = result[type]!['amount']! + amount;
    }
    return result;
  }

  Map<String, Map<String, double>> _calculateSaleTypeSummary() {
    final Map<String, Map<String, double>> result = {};
    for (var s in _filteredSalesData) {
      final type = (s['Sale_Type_name'] ?? 'Other').toString().trim();
      final liter = ((s['SALELITER'] ?? 0) as num).toDouble();
      final amount = ((s['TotalPrice'] ?? 0) as num).toDouble();
      result[type] ??= {'liters': 0.0, 'amount': 0.0};
      result[type]!['liters'] = result[type]!['liters']! + liter;
      result[type]!['amount'] = result[type]!['amount']! + amount;
    }
    return result;
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 950;

    return RefreshIndicator(
      onRefresh: _fetchReportData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Text(
                  'Reports Summary (Station App)',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: HOColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HOColors.accent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_rounded, size: 12, color: HOColors.accent),
                      SizedBox(width: 4),
                      Text('Live API',
                          style: TextStyle(
                              fontSize: 11,
                              color: HOColors.accent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Source: ho.moonsungroup.com:5000  •  Station: $_selectedStationName',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 24),

            // Filters
            _buildFiltersCard(isMobile),
            const SizedBox(height: 24),

            // Metrics
            if (!_isLoading || _salesData.isNotEmpty)
              _buildMetricsBar(isMobile),

            // Content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                    child: CircularProgressIndicator(color: HOColors.accent)),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_filteredSalesData.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (isMobile) ...[
                _buildFuelSummaryTable(),
                const SizedBox(height: 24),
                _buildSaleTypeSummaryTable(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFuelSummaryTable()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSaleTypeSummaryTable()),
                  ],
                ),
              const SizedBox(height: 24),
              _buildTransactionsTable(),
            ] else if (_salesData.isEmpty && !_isLoading)
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  // ─── Filters Card ──────────────────────────────────────────────────────────
  Widget _buildFiltersCard(bool isMobile) {
    final fmt = DateFormat('dd MMM yyyy');
    String _tfmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1 — Station + Fuel Type
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Station
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStationId,
                    dropdownColor: HOColors.surface,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Station (Database)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      helperText: 'Connects to station MSSQL DB',
                      helperStyle: TextStyle(fontSize: 10, color: Colors.white30),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Stations (Default DB)')),
                      ..._stations.map((s) => DropdownMenuItem(
                            value: s['station_id']?.toString(),
                            child: Text(
                              '${s['name'] ?? ''} (${s['station_id'] ?? ''})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStationId = val;
                        _selectedStationName = val == null
                            ? 'All Stations'
                            : (_stations.firstWhere(
                                    (s) => s['station_id']?.toString() == val,
                                    orElse: () => {'name': val})['name'] ??
                                val);
                      });
                    },
                  ),
                ),

                // Fuel Type (client-side filter)
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFuelType,
                    dropdownColor: HOColors.surface,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Fuel Type Filter',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      helperText: 'Filters loaded data locally',
                      helperStyle: TextStyle(fontSize: 10, color: Colors.white30),
                    ),
                    items: _fuelTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedFuelType = val);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Row 2 — Date + Time chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dateTimeChip(
                  label: 'From',
                  dateStr: fmt.format(_startDate),
                  timeStr: _tfmt(_startTime),
                  accentColor: HOColors.accent,
                  onDateTap: _selectDateRange,
                  onTimeTap: () => _pickTime(isStart: true),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.white38),
                _dateTimeChip(
                  label: 'To',
                  dateStr: fmt.format(_endDate),
                  timeStr: _tfmt(_endTime),
                  accentColor: Colors.blueAccent,
                  onDateTap: _selectDateRange,
                  onTimeTap: () => _pickTime(isStart: false),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Row 3 — Search Button
            SizedBox(
              width: isMobile ? double.infinity : null,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchReportData,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, color: Colors.white),
                label: Text(
                  _isLoading ? 'Searching...' : 'Search',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Date + Time Chip ──────────────────────────────────────────────────────
  Widget _dateTimeChip({
    required String label,
    required String dateStr,
    required String timeStr,
    required Color accentColor,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onDateTap,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 15, color: accentColor),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                color: accentColor,
                                fontWeight: FontWeight.bold)),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, color: accentColor.withOpacity(0.25)),
            InkWell(
              onTap: onTimeTap,
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 15, color: accentColor),
                    const SizedBox(width: 6),
                    Text(timeStr,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Metrics Bar ───────────────────────────────────────────────────────────
  Widget _buildMetricsBar(bool isMobile) {
    final chips = [
      _metricChip(
          'Total Amount (Ks)',
          NumberFormat('#,###').format(_grandTotalAmount),
          Colors.greenAccent,
          Icons.attach_money_rounded),
      _metricChip(
          'Total Liters (L)',
          _grandTotalLiter.toStringAsFixed(2),
          Colors.blueAccent,
          Icons.local_gas_station_rounded),
      _metricChip(
          'Transactions',
          '${_filteredSalesData.length}',
          Colors.tealAccent,
          Icons.receipt_long_rounded),
    ];

    if (isMobile) {
      return Column(
          children: chips
              .map((c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
              .toList());
    }
    return Row(
        children: chips
            .map((c) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16), child: c)))
            .toList());
  }

  Widget _metricChip(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 18, color: color, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fuel Summary Table ────────────────────────────────────────────────────
  Widget _buildFuelSummaryTable() {
    final data = _calculateFuelSummary();
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value['amount']!.compareTo(a.value['amount']!));

    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fuel Summary (ဆီအမျိုးအစားအလိုက်)',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: HOColors.accent)),
          const Divider(height: 24, color: Colors.white10),
          if (sorted.isEmpty)
            const Center(
                child: Text('No fuel data.', style: TextStyle(color: Colors.white38)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 44,
                horizontalMargin: 8,
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12),
                dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                columns: const [
                  DataColumn(label: Text('Fuel Type')),
                  DataColumn(label: Text('Liters'), numeric: true),
                  DataColumn(label: Text('Amount (Ks)'), numeric: true),
                ],
                rows: sorted
                    .map((e) => DataRow(cells: [
                          DataCell(Text(e.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.white))),
                          DataCell(Text(e.value['liters']!.toStringAsFixed(2))),
                          DataCell(Text(
                            NumberFormat('#,###').format(e.value['amount']),
                            style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold),
                          )),
                        ]))
                    .toList(),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Sale Type Summary Table ───────────────────────────────────────────────
  Widget _buildSaleTypeSummaryTable() {
    final data = _calculateSaleTypeSummary();
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value['amount']!.compareTo(a.value['amount']!));

    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sale Type Summary (အရောင်းအမျိုးအစားအလိုက်)',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: HOColors.accent)),
          const Divider(height: 24, color: Colors.white10),
          if (sorted.isEmpty)
            const Center(
                child: Text('No data.', style: TextStyle(color: Colors.white38)))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 44,
                horizontalMargin: 8,
                columnSpacing: 24,
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12),
                dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                columns: const [
                  DataColumn(label: Text('Sale Type')),
                  DataColumn(label: Text('Liters'), numeric: true),
                  DataColumn(label: Text('Amount (Ks)'), numeric: true),
                ],
                rows: sorted
                    .map((e) => DataRow(cells: [
                          DataCell(Text(e.key)),
                          DataCell(Text(e.value['liters']!.toStringAsFixed(2))),
                          DataCell(Text(
                            NumberFormat('#,###').format(e.value['amount']),
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold),
                          )),
                        ]))
                    .toList(),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Transactions Table ────────────────────────────────────────────────────
  Widget _buildTransactionsTable() {
    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transactions (အရောင်းမှတ်တမ်းများ)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(
                '${_filteredSalesData.length > 50 ? "Showing top 50 of " : ""}${_filteredSalesData.length}',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold, color: HOColors.accent, fontSize: 12),
                dataTextStyle:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                columns: const [
                  DataColumn(label: Text('Date & Time')),
                  DataColumn(label: Text('Voucher')),
                  DataColumn(label: Text('Vehicle')),
                  DataColumn(label: Text('Fuel Type')),
                  DataColumn(label: Text('Liters'), numeric: true),
                  DataColumn(label: Text('Amount (Ks)'), numeric: true),
                  DataColumn(label: Text('Sale Type')),
                  DataColumn(label: Text('Cashier')),
                ],
                rows: _filteredSalesData.take(50).map((txn) {
                  DateTime? dt;
                  try {
                    dt = DateTime.parse(txn['S_Date'].toString()).toLocal();
                  } catch (_) {}
                  final amount = ((txn['TotalPrice'] ?? 0) as num).toDouble();
                  final liters = ((txn['SALELITER'] ?? 0) as num).toDouble();
                  return DataRow(cells: [
                    DataCell(Text(dt != null
                        ? DateFormat('dd MMM, HH:mm').format(dt)
                        : (txn['S_Date']?.toString() ?? '-'))),
                    DataCell(Text(txn['VocNo']?.toString() ?? '-')),
                    DataCell(Text(txn['Vehical_No']?.toString() ?? '-')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: HOColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(txn['FuelTypeName']?.toString() ?? '-',
                            style: const TextStyle(
                                color: HOColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                    ),
                    DataCell(Text(liters.toStringAsFixed(2))),
                    DataCell(Text(NumberFormat('#,###').format(amount),
                        style: const TextStyle(color: Colors.greenAccent))),
                    DataCell(Text(txn['Sale_Type_name']?.toString() ?? '-')),
                    DataCell(Text(txn['CashierName']?.toString() ?? '-')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Empty / Error states ──────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Select a station and press Search to load data.',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchReportData,
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            label: const Text('Search', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text('Failed to connect to Station API',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchReportData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text('Retry', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
