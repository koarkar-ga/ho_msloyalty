import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/services/station_api_service.dart';

class StationStatusPage extends StatefulWidget {
  const StationStatusPage({super.key});

  @override
  State<StationStatusPage> createState() => _StationStatusPageState();
}

class _StationStatusPageState extends State<StationStatusPage> {
  final HODataService _dataService = HODataService();
  final StationApiService _stationApi = StationApiService();

  bool _isGlobalLoading = false;
  String _searchQuery = '';
  String? _selectedStatusFilter; // 'Online', 'Offline', null = All

  List<Map<String, dynamic>> _stations = [];

  /// station_id → { isOnline, lastSaleTime, voucherNo, latency, error }
  Map<String, Map<String, dynamic>> _stationStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadStationsAndPing();
  }

  // ─── Load + Ping ────────────────────────────────────────────────────────────
  Future<void> _loadStationsAndPing() async {
    if (_isGlobalLoading) return;
    setState(() => _isGlobalLoading = true);

    try {
      final list = await _dataService.getStationsForDropdown();
      if (mounted) setState(() => _stations = list);
      await _pingAllStations();
    } catch (e) {
      _showError('Error loading status dashboard: $e');
    } finally {
      if (mounted) setState(() => _isGlobalLoading = false);
    }
  }

  Future<void> _pingAllStations() async {
    // Ping all stations in parallel via the HO API
    final futures = _stations.map((s) {
      final sId = s['station_id']?.toString() ?? '';
      return _pingStation(sId);
    }).toList();
    await Future.wait(futures);
  }

  Future<void> _pingStation(String stationId) async {
    if (stationId.isEmpty) return;

    final startTime = DateTime.now();
    try {
      // 1. Health check — confirms DB connection
      final health = await _stationApi.healthCheck(stationId: stationId);
      final latencyMs = DateTime.now().difference(startTime).inMilliseconds;
      final isOnline = health['status'] == 'online';

      if (!isOnline) {
        if (mounted) {
          setState(() {
            _stationStatuses[stationId] = {
              'isOnline': false,
              'latency': latencyMs,
              'lastSaleTime': null,
              'voucherNo': null,
              'fuelType': null,
              'amount': null,
              'error': health['error'] ?? 'DB disconnected',
            };
          });
        }
        return;
      }

      // 2. Fetch last sale for extra info
      DateTime? lastSaleTime;
      String? voucherNo;
      String? fuelType;
      double? amount;

      try {
        final now = DateTime.now();
        final sales = await _stationApi.searchSales(
          startDate: now.subtract(const Duration(days: 3)),
          endDate: now,
          stationId: stationId,
        );
        if (sales.isNotEmpty) {
          final last = sales.first;
          voucherNo = last['VocNo']?.toString();
          fuelType = last['FuelTypeName']?.toString();
          amount = ((last['TotalPrice'] ?? 0) as num).toDouble();
          try {
            lastSaleTime = DateTime.parse(last['S_Date'].toString()).toLocal();
          } catch (_) {}
        }
      } catch (_) {
        // last sale not critical — online status already confirmed
      }

      if (mounted) {
        setState(() {
          _stationStatuses[stationId] = {
            'isOnline': true,
            'latency': latencyMs,
            'lastSaleTime': lastSaleTime,
            'voucherNo': voucherNo,
            'fuelType': fuelType,
            'amount': amount,
            'error': null,
          };
        });
      }
    } catch (e) {
      final latencyMs = DateTime.now().difference(startTime).inMilliseconds;
      String errMsg = e.toString();
      if (errMsg.contains('TimeoutException')) errMsg = 'Timeout (8s)';
      else if (errMsg.contains('SocketException')) errMsg = 'Unreachable';
      else if (errMsg.contains('Connection refused')) errMsg = 'Refused';
      else if (errMsg.length > 60) errMsg = '${errMsg.substring(0, 60)}…';

      if (mounted) {
        setState(() {
          _stationStatuses[stationId] = {
            'isOnline': false,
            'latency': latencyMs,
            'lastSaleTime': null,
            'voucherNo': null,
            'fuelType': null,
            'amount': null,
            'error': errMsg,
          };
        });
      }
    }
  }

  // ─── Filtered list ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredStations {
    return _stations.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final code = (s['station_id'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      if (!name.contains(q) && !code.contains(q)) return false;
      if (_selectedStatusFilter != null) {
        final isOnline = _stationStatuses[s['station_id']]?['isOnline'] == true;
        if (_selectedStatusFilter == 'Online' && !isOnline) return false;
        if (_selectedStatusFilter == 'Offline' && isOnline) return false;
      }
      return true;
    }).toList();
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 950;

    final int total = _stations.length;
    final int online =
        _stationStatuses.values.where((v) => v['isOnline'] == true).length;
    final int offline = _stationStatuses.isNotEmpty ? total - online : 0;
    final int pending = total - _stationStatuses.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Station Status (Live)',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pinging via ho.moonsungroup.com:3000/api',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white38),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isGlobalLoading ? null : _loadStationsAndPing,
                icon: _isGlobalLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Refresh All',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HOColors.accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Metrics ──────────────────────────────────────────────────────────
          _buildMetricsBar(total, online, offline, pending, isMobile),
          const SizedBox(height: 24),

          // ── Filters ───────────────────────────────────────────────────────────
          _buildFiltersCard(isMobile),
          const SizedBox(height: 24),

          // ── Station Grid ─────────────────────────────────────────────────────
          _filteredStations.isEmpty
              ? _buildEmptyState()
              : _buildStationsGrid(isMobile),
        ],
      ),
    );
  }

  // ─── Metrics Bar ──────────────────────────────────────────────────────────
  Widget _buildMetricsBar(
      int total, int online, int offline, int pending, bool isMobile) {
    final cards = [
      _metricCard('Total Stations', '$total', Colors.blueAccent,
          Icons.ev_station_rounded),
      _metricCard('Online', '$online', Colors.greenAccent,
          Icons.cloud_done_rounded),
      _metricCard(
          'Offline', '$offline', Colors.redAccent, Icons.cloud_off_rounded),
      if (pending > 0)
        _metricCard('Pending', '$pending', Colors.orangeAccent,
            Icons.hourglass_top_rounded),
    ];

    if (isMobile) {
      return Column(
          children: cards
              .map((c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
              .toList());
    }
    return Row(
        children: cards
            .map((c) => Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16), child: c)))
            .toList());
  }

  Widget _metricCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 28, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(icon, size: 36, color: color.withOpacity(0.4)),
        ],
      ),
    );
  }

  // ─── Filters Card ─────────────────────────────────────────────────────────
  Widget _buildFiltersCard(bool isMobile) {
    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 300,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  labelText: 'Search Station Name or Code',
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            SizedBox(
              width: isMobile ? double.infinity : 200,
              child: DropdownButtonFormField<String>(
                value: _selectedStatusFilter,
                dropdownColor: HOColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Filter Status',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(
                      value: 'Online', child: Text('Online Only')),
                  DropdownMenuItem(
                      value: 'Offline', child: Text('Offline Only')),
                ],
                onChanged: (v) => setState(() => _selectedStatusFilter = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stations Grid ─────────────────────────────────────────────────────────
  Widget _buildStationsGrid(bool isMobile) {
    final list = _filteredStations;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 3,
        childAspectRatio: isMobile ? 2.2 : 1.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final station = list[i];
        final sId = station['station_id']?.toString() ?? '';
        final status = _stationStatuses[sId];
        final isPending = status == null;
        final isOnline = status?['isOnline'] == true;
        final error = status?['error']?.toString();
        final latency = status?['latency'] as int?;
        final voucherNo = status?['voucherNo']?.toString();
        final fuelType = status?['fuelType']?.toString();
        final amount = status?['amount'] as double?;
        final lastSaleTime = status?['lastSaleTime'] as DateTime?;

        final borderColor = isPending
            ? Colors.white12
            : isOnline
                ? Colors.greenAccent.withOpacity(0.22)
                : Colors.redAccent.withOpacity(0.22);

        return Card(
          color: HOColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: name + status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station['name'] ?? 'Unknown',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('ID: $sId',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(isPending, isOnline),
                  ],
                ),
                const Divider(height: 14, color: Colors.white10),

                // Body
                Expanded(
                  child: isPending
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: HOColors.accent),
                          ),
                        )
                      : isOnline
                          ? _onlineBody(
                              voucherNo: voucherNo,
                              fuelType: fuelType,
                              amount: amount,
                              lastSaleTime: lastSaleTime)
                          : _offlineBody(error),
                ),

                // Footer: latency + re-ping
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _pingChip(latency, isOnline),
                    GestureDetector(
                      onTap: () => _pingStation(sId),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: HOColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.sync_rounded,
                            size: 16, color: HOColors.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(bool isPending, bool isOnline) {
    final Color color = isPending
        ? Colors.orangeAccent
        : isOnline
            ? Colors.greenAccent
            : Colors.redAccent;
    final String label =
        isPending ? 'Pending' : isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _onlineBody({
    String? voucherNo,
    String? fuelType,
    double? amount,
    DateTime? lastSaleTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (voucherNo != null)
          _infoRow(Icons.receipt_long_rounded, 'Voucher',
              voucherNo, Colors.white70),
        if (fuelType != null)
          _infoRow(Icons.local_gas_station_rounded, 'Fuel',
              fuelType, HOColors.accent),
        if (amount != null)
          _infoRow(Icons.payments_rounded, 'Amount',
              '${NumberFormat('#,###').format(amount)} Ks', Colors.greenAccent),
        if (lastSaleTime != null)
          _infoRow(Icons.access_time_rounded, 'Last Sale',
              DateFormat('dd MMM, HH:mm').format(lastSaleTime), Colors.white54),
      ],
    );
  }

  Widget _offlineBody(String? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 14, color: Colors.redAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                error ?? 'Connection failed',
                style:
                    const TextStyle(fontSize: 12, color: Colors.redAccent),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white30),
          const SizedBox(width: 5),
          Text('$label: ',
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _pingChip(int? latency, bool isOnline) {
    Color color = Colors.white24;
    if (latency != null) {
      if (latency < 200) color = Colors.greenAccent;
      else if (latency < 600) color = Colors.orangeAccent;
      else color = Colors.redAccent;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.network_ping_rounded, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          latency != null ? '${latency}ms' : 'Pinging…',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.ev_station_outlined, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text('No stations match your filters.',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ),
    );
  }
}
