import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';

class DuplicateAnalysisPage extends StatefulWidget {
  const DuplicateAnalysisPage({super.key});

  @override
  State<DuplicateAnalysisPage> createState() => _DuplicateAnalysisPageState();
}

class _DuplicateAnalysisPageState extends State<DuplicateAnalysisPage> with SingleTickerProviderStateMixin {
  final HODataService _dataService = HODataService();
  late TabController _tabController;

  bool _isLoading = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 3));
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  String? _selectedStationId;

  DateTime get _effectiveStart => DateTime(
        _startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute, 0,
      );

  DateTime get _effectiveEnd => DateTime(
        _endDate.year, _endDate.month, _endDate.day,
        _endTime.hour, _endTime.minute, 59,
      );

  // Analysis settings
  bool _ignoreCommonPrefixes = true;
  int _shortIntervalMinutes = 5;

  List<dynamic> _stations = [];
  List<Map<String, dynamic>> _allTransactions = [];

  // Categorized anomalies
  List<Map<String, dynamic>> _shortIntervalAnomalies = [];
  List<Map<String, dynamic>> _multiStationAnomalies = [];
  List<Map<String, dynamic>> _diffFuelAnomalies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final stationsList = await _dataService.getStationsForDropdown();
      setState(() {
        _stations = stationsList;
      });
      await _runAnalysis();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analysis setup: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all transactions for the date range
      final data = await _dataService.getSaleTransactionsReport(
        startDate: _effectiveStart,
        endDate: _effectiveEnd,
        stationId: _selectedStationId,
      );

      setState(() {
        _allTransactions = data;
        _analyzeData();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running analysis: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCommonPrefix(String vehicle) {
    final v = vehicle.trim().toUpperCase();
    if (v.isEmpty) return true;
    // Check if starts with C, CC, or CY
    return v.startsWith('C') || v.startsWith('CY') || v.startsWith('CC');
  }

  void _analyzeData() {
    _shortIntervalAnomalies.clear();
    _multiStationAnomalies.clear();
    _diffFuelAnomalies.clear();

    if (_allTransactions.isEmpty) return;

    // Filter transaction list to remove empty/common vehicle numbers if configured
    final List<Map<String, dynamic>> workingSet = _allTransactions.where((txn) {
      final vehicle = (txn['vehicle_no'] ?? '').toString();
      if (vehicle.trim().isEmpty) return false;
      if (_ignoreCommonPrefixes && _isCommonPrefix(vehicle)) return false;
      return true;
    }).toList();

    // Group transactions by Vehicle
    final Map<String, List<Map<String, dynamic>>> vehicleGroups = {};
    for (var txn in workingSet) {
      final vehicle = txn['vehicle_no'].toString().trim().toUpperCase();
      vehicleGroups[vehicle] ??= [];
      vehicleGroups[vehicle]!.add(txn);
    }

    // 1. Short Interval & Different Fuel Analysis
    vehicleGroups.forEach((vehicle, txns) {
      // Sort transactions for this vehicle by created_at ascending
      txns.sort((a, b) {
        final aTime = DateTime.parse(a['created_at']);
        final bTime = DateTime.parse(b['created_at']);
        return aTime.compareTo(bTime);
      });

      // ── SHORT INTERVAL ──
      for (int i = 1; i < txns.length; i++) {
        final current = txns[i];
        final previous = txns[i - 1];

        final currTime = DateTime.parse(current['created_at']);
        final prevTime = DateTime.parse(previous['created_at']);
        final diffMins = currTime.difference(prevTime).inMinutes;

        // Check if same station and within short interval
        if (current['station_id'] == previous['station_id'] && diffMins <= _shortIntervalMinutes) {
          final sName = _getStationName(current['station_id']);
          
          // Mark both transactions
          final anomalyDesc = "Refueled twice within $diffMins mins at $sName";
          _shortIntervalAnomalies.add({...previous, 'anomaly': anomalyDesc, 'partner_voucher': current['voucher_no']});
          _shortIntervalAnomalies.add({...current, 'anomaly': anomalyDesc, 'partner_voucher': previous['voucher_no']});
        }
      }

      // ── DIFFERENT FUEL (Same Day) ──
      // Group vehicle's txns by local calendar date
      final Map<String, List<Map<String, dynamic>>> dateGroups = {};
      for (var txn in txns) {
        final dt = DateTime.parse(txn['created_at']).toLocal();
        final dateKey = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        dateGroups[dateKey] ??= [];
        dateGroups[dateKey]!.add(txn);
      }

      dateGroups.forEach((date, dayTxns) {
        final fuels = dayTxns.map((t) => (t['fuel_type'] ?? '').toString().trim().toUpperCase()).toSet();
        if (fuels.length > 1) {
          final fuelsJoined = dayTxns.map((t) => (t['fuel_type'] ?? 'Other')).toSet().join(' & ');
          for (var t in dayTxns) {
            _diffFuelAnomalies.add({
              ...t,
              'anomaly': "Refueled different fuel types ($fuelsJoined) on $date",
            });
          }
        }
      });

      // ── MULTI-STATION (Same Day) ──
      dateGroups.forEach((date, dayTxns) {
        final stations = dayTxns.map((t) => t['station_id']?.toString()).toSet();
        if (stations.length > 1) {
          final stationNames = dayTxns.map((t) => _getStationName(t['station_id'])).toSet().join(' & ');
          for (var t in dayTxns) {
            _multiStationAnomalies.add({
              ...t,
              'anomaly': "Refueled at multiple stations ($stationNames) on $date",
            });
          }
        }
      });
    });

    // Sort outputs descending by time
    _sortAnomalies(_shortIntervalAnomalies);
    _sortAnomalies(_multiStationAnomalies);
    _sortAnomalies(_diffFuelAnomalies);
  }

  void _sortAnomalies(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aTime = DateTime.parse(a['created_at']);
      final bTime = DateTime.parse(b['created_at']);
      return bTime.compareTo(aTime);
    });
  }

  String _getStationName(dynamic id) {
    if (id == null) return 'Unknown';
    try {
      final s = _stations.firstWhere(
        (element) => element['station_id']?.toString() == id.toString(),
      );
      return s['name']?.toString() ?? id.toString();
    } catch (_) {
      return 'Station $id';
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: HOColors.accent,
              surface: HOColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
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
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

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

  void _exportCSV() {
    List<Map<String, dynamic>> targetList = [];
    String typeLabel = "";

    switch (_tabController.index) {
      case 0:
        targetList = _shortIntervalAnomalies;
        typeLabel = "Short_Interval_Anomalies";
        break;
      case 1:
        targetList = _multiStationAnomalies;
        typeLabel = "Multi_Station_Anomalies";
        break;
      case 2:
        targetList = _diffFuelAnomalies;
        typeLabel = "Different_Fuel_Anomalies";
        break;
    }

    if (targetList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No anomalies to export in this category.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    List<List<dynamic>> rows = [
      ['Date & Time', 'Voucher No', 'Vehicle No', 'Station', 'Fuel Type', 'Liters', 'Amount (MMK)', 'Anomaly Details'],
    ];

    for (var txn in targetList) {
      final dt = DateTime.parse(txn['created_at']).toLocal();
      final sName = _getStationName(txn['station_id']);
      final amount = (txn['amount_mmk'] as num?)?.toDouble() ?? 0.0;
      final liters = (txn['liters'] ?? txn['sale_liter'] ?? 0.0) as num;

      rows.add([
        DateFormat('dd MMM yyyy, HH:mm').format(dt),
        txn['voucher_no'] ?? '-',
        txn['vehicle_no'] ?? '-',
        sName,
        txn['fuel_type'] ?? '-',
        liters,
        amount,
        txn['anomaly'] ?? '',
      ]);
    }

    String csvData = csv.encode(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'MoonSun_${typeLabel}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$typeLabel report exported successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 950;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duplicate Analysis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _exportCSV,
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: const Text('Export Current Tab', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview/Control Card
          _buildControlsCard(isMobile),
          const SizedBox(height: 24),

          // Metrics Bar
          _buildMetricsBar(isMobile),
          const SizedBox(height: 24),

          // Tabs & Results
          Card(
            color: HOColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: HOColors.accent,
                  labelColor: HOColors.accent,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text("Short Interval (${_shortIntervalAnomalies.length})"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.ev_station_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text("Multi-Station (${_multiStationAnomalies.length})"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_gas_station_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text("Diff Fuel Type (${_diffFuelAnomalies.length})"),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 500,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResultsList(_shortIntervalAnomalies),
                      _buildResultsList(_multiStationAnomalies),
                      _buildResultsList(_diffFuelAnomalies),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(bool isMobile) {
    final fmt = DateFormat('dd MMM yyyy');
    String _tfmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Station Selector
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStationId,
                    dropdownColor: HOColors.surface,
                    decoration: const InputDecoration(
                      labelText: 'Station Filter',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Stations')),
                      ..._stations.map((s) => DropdownMenuItem(
                        value: s['station_id']?.toString(),
                        child: Text(s['name'] ?? ''),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStationId = val);
                    },
                  ),
                ),

                // From/To Date & Time chips
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
                      onDateTap: () => _selectDateRange(context),
                      onTimeTap: () => _pickTime(isStart: true),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.white38),
                    _dateTimeChip(
                      label: 'To',
                      dateStr: fmt.format(_endDate),
                      timeStr: _tfmt(_endTime),
                      accentColor: Colors.blueAccent,
                      onDateTap: () => _selectDateRange(context),
                      onTimeTap: () => _pickTime(isStart: false),
                    ),
                  ],
                ),

                // Search Button
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runAnalysis,
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
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Colors.white10),
            // Configuration Parameters (Max Interval & Ignore Prefixes)
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Short Interval Time Dropdown
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: DropdownButtonFormField<int>(
                    value: _shortIntervalMinutes,
                    dropdownColor: HOColors.surface,
                    decoration: const InputDecoration(
                      labelText: 'Max Interval (Mins)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      helperText: 'For short interval duplicate analysis',
                      helperStyle: TextStyle(fontSize: 10, color: Colors.white30),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 minutes')),
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 10, child: Text('10 minutes')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _shortIntervalMinutes = val);
                        _analyzeData();
                      }
                    },
                  ),
                ),

                // Ignore common prefixes Checkbox
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _ignoreCommonPrefixes,
                      activeColor: HOColors.accent,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _ignoreCommonPrefixes = val);
                          _analyzeData();
                        }
                      },
                    ),
                    const Text(
                      "Ignore generic plates (C, CC, CY) to reduce noise",
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsBar(bool isMobile) {
    int total = _shortIntervalAnomalies.length + _multiStationAnomalies.length + _diffFuelAnomalies.length;
    final chips = [
      _metricCard("Total Anomalies", "$total", Colors.redAccent),
      _metricCard("Short Intervals", "${_shortIntervalAnomalies.length}", Colors.orangeAccent),
      _metricCard("Multi-Stations", "${_multiStationAnomalies.length}", Colors.blueAccent),
      _metricCard("Different Fuels", "${_diffFuelAnomalies.length}", Colors.tealAccent),
    ];

    if (isMobile) {
      return Column(children: chips.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
    }

    return Row(
      children: chips.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList(),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<Map<String, dynamic>> anomalies) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HOColors.accent));
    }

    if (anomalies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.gpp_good_outlined, size: 48, color: Colors.greenAccent),
            SizedBox(height: 12),
            Text("No suspicious patterns found in this category.", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: HOColors.accent),
          dataTextStyle: const TextStyle(color: Colors.white70),
          columns: const [
            DataColumn(label: Text('Vehicle No')),
            DataColumn(label: Text('Date & Time')),
            DataColumn(label: Text('Station')),
            DataColumn(label: Text('Voucher No')),
            DataColumn(label: Text('Fuel Type')),
            DataColumn(label: Text('Liters')),
            DataColumn(label: Text('Amount (MMK)')),
            DataColumn(label: Text('Details')),
          ],
          rows: anomalies.map((txn) {
            final dt = DateTime.parse(txn['created_at']).toLocal();
            final amount = (txn['amount_mmk'] as num?)?.toDouble() ?? 0.0;
            final liters = (txn['liters'] ?? txn['sale_liter'] ?? 0.0) as num;
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      txn['vehicle_no'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                DataCell(Text(DateFormat('dd MMM, HH:mm').format(dt))),
                DataCell(Text(_getStationName(txn['station_id']))),
                DataCell(Text(txn['voucher_no'] ?? '-')),
                DataCell(Text(txn['fuel_type'] ?? '-')),
                DataCell(Text(liters.toStringAsFixed(2))),
                DataCell(Text(NumberFormat('#,###').format(amount))),
                DataCell(
                  Text(
                    txn['anomaly'] ?? '',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
