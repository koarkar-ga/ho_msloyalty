import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:intl/intl.dart';

class ReportFilterBar extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedStationId;
  final List<dynamic> stations;
  final VoidCallback onDateRangePick;
  final ValueChanged<String?> onStationChange;
  final VoidCallback onExport;

  const ReportFilterBar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedStationId,
    required this.stations,
    required this.onDateRangePick,
    required this.onStationChange,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final double width = MediaQuery.of(context).size.width;
    final bool isSmallScreen = width < 700;

    final stationDropdown = DropdownButtonFormField<String>(
      initialValue: selectedStationId,
      dropdownColor: HOColors.surface,
      decoration: InputDecoration(
        labelText: 'Station',
        labelStyle: const TextStyle(color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.black26,
      ),
      style: const TextStyle(color: Colors.white),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text("All Stations"),
        ),
        ...stations.map(
          (s) => DropdownMenuItem(
            value: s['id'].toString(),
            child: Text(s['name'] ?? 'Unknown'),
          ),
        ),
      ],
      onChanged: onStationChange,
    );

    final dateRangePicker = InkWell(
      onTap: onDateRangePick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date Range',
          labelStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.black26,
          suffixIcon: const Icon(
            Icons.date_range,
            color: Colors.white54,
          ),
        ),
        child: Text(
          '${df.format(startDate)} - ${df.format(endDate)}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );

    final exportButton = ElevatedButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.download, color: Colors.white),
      label: const Text(
        'Export CSV',
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: isSmallScreen ? 14 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    if (isSmallScreen) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: HOColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            stationDropdown,
            const SizedBox(height: 16),
            dateRangePicker,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: exportButton,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: stationDropdown,
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: dateRangePicker,
          ),
          const Spacer(flex: 2),
          exportButton,
        ],
      ),
    );
  }
}
