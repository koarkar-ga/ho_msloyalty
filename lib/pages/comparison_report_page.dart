import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/services/station_api_service.dart';

class ComparisonReportPage extends StatefulWidget {
  const ComparisonReportPage({super.key});

  @override
  State<ComparisonReportPage> createState() => _ComparisonReportPageState();
}

class _ComparisonReportPageState extends State<ComparisonReportPage> {
  final HODataService _dataService = HODataService();
  final StationApiService _stationApi = StationApiService();
  bool _isLoading = false;

  // Filters
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String? _selectedStationId;
  bool _useAmount = true; // true for MMK (Ks), false for Liters (L)

  List<dynamic> _stations = [];
  Map<String, dynamic> _reportData = {};

  final List<int> _years = [
    DateTime.now().year,
    DateTime.now().year - 1,
    DateTime.now().year - 2,
  ];

  final List<Map<String, dynamic>> _months = [
    {'value': 1, 'name': 'January'},
    {'value': 2, 'name': 'February'},
    {'value': 3, 'name': 'March'},
    {'value': 4, 'name': 'April'},
    {'value': 5, 'name': 'May'},
    {'value': 6, 'name': 'June'},
    {'value': 7, 'name': 'July'},
    {'value': 8, 'name': 'August'},
    {'value': 9, 'name': 'September'},
    {'value': 10, 'name': 'October'},
    {'value': 11, 'name': 'November'},
    {'value': 12, 'name': 'December'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final stationsList = await _dataService.getStationsForDropdown();
      setState(() {
        _stations = stationsList;
      });
      await _fetchReportData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comparison setup: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _stationApi.getComparisonReport(
        year: _selectedYear,
        month: _selectedMonth,
        stationId: _selectedStationId,
      );
      setState(() {
        _reportData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comparison report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                'Comparison Report',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              _buildValueTypeToggle(),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Card
          _buildFiltersCard(isMobile),
          const SizedBox(height: 24),

          // Loading or Charts Content
          _isLoading
              ? const SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: HOColors.accent),
                  ),
                )
              : _buildChartsContent(isMobile),
        ],
      ),
    );
  }

  Widget _buildValueTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Amount (Ks)', _useAmount, () {
            if (!_useAmount) setState(() => _useAmount = true);
          }),
          _toggleButton('Liters (L)', !_useAmount, () {
            if (_useAmount) setState(() => _useAmount = false);
          }),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? HOColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard(bool isMobile) {
    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Year Selector
            SizedBox(
              width: isMobile ? double.infinity : 150,
              child: DropdownButtonFormField<int>(
                value: _selectedYear,
                dropdownColor: HOColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(y.toString()),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedYear = val);
                    _fetchReportData();
                  }
                },
              ),
            ),

            // Month Selector
            SizedBox(
              width: isMobile ? double.infinity : 180,
              child: DropdownButtonFormField<int>(
                value: _selectedMonth,
                dropdownColor: HOColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _months.map((m) => DropdownMenuItem(
                  value: m['value'] as int,
                  child: Text(m['name'] as String),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMonth = val);
                    _fetchReportData();
                  }
                },
              ),
            ),

            // Station Selector
            SizedBox(
              width: isMobile ? double.infinity : 220,
              child: DropdownButtonFormField<String>(
                value: _selectedStationId,
                dropdownColor: HOColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Station',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  _fetchReportData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsContent(bool isMobile) {
    if (_reportData.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        // Daily Chart (MoM)
        _buildDailyChartCard(isMobile),
        const SizedBox(height: 24),

        // Monthly Chart (YoY)
        _buildMonthlyYoYChartCard(isMobile),
      ],
    );
  }

  Widget _buildDailyChartCard(bool isMobile) {
    final List<dynamic> selectedDaily = _reportData['selectedMonthDaily'] ?? [];
    final List<dynamic> prevDaily = _reportData['prevMonthDaily'] ?? [];

    // Parse into map for easy lookup
    final Map<int, double> selectedMap = {
      for (var item in selectedDaily)
        (item['SaleDay'] as int): _useAmount
            ? (item['TotalAmount'] as num).toDouble()
            : (item['TotalLiter'] as num).toDouble()
    };
    final Map<int, double> prevMap = {
      for (var item in prevDaily)
        (item['SaleDay'] as int): _useAmount
            ? (item['TotalAmount'] as num).toDouble()
            : (item['TotalLiter'] as num).toDouble()
    };

    List<FlSpot> selectedSpots = [];
    List<FlSpot> prevSpots = [];

    // Days in current month & prev month can be up to 31
    for (int day = 1; day <= 31; day++) {
      if (selectedMap.containsKey(day)) {
        selectedSpots.add(FlSpot(day.toDouble(), selectedMap[day]!));
      }
      if (prevMap.containsKey(day)) {
        prevSpots.add(FlSpot(day.toDouble(), prevMap[day]!));
      }
    }

    // Determine max Y limit for chart styling
    double maxY = 0;
    for (var spot in selectedSpots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    for (var spot in prevSpots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    // Round max Y up slightly
    maxY = maxY > 0 ? maxY * 1.15 : 100;

    final String selectedMonthName = _months.firstWhere((m) => m['value'] == _selectedMonth)['name'];
    final String prevMonthName = _months.firstWhere((m) => m['value'] == (_selectedMonth == 1 ? 12 : _selectedMonth - 1))['name'];

    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Sales Growth (Month-over-Month)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comparing $selectedMonthName $_selectedYear with $prevMonthName ${_selectedMonth == 1 ? _selectedYear - 1 : _selectedYear}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                // Legend
                Row(
                  children: [
                    _legendItem(selectedMonthName, HOColors.accent),
                    const SizedBox(width: 16),
                    _legendItem(prevMonthName, Colors.blueAccent),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 350,
              child: selectedSpots.isEmpty && prevSpots.isEmpty
                  ? const Center(child: Text("No daily data available for selected filter."))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: null,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8.0,
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8.0,
                                  child: Text(
                                    _formatYAxisValue(value),
                                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 1,
                        maxX: 31,
                        minY: 0,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final isSelectedMonth = spot.barIndex == 0;
                                final valStr = _useAmount
                                    ? "${NumberFormat('#,###').format(spot.y)} Ks"
                                    : "${spot.y.toStringAsFixed(2)} L";
                                return LineTooltipItem(
                                  "${isSelectedMonth ? selectedMonthName : prevMonthName} Day ${spot.x.toInt()}: \n$valStr",
                                  TextStyle(
                                    color: isSelectedMonth ? HOColors.accent : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: selectedSpots,
                            isCurved: true,
                            color: HOColors.accent,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: HOColors.accent.withOpacity(0.08),
                            ),
                          ),
                          LineChartBarData(
                            spots: prevSpots,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blueAccent.withOpacity(0.04),
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

  Widget _buildMonthlyYoYChartCard(bool isMobile) {
    final List<dynamic> yoyRaw = _reportData['yoy'] ?? [];

    // Parse by Year -> Month -> Value
    final Map<int, Map<int, double>> yoyYearMap = {};
    for (var item in yoyRaw) {
      final y = item['SaleYear'] as int;
      final m = item['SaleMonth'] as int;
      final val = _useAmount
          ? (item['TotalAmount'] as num).toDouble()
          : (item['TotalLiter'] as num).toDouble();

      yoyYearMap[y] ??= {};
      yoyYearMap[y]![m] = val;
    }

    final yearCurrent = _selectedYear;
    final yearPrev1 = yearCurrent - 1;
    final yearPrev2 = yearCurrent - 2;

    List<FlSpot> currentYearSpots = [];
    List<FlSpot> prev1YearSpots = [];
    List<FlSpot> prev2YearSpots = [];

    for (int month = 1; month <= 12; month++) {
      if (yoyYearMap[yearCurrent]?.containsKey(month) ?? false) {
        currentYearSpots.add(FlSpot(month.toDouble(), yoyYearMap[yearCurrent]![month]!));
      }
      if (yoyYearMap[yearPrev1]?.containsKey(month) ?? false) {
        prev1YearSpots.add(FlSpot(month.toDouble(), yoyYearMap[yearPrev1]![month]!));
      }
      if (yoyYearMap[yearPrev2]?.containsKey(month) ?? false) {
        prev2YearSpots.add(FlSpot(month.toDouble(), yoyYearMap[yearPrev2]![month]!));
      }
    }

    double maxY = 0;
    final allSpots = [...currentYearSpots, ...prev1YearSpots, ...prev2YearSpots];
    for (var spot in allSpots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = maxY > 0 ? maxY * 1.15 : 100;

    return Card(
      color: HOColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Sales Comparison (Year-over-Year)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comparing monthly performance across the last 3 years',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
                // Legend
                Row(
                  children: [
                    _legendItem(yearCurrent.toString(), HOColors.accent),
                    const SizedBox(width: 16),
                    _legendItem(yearPrev1.toString(), Colors.greenAccent),
                    const SizedBox(width: 16),
                    _legendItem(yearPrev2.toString(), Colors.white24),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 350,
              child: allSpots.isEmpty
                  ? const Center(child: Text("No YoY data available for selected filter."))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                int idx = value.toInt() - 1;
                                if (idx >= 0 && idx < 12) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8.0,
                                    child: Text(
                                      shortMonths[idx],
                                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 8.0,
                                  child: Text(
                                    _formatYAxisValue(value),
                                    style: const TextStyle(fontSize: 10, color: Colors.white60),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 1,
                        maxX: 12,
                        minY: 0,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                String yrStr = yearCurrent.toString();
                                Color yrColor = HOColors.accent;
                                if (spot.barIndex == 1) {
                                  yrStr = yearPrev1.toString();
                                  yrColor = Colors.greenAccent;
                                } else if (spot.barIndex == 2) {
                                  yrStr = yearPrev2.toString();
                                  yrColor = Colors.white60;
                                }

                                final valStr = _useAmount
                                    ? "${NumberFormat('#,###').format(spot.y)} Ks"
                                    : "${spot.y.toStringAsFixed(2)} L";
                                const shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                return LineTooltipItem(
                                  "$yrStr ${shortMonths[spot.x.toInt() - 1]}: \n$valStr",
                                  TextStyle(
                                    color: yrColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: currentYearSpots,
                            isCurved: true,
                            color: HOColors.accent,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: HOColors.accent.withOpacity(0.08),
                            ),
                          ),
                          LineChartBarData(
                            spots: prev1YearSpots,
                            isCurved: true,
                            color: Colors.greenAccent,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: false,
                            ),
                          ),
                          LineChartBarData(
                            spots: prev2YearSpots,
                            isCurved: true,
                            color: Colors.white24,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
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

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text("No comparison data matches the selected filters.", style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}
