import 'package:flutter/material.dart';
import 'package:ms_dashboard/pages/report_widgets.dart';
import 'package:ms_dashboard/pages/sales_breakdown_page.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';

class ReportsPage extends StatefulWidget {
  final String mode; // 'sales' or 'loyalty'
  const ReportsPage({super.key, this.mode = 'sales'});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HODataService _dataService = HODataService();

  // Shared Filter State
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _selectedStationId;
  List<dynamic> _stationsList = [];

  // Data States
  bool _isLoadingSales = false;
  List<Map<String, dynamic>> _salesData = [];

  bool _isLoadingPoints = false;
  List<Map<String, dynamic>> _pointsData = [];

  bool _isLoadingRedemptions = false;
  List<Map<String, dynamic>> _redemptionsData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStations();
    _fetchAllReports();
  }

  Future<void> _fetchAllReports() async {
    if (widget.mode == 'loyalty') {
      _fetchPointIssues();
      _fetchRedemptions();
    } else {
      _fetchSaleTransactions();
    }
  }

  Future<void> _loadStations() async {
    final s = await _dataService.getStationsForDropdown();
    if (mounted) setState(() => _stationsList = s);
  }

  Future<void> _fetchSaleTransactions() async {
    if (!mounted) return;
    setState(() => _isLoadingSales = true);
    final data = await _dataService.getSaleTransactionsReport(
      startDate: _startDate,
      endDate: _endDate,
      stationId: _selectedStationId,
    );
    if (mounted) {
      setState(() {
        _salesData = data;
        _isLoadingSales = false;
      });
    }
  }

  Future<void> _fetchPointIssues() async {
    if (!mounted) return;
    setState(() => _isLoadingPoints = true);
    final data = await _dataService.getPointIssueReport(
      startDate: _startDate,
      endDate: _endDate,
      stationId: _selectedStationId,
    );
    if (mounted) {
      setState(() {
        _pointsData = data;
        _isLoadingPoints = false;
      });
    }
  }

  Future<void> _fetchRedemptions() async {
    if (!mounted) return;
    setState(() => _isLoadingRedemptions = true);
    final data = await _dataService.getRedemptionReport(
      startDate: _startDate,
      endDate: _endDate,
      stationId: _selectedStationId,
    );
    if (mounted) {
      setState(() {
        _redemptionsData = data;
        _isLoadingRedemptions = false;
      });
    }
  }

  String _getStationName(String? stationId) {
    if (stationId == null || stationId.isEmpty) return 'Unknown';
    final matches = _stationsList.where(
      (s) => s['station_id'] == stationId || s['id'].toString() == stationId,
    );
    if (matches.isEmpty) return stationId;
    return matches.first['name'] ?? stationId;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
        // set end date to end of the day
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      _fetchAllReports();
    }
  }

  void _exportCSV(String reportType) {
    if ((reportType == 'Sale Transactions' && _salesData.isEmpty) ||
        (reportType == 'Point Issues' && _pointsData.isEmpty) ||
        (reportType == 'Redemptions' && _redemptionsData.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to export for $reportType.')),
      );
      return;
    }

    List<List<dynamic>> rows = [];

    if (reportType == 'Sale Transactions') {
      rows.add([
        'Date & Time',
        'Station',
        'Vehicle No',
        'Fuel Type',
        'Liters',
        'Price / Liter',
        'Amount (MMK)',
        'Sale Type',
      ]);
      for (var txn in _salesData) {
        final dt = DateTime.parse(txn['created_at']).toLocal();
        final stationName = _getStationName(txn['station_id']);
        final amount = (txn['amount_mmk'] as num?)?.toDouble() ?? 0.0;
        final liters =
            (txn['liters'] as num?)?.toDouble() ??
            (txn['sale_liter'] as num?)?.toDouble() ??
            0.0;
        final pricePerLiter = liters > 0 ? (amount / liters) : 0.0;

        rows.add([
          DateFormat('dd MMM yyyy, HH:mm').format(dt),
          stationName,
          txn['voucher_no'] ?? '-',
          txn['vehicle_no'] ?? '-',
          txn['fuel_type'] ?? '-',
          liters,
          pricePerLiter.toStringAsFixed(0),
          amount,
          txn['sale_type'] ?? '-',
        ]);
      }
    } else if (reportType == 'Point Issues') {
      rows.add([
        'Date & Time',
        'Station',
        'Voucher No',
        'Fuel Type',
        'Payment Type',
        'Total Price (MMK)',
        'Total Liter',
        'Price / Liter',
        'Points Earned',
      ]);
      for (var txn in _pointsData) {
        final dt = DateTime.parse(txn['created_at']).toLocal();
        final stationName = _getStationName(txn['station_id']);
        final price = (txn['amount_mmk'] as num?)?.toDouble() ?? 0.0;
        final actualLiters = (txn['sale_liter'] as num?)?.toDouble();
        final unitPriceFallback =
            (txn['unit_price'] as num?)?.toDouble() ?? 1.0;
        final liters =
            actualLiters ??
            (unitPriceFallback > 0 ? (price / unitPriceFallback) : 0.0);
        final pricePerLiter = liters > 0 ? (price / liters) : 0.0;

        rows.add([
          DateFormat('dd MMM yyyy, HH:mm').format(dt),
          stationName,
          txn['voucher_no'] ?? '-',
          txn['fuel_type'] ?? '-',
          txn['payment_type'] ?? '-',
          price,
          liters.toStringAsFixed(2),
          pricePerLiter.toStringAsFixed(0),
          txn['points_earned'] ?? 0,
        ]);
      }
    } else if (reportType == 'Redemptions') {
      rows.add([
        'Date & Time',
        'Station',
        'Reward Name',
        'Required Point',
        'Spend Point',
      ]);
      for (var txn in _redemptionsData) {
        final dt = DateTime.parse(txn['created_at']).toLocal();
        final stationName = _getStationName(txn['station_id']);
        final reward = txn['gift_cards']?['title'] ?? 'Unknown';
        final required = txn['gift_cards']?['points_required'] ?? 0;

        rows.add([
          DateFormat('dd MMM yyyy, HH:mm').format(dt),
          stationName,
          reward,
          required,
          txn['points_spent'] ?? 0,
        ]);
      }
    }

    String csvData = csv.encode(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download =
          '${reportType.replaceAll(' ', '_')}_Export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$reportType exported successfully!')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoyalty = widget.mode == 'loyalty';

    return Column(
      children: [
        // TabBar Header
        Container(
          color: HOColors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: HOColors.accent,
            labelColor: HOColors.accent,
            unselectedLabelColor: Colors.white60,
            tabs: isLoyalty
                ? const [
                    Tab(icon: Icon(Icons.stars), text: 'Point Issues'),
                    Tab(icon: Icon(Icons.card_giftcard), text: 'Redemptions'),
                  ]
                : const [
                    Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Sale Transactions'),
                  ],
          ),
        ),
        // TabBar Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: isLoyalty
                ? [
                    _buildPointIssuesTab(),
                    _buildRedemptionsTab(),
                  ]
                : [
                    const SalesBreakdownPage(), // Existing UI
                    _buildSaleTransactionsTab(),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaleTransactionsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          ReportFilterBar(
            startDate: _startDate,
            endDate: _endDate,
            selectedStationId: _selectedStationId,
            stations: _stationsList,
            onDateRangePick: () => _selectDateRange(context),
            onStationChange: (val) {
              setState(() => _selectedStationId = val);
              _fetchSaleTransactions();
            },
            onExport: () => _exportCSV('Sale Transactions'),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: HOColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: _isLoadingSales
                  ? const Center(child: CircularProgressIndicator())
                  : _salesData.isEmpty
                  ? const Center(
                      child: Text(
                        'No Sale Transactions Found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HOColors.accent,
                          ),
                          dataTextStyle: const TextStyle(color: Colors.white),
                          columns: const [
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Station')),
                            DataColumn(label: Text('Voucher No')),
                            DataColumn(label: Text('Vehicle No')),
                            DataColumn(label: Text('Fuel Type')),
                            DataColumn(label: Text('Liters')),
                            DataColumn(label: Text('Price / Liter')),
                            DataColumn(label: Text('Amount (MMK)')),
                            DataColumn(label: Text('Sale Type')),
                          ],
                          rows: _salesData.map((txn) {
                            final dt = DateTime.parse(
                              txn['created_at'],
                            ).toLocal();
                            final stationName = _getStationName(
                              txn['station_id'],
                            );
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(dt),
                                  ),
                                ),
                                DataCell(Text(stationName)),
                                DataCell(Text(txn['voucher_no'] ?? '-')),
                                DataCell(Text(txn['vehicle_no'] ?? '-')),
                                DataCell(Text(txn['fuel_type'] ?? '-')),
                                DataCell(
                                  Text(
                                    (txn['liters'] ?? txn['sale_liter'] ?? '0')
                                        .toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (() {
                                      final amount =
                                          (txn['amount_mmk'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final liters =
                                          (txn['liters'] as num?)?.toDouble() ??
                                          (txn['sale_liter'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      return liters > 0
                                          ? (amount / liters).toStringAsFixed(0)
                                          : '-';
                                    })(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    NumberFormat(
                                      '#,###',
                                    ).format(txn['amount_mmk'] ?? 0),
                                  ),
                                ),
                                DataCell(Text(txn['sale_type'] ?? '-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointIssuesTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          ReportFilterBar(
            startDate: _startDate,
            endDate: _endDate,
            selectedStationId: _selectedStationId,
            stations: _stationsList,
            onDateRangePick: () => _selectDateRange(context),
            onStationChange: (val) {
              setState(() => _selectedStationId = val);
              _fetchAllReports();
            },
            onExport: () => _exportCSV('Point Issues'),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: HOColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: _isLoadingPoints
                  ? const Center(child: CircularProgressIndicator())
                  : _pointsData.isEmpty
                  ? const Center(
                      child: Text(
                        'No Point Issues Found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HOColors.accent,
                          ),
                          dataTextStyle: const TextStyle(color: Colors.white),
                          columns: const [
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Station')),
                            DataColumn(label: Text('Voucher No')),
                            DataColumn(label: Text('Fuel Type')),
                            DataColumn(label: Text('Payment Type')),
                            DataColumn(label: Text('Total Price(MMK)')),
                            DataColumn(label: Text('Total Liter')),
                            DataColumn(label: Text('Price / Liter')),
                            DataColumn(label: Text('Points Earned')),
                          ],
                          rows: _pointsData.map((txn) {
                            final dt = DateTime.parse(
                              txn['created_at'],
                            ).toLocal();
                            final stationName = _getStationName(
                              txn['station_id'],
                            );
                            final price =
                                (txn['amount_mmk'] as num?)?.toDouble() ?? 0.0;
                            final unitPrice =
                                (txn['unit_price'] as num?)?.toDouble() ?? 1.0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(dt),
                                  ),
                                ),
                                DataCell(Text(stationName)),
                                DataCell(Text(txn['voucher_no'] ?? '-')),
                                DataCell(Text(txn['fuel_type'] ?? '-')),
                                DataCell(Text(txn['payment_type'] ?? '-')),
                                DataCell(
                                  Text(NumberFormat('#,###').format(price)),
                                ),
                                DataCell(
                                  Text(
                                    (txn['sale_liter'] ??
                                            (unitPrice > 0
                                                ? (price / unitPrice)
                                                      .toStringAsFixed(2)
                                                : '0'))
                                        .toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (() {
                                      final liters =
                                          (txn['sale_liter'] as num?)
                                              ?.toDouble() ??
                                          (unitPrice > 0
                                              ? (price / unitPrice)
                                              : 0.0);
                                      return liters > 0
                                          ? (price / liters).toStringAsFixed(0)
                                          : '-';
                                    })(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    txn['points_earned']?.toString() ?? '0',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          ReportFilterBar(
            startDate: _startDate,
            endDate: _endDate,
            selectedStationId: _selectedStationId,
            stations: _stationsList,
            onDateRangePick: () => _selectDateRange(context),
            onStationChange: (val) {
              setState(() => _selectedStationId = val);
              _fetchAllReports();
            },
            onExport: () => _exportCSV('Redemptions'),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: HOColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: _isLoadingRedemptions
                  ? const Center(child: CircularProgressIndicator())
                  : _redemptionsData.isEmpty
                  ? const Center(
                      child: Text(
                        'No Redemptions Found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: HOColors.accent,
                          ),
                          dataTextStyle: const TextStyle(color: Colors.white),
                          columns: const [
                            DataColumn(label: Text('Date & Time')),
                            DataColumn(label: Text('Station')),
                            DataColumn(label: Text('Reward Name')),
                            DataColumn(label: Text('Required Point')),
                            DataColumn(label: Text('Spend Point')),
                          ],
                          rows: _redemptionsData.map((txn) {
                            final dt = DateTime.parse(
                              txn['created_at'],
                            ).toLocal();
                            final stationName = _getStationName(
                              txn['station_id'],
                            );
                            final reward =
                                txn['gift_cards']?['title'] ?? 'Unknown';
                            final required =
                                txn['gift_cards']?['points_required'] ?? 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(dt),
                                  ),
                                ),
                                DataCell(Text(stationName)),
                                DataCell(
                                  Text(
                                    reward,
                                    style: const TextStyle(
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                                DataCell(Text(required.toString())),
                                DataCell(
                                  Text(
                                    txn['points_spent']?.toString() ?? '0',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
