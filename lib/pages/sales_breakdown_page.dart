import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesBreakdownPage extends StatelessWidget {
  const SalesBreakdownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Breakdown by Station',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const stations = [
                              'St 1',
                              'St 2',
                              'St 3',
                              'St 4',
                              'St 5',
                            ];
                            if (value.toInt() < stations.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  stations[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      _makeGroupData(0, 45, Colors.blue),
                      _makeGroupData(1, 75, Colors.green),
                      _makeGroupData(2, 60, Colors.amber),
                      _makeGroupData(3, 90, Colors.red),
                      _makeGroupData(4, 30, Colors.purple),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: SizedBox(
                      height: 300,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: 40,
                              color: Colors.blue,
                              title: '92 Ron',
                              radius: 60,
                            ),
                            PieChartSectionData(
                              value: 30,
                              color: Colors.green,
                              title: '95 Ron',
                              radius: 60,
                            ),
                            PieChartSectionData(
                              value: 20,
                              color: Colors.amber,
                              title: 'Diesel',
                              radius: 60,
                            ),
                            PieChartSectionData(
                              value: 10,
                              color: Colors.red,
                              title: 'Premium',
                              radius: 60,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 25,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }
}
