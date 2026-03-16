import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final HODataService _dataService = HODataService();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _chartData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _dataService.getSummaryStats();
      final chartData = await _dataService.getDashboardChartData();
      setState(() {
        _stats = stats;
        _chartData = chartData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dashboard Overview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(child: _summaryCard('Total Points Issued Today', _stats?['pointsToday']?.toString() ?? '0', Icons.stars, Colors.amber)),
              const SizedBox(width: 20),
              Expanded(child: _summaryCard('Total Redemptions', _stats?['redemptionsToday']?.toString() ?? '0', Icons.redeem, Colors.green)),
              const SizedBox(width: 20),
              Expanded(child: _summaryCard('Active Stations', _stats?['activeStations']?.toString() ?? '0', Icons.local_gas_station, Colors.blue)),
              const SizedBox(width: 20),
              Expanded(child: _summaryCard('Online Users', '${_stats?['onlineUsers'] ?? 0} Active', Icons.sensors, Colors.teal)),
            ],
          ),
          
          const SizedBox(height: 40),
          
          SizedBox(
            height: 400,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Points Issued by Stations', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 24),
                          Expanded(child: _buildPointsIssuedList()),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fuel Type Distribution', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 24),
                          Expanded(child: _buildFuelTypeChart()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsIssuedList() {
    final data = _chartData?['pointsByStation'] as List<Map<String, dynamic>>?;
    if (data == null || data.isEmpty) {
      return const Center(child: Text('No point data available', style: TextStyle(color: Colors.white38)));
    }

    final maxVal = data.fold<double>(0, (prev, e) => (e['value'] as double) > prev ? e['value'] as double : prev);

    return ListView.builder(
      itemCount: data.length,
      padding: const EdgeInsets.only(right: 16),
      itemBuilder: (context, index) {
        final station = data[index];
        final points = station['value'] as double;
        final percentage = maxVal > 0 ? points / maxVal : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      station['name'],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    NumberFormat.decimalPattern().format(points.toInt()),
                    style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [HOColors.accent, Color(0xFFB8962D)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: HOColors.accent.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFuelTypeChart() {
    final data = _chartData?['fuelDistribution'] as List<Map<String, dynamic>>?;
    if (data == null || data.isEmpty) {
      return const Center(child: Text('No fuel data available', style: TextStyle(color: Colors.white38)));
    }

    final colors = [
      HOColors.accent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: data.asMap().entries.map((e) {
          final is92 = e.value['name'].toString().contains('92');
          final is95 = e.value['name'].toString().contains('95');
          final isDiesel = e.value['name'].toString().toLowerCase().contains('diesel');
          
          Color sectionColor = colors[e.key % colors.length];
          if (is92) sectionColor = Colors.orangeAccent;
          if (is95) sectionColor = Colors.redAccent;
          if (isDiesel) sectionColor = Colors.greenAccent;

          return PieChartSectionData(
            color: sectionColor,
            value: e.value['value'],
            title: '${e.value['name']}\n${e.value['value'].toInt()}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(icon, color: color.withOpacity(0.8), size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
