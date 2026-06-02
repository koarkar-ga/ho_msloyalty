import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:ms_dashboard/services/session_manager.dart';
import 'package:ms_dashboard/services/station_api_service.dart';
import 'package:ms_dashboard/services/tracksolid_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final HODataService _dataService = HODataService();
  final StationApiService _stationApi = StationApiService();
  final TracksolidService _tracksolidService = TracksolidService();

  Map<String, dynamic>? _chartData;
  bool _isLoading = false;
  int _userLevel = 11; // Default to Staff/lowest level

  // Station counts
  int _totalStations = 0;
  int _onlineStations = 0;
  int _offlineStations = 0;

  // Loyalty counts
  int _totalLoyaltyUsers = 0;
  int _activeLoyaltyUsers = 0;
  int _onlineLoyaltyUsers = 0;

  // Stations status and today liters ranking data
  List<Map<String, dynamic>> _stationsData = [];

  // Recent transactions
  List<Map<String, dynamic>> _recentTransactions = [];

  // GPS Bowser counts
  int _totalGpsBowsers = 0;
  Map<String, Map<String, int>> _subAccountGpsStats = {};
  List<Map<String, dynamic>> _liveBowsers = [];
  Map<String, double> _todayFuelDistribution = {};

  // Loading progress states (0.0 to 1.0, where 1.0 is done)
  double? _userLevelProgress;
  double? _stationStatsProgress;
  double? _loyaltyStatsProgress;
  double? _liveMonitorProgress;
  double? _fleetGpsProgress;
  double? _salesChartsProgress;

  // Map state variables
  final MapController _mapController = MapController();
  String _mapType = 'Google Maps';
  double _currentZoom = 6.0;
  Timer? _gpsTimer;

  // Sorting
  String _stationSortColumn = 'liters'; // 'liters', 'name', 'status'
  bool _stationSortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startGpsTimer();
  }

  void _startGpsTimer() {
    _gpsTimer?.cancel();
    _gpsTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && !_isLoading) {
        _updateGpsData();
      }
    });
  }

  Future<void> _updateGpsData() async {
    try {
      final devices = await _tracksolidService.getDeviceList();
      final totalBowsers = devices.length;
      final imeis = devices
          .map((d) => d['imei']?.toString() ?? '')
          .where((imei) => imei.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> locations = [];
      if (imeis.isNotEmpty) {
        locations = await _tracksolidService.getLocations(imeis);
      }

      final Map<String, Map<String, dynamic>> liveMap = {};
      for (var loc in locations) {
        if (loc['imei'] != null) {
          liveMap[loc['imei'].toString()] = loc;
        }
      }

      final Map<String, Map<String, int>> subAccountStats = {};
      subAccountStats['All Sub Accounts'] = {
        'total': 0,
        'moving': 0,
        'idle': 0,
        'offline': 0,
      };

      final List<Map<String, dynamic>> liveBowsers = [];
      for (var d in devices) {
        final subAcc = d['subAccountName']?.toString() ?? 'Other';
        final imei = d['imei']?.toString() ?? '';
        final live = liveMap[imei];

        final isOnline = live != null && (live['status'] == '1' || live['status'] == 1);
        final isAccOn = live != null && (live['accStatus'] == '1' || live['accStatus'] == 1);
        final lat = double.tryParse(live?['lat']?.toString() ?? '');
        final lng = double.tryParse(live?['lng']?.toString() ?? '');

        liveBowsers.add({
          'deviceName': d['deviceName'] ?? d['device_name'] ?? 'Unknown',
          'imei': imei,
          'subAccountName': subAcc,
          'lat': lat,
          'lng': lng,
          'isOnline': isOnline,
          'isAccOn': isAccOn,
          'speed': live?['speed']?.toString() ?? '0',
          'direction': live?['direction']?.toString() ?? '0',
          'vehicleIcon': d['vehicleIcon'],
        });

        void increment(String key) {
          subAccountStats[key] ??= {
            'total': 0,
            'moving': 0,
            'idle': 0,
            'offline': 0,
          };
          subAccountStats[key]!['total'] = subAccountStats[key]!['total']! + 1;
          if (isOnline) {
            if (isAccOn) {
              subAccountStats[key]!['moving'] = subAccountStats[key]!['moving']! + 1;
            } else {
              subAccountStats[key]!['idle'] = subAccountStats[key]!['idle']! + 1;
            }
          } else {
            subAccountStats[key]!['offline'] = subAccountStats[key]!['offline']! + 1;
          }
        }

        increment(subAcc);
        increment('All Sub Accounts');
      }

      if (mounted) {
        setState(() {
          _totalGpsBowsers = totalBowsers;
          _subAccountGpsStats = subAccountStats;
          _liveBowsers = liveBowsers;
        });
      }
    } catch (e) {
      debugPrint('Error auto-updating GPS data: $e');
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _userLevelProgress = 0.0;
        _stationStatsProgress = 0.0;
        _loyaltyStatsProgress = 0.0;
        _liveMonitorProgress = 0.0;
        _fleetGpsProgress = 0.0;
        _salesChartsProgress = 0.0;
      });
    }

    // Load components in parallel
    Future.wait([
      _fetchUserLevel(),
      _fetchStationStats(),
      _fetchLoyaltyStats(),
      _fetchLiveMonitorAndSales(),
      _fetchFleetGps(),
    ]);
  }

  Future<void> _fetchUserLevel() async {
    try {
      if (mounted) setState(() => _userLevelProgress = 0.3);
      final username = await SessionManager.getUsername();
      int userLevel = 11;
      if (username != null) {
        if (mounted) setState(() => _userLevelProgress = 0.6);
        final userRes = await _dataService.supabase
            .from('ho_auth')
            .select('userlevel')
            .eq('username', username)
            .maybeSingle();
        if (userRes != null) {
          userLevel = int.tryParse(userRes['userlevel']?.toString() ?? '11') ?? 11;
        }
      }
      if (mounted) {
        setState(() {
          _userLevel = userLevel;
          _userLevelProgress = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading user level: $e');
      if (mounted) {
        setState(() => _userLevelProgress = 1.0);
      }
    }
  }

  Future<void> _fetchStationStats() async {
    try {
      if (mounted) setState(() => _stationStatsProgress = 0.1);
      final stationsList = await _dataService.getStationsForDropdown();
      final totalStationsCount = stationsList.length;
      if (mounted) setState(() => _stationStatsProgress = 0.3);

      if (totalStationsCount == 0) {
        if (mounted) {
          setState(() {
            _totalStations = 0;
            _onlineStations = 0;
            _offlineStations = 0;
            _stationStatsProgress = 1.0;
          });
        }
        return;
      }

      int onlineCount = 0;
      for (int i = 0; i < totalStationsCount; i++) {
        final s = stationsList[i];
        final sId = s['station_id']?.toString() ?? '';
        if (sId.isNotEmpty) {
          try {
            final health = await _stationApi.healthCheck(stationId: sId).timeout(const Duration(seconds: 3));
            if (health['status'] == 'online') {
              onlineCount++;
            }
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _stationStatsProgress = 0.3 + ((i + 1) / totalStationsCount) * 0.7;
          });
        }
      }

      if (mounted) {
        setState(() {
          _totalStations = totalStationsCount;
          _onlineStations = onlineCount;
          _offlineStations = totalStationsCount - onlineCount;
          _stationStatsProgress = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching station stats: $e');
      if (mounted) {
        setState(() => _stationStatsProgress = 1.0);
      }
    }
  }

  Future<void> _fetchLoyaltyStats() async {
    try {
      if (mounted) setState(() => _loyaltyStatsProgress = 0.1);
      final totalUserRes = await _dataService.supabase.from('profiles').select('id');
      final totalUsers = totalUserRes.length;
      if (mounted) setState(() => _loyaltyStatsProgress = 0.4);

      final activeUserRes = await _dataService.supabase.from('profiles').select('id').eq('is_active', true);
      final activeUsers = activeUserRes.length;
      if (mounted) setState(() => _loyaltyStatsProgress = 0.7);

      final fiveMinsAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      final onlineUserRes = await _dataService.supabase.from('profiles').select('id').gte('last_login_at', fiveMinsAgo).eq('is_active', true);
      final onlineUsers = onlineUserRes.length;

      if (mounted) {
        setState(() {
          _totalLoyaltyUsers = totalUsers;
          _activeLoyaltyUsers = activeUsers;
          _onlineLoyaltyUsers = onlineUsers;
          _loyaltyStatsProgress = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading loyalty stats: $e');
      if (mounted) {
        setState(() => _loyaltyStatsProgress = 1.0);
      }
    }
  }

  Future<void> _fetchLiveMonitorAndSales() async {
    try {
      if (mounted) {
        setState(() {
          _liveMonitorProgress = 0.1;
          _salesChartsProgress = 0.1;
        });
      }

      // ── 1. Fetch all stations from Supabase ─────────────────────────
      final stationsList = await _dataService.getStationsForDropdown();
      // Build a name lookup map: station_id → name
      final Map<String, String> stationNameMap = {
        for (var s in stationsList)
          (s['station_id']?.toString() ?? ''): (s['name']?.toString() ?? s['station_id']?.toString() ?? ''),
      };

      if (mounted) setState(() { _liveMonitorProgress = 0.25; _salesChartsProgress = 0.25; });

      // ── 2. Fetch today's transactions from Supabase ─────────────────
      final todayStart = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayEnd   = '${todayStart}T23:59:59.999Z';

      final txnResponse = await _dataService.supabase
          .from('fuel_transactions')
          .select('id, station_id, created_at, fuel_type, vehicle_no, sale_liter, amount_mmk, voc_no')
          .gte('created_at', '${todayStart}T00:00:00.000Z')
          .lte('created_at', todayEnd)
          .order('created_at', ascending: false)
          .limit(500);

      final List<Map<String, dynamic>> allTxns =
          List<Map<String, dynamic>>.from(txnResponse);

      if (mounted) setState(() { _liveMonitorProgress = 0.6; _salesChartsProgress = 0.6; });

      // ── 3. Aggregate per station ────────────────────────────────────
      final Map<String, Map<String, dynamic>> stationAgg = {};
      for (var s in stationsList) {
        final sId = s['station_id']?.toString() ?? '';
        stationAgg[sId] = {
          'station_id': sId,
          'name': stationNameMap[sId] ?? sId,
          'online': true, // Supabase data = station has synced (online indicator)
          'todayLiters': 0.0,
          'todayAmount': 0.0,
          'txns': <Map<String, dynamic>>[],
        };
      }

      final Map<String, double> fuelDist = {};

      for (var txn in allTxns) {
        final sId = txn['station_id']?.toString() ?? '';
        final liters  = (txn['sale_liter']  as num?)?.toDouble() ?? 0.0;
        final amount  = (txn['amount_mmk']  as num?)?.toDouble() ?? 0.0;
        final fuelType = txn['fuel_type']?.toString() ?? 'Other';

        if (stationAgg.containsKey(sId)) {
          stationAgg[sId]!['todayLiters'] = (stationAgg[sId]!['todayLiters'] as double) + liters;
          stationAgg[sId]!['todayAmount'] = (stationAgg[sId]!['todayAmount'] as double) + amount;
          (stationAgg[sId]!['txns'] as List).add({
            ...txn,
            'station_name': stationNameMap[sId] ?? sId,
          });
        }

        fuelDist[fuelType] = (fuelDist[fuelType] ?? 0.0) + liters;
      }

      final List<Map<String, dynamic>> stationsData = stationAgg.values.toList();

      // ── 4. Recent 20 transactions (already sorted desc) ─────────────
      final recentTxns = allTxns.take(20).map((txn) {
        final sId = txn['station_id']?.toString() ?? '';
        return <String, dynamic>{
          ...txn,
          'station_name': stationNameMap[sId] ?? sId,
          // Normalise field names so the UI widget works unchanged
          'S_Date':       txn['created_at'],
          'SALELITER':    txn['sale_liter'],
          'TotalPrice':   txn['amount_mmk'],
          'FuelTypeName': txn['fuel_type'],
          'Vehical_No':   txn['vehicle_no'],
        };
      }).toList();

      if (mounted) setState(() { _liveMonitorProgress = 0.85; _salesChartsProgress = 0.85; });

      // ── 5. Chart data ───────────────────────────────────────────────
      final chartData = await _dataService.getDashboardChartData();

      if (mounted) {
        setState(() {
          _stationsData        = stationsData;
          _recentTransactions  = recentTxns;
          _todayFuelDistribution = fuelDist;
          _chartData           = chartData;
          _liveMonitorProgress  = 1.0;
          _salesChartsProgress  = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales / monitor data: $e');
      if (mounted) {
        setState(() {
          _liveMonitorProgress = 1.0;
          _salesChartsProgress = 1.0;
        });
      }
    }
  }

  Future<void> _fetchFleetGps() async {
    try {
      if (mounted) setState(() => _fleetGpsProgress = 0.1);
      final devices = await _tracksolidService.getDeviceList();
      final totalBowsers = devices.length;
      if (mounted) setState(() => _fleetGpsProgress = 0.4);

      final imeis = devices
          .map((d) => d['imei']?.toString() ?? '')
          .where((imei) => imei.isNotEmpty)
          .toList();

      List<Map<String, dynamic>> locations = [];
      if (imeis.isNotEmpty) {
        locations = await _tracksolidService.getLocations(imeis);
      }
      if (mounted) setState(() => _fleetGpsProgress = 0.8);

      final Map<String, Map<String, dynamic>> liveMap = {};
      for (var loc in locations) {
        if (loc['imei'] != null) {
          liveMap[loc['imei'].toString()] = loc;
        }
      }

      final Map<String, Map<String, int>> subAccountStats = {};
      subAccountStats['All Sub Accounts'] = {
        'total': 0,
        'moving': 0,
        'idle': 0,
        'offline': 0,
      };

      final List<Map<String, dynamic>> liveBowsers = [];
      for (var d in devices) {
        final subAcc = d['subAccountName']?.toString() ?? 'Other';
        final imei = d['imei']?.toString() ?? '';
        final live = liveMap[imei];

        final isOnline = live != null && (live['status'] == '1' || live['status'] == 1);
        final isAccOn = live != null && (live['accStatus'] == '1' || live['accStatus'] == 1);
        final lat = double.tryParse(live?['lat']?.toString() ?? '');
        final lng = double.tryParse(live?['lng']?.toString() ?? '');

        liveBowsers.add({
          'deviceName': d['deviceName'] ?? d['device_name'] ?? 'Unknown',
          'imei': imei,
          'subAccountName': subAcc,
          'lat': lat,
          'lng': lng,
          'isOnline': isOnline,
          'isAccOn': isAccOn,
          'speed': live?['speed']?.toString() ?? '0',
          'direction': live?['direction']?.toString() ?? '0',
          'vehicleIcon': d['vehicleIcon'],
        });

        void increment(String key) {
          subAccountStats[key] ??= {
            'total': 0,
            'moving': 0,
            'idle': 0,
            'offline': 0,
          };
          subAccountStats[key]!['total'] = subAccountStats[key]!['total']! + 1;
          if (isOnline) {
            if (isAccOn) {
              subAccountStats[key]!['moving'] = subAccountStats[key]!['moving']! + 1;
            } else {
              subAccountStats[key]!['idle'] = subAccountStats[key]!['idle']! + 1;
            }
          } else {
            subAccountStats[key]!['offline'] = subAccountStats[key]!['offline']! + 1;
          }
        }

        increment(subAcc);
        increment('All Sub Accounts');
      }

      if (mounted) {
        setState(() {
          _totalGpsBowsers = totalBowsers;
          _subAccountGpsStats = subAccountStats;
          _liveBowsers = liveBowsers;
          _fleetGpsProgress = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading GPS: $e');
      if (mounted) {
        setState(() => _fleetGpsProgress = 1.0);
      }
    }
  }

  Widget _buildStationSummaryCards(double width) {
    final cards = [
      _summaryCard('Total Stations', '$_totalStations', Icons.local_gas_station, Colors.blue),
      _summaryCard('Online Stations', '$_onlineStations', Icons.wifi_rounded, Colors.green),
      _summaryCard('Offline Stations', '$_offlineStations', Icons.wifi_off_rounded, Colors.red),
    ];

    return _layoutCards(width, cards);
  }

  Widget _buildLoyaltySummaryCards(double width) {
    final cards = [
      _summaryCard('Total Loyalty Users', '$_totalLoyaltyUsers', Icons.people_rounded, Colors.purple),
      _summaryCard('Active Users', '$_activeLoyaltyUsers', Icons.check_circle_rounded, Colors.orange),
      _summaryCard('Online Users (5m)', '$_onlineLoyaltyUsers', Icons.sensors_rounded, Colors.teal),
    ];

    return _layoutCards(width, cards);
  }

  Widget _layoutCards(double width, List<Widget> cards) {
    if (width < 600) {
      return Column(
        children: cards.map((card) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: card,
        )).toList(),
      );
    } else {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
        ],
      );
    }
  }

  Widget _buildLiveTransactionsCard() {
    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live Sale Transaction Logs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentTransactions.isEmpty)
              const SizedBox(
                height: 300,
                child: Center(
                  child: Text('No transaction logs available', style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _recentTransactions.length,
                  itemBuilder: (context, index) {
                    final txn = _recentTransactions[index];
                    final stationName = txn['station_name'] ?? 'Station';
                    final timeStr = txn['S_Date']?.toString() ?? '';
                    String time = '--:--';
                    try {
                      time = DateFormat('HH:mm:ss').format(DateTime.parse(timeStr).toLocal());
                    } catch (_) {
                      if (timeStr.length >= 19) {
                        time = timeStr.substring(11, 19);
                      } else {
                        time = timeStr;
                      }
                    }
                    final vehicle = txn['Vehical_No'] ?? '-';
                    final fuelType = txn['FuelTypeName'] ?? '-';
                    final liters = (txn['SALELITER'] ?? 0.0) as num;
                    final amount = (txn['TotalPrice'] ?? 0.0) as num;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HOColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.03)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    stationName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    time,
                                    style: const TextStyle(color: Colors.white30, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Plate: $vehicle • Fuel: $fuelType',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${liters.toStringAsFixed(2)} L',
                                style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${NumberFormat('#,###').format(amount)} Ks',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationRankingCard() {
    List<Map<String, dynamic>> sortedList = List.from(_stationsData);
    sortedList.sort((a, b) {
      int cmp = 0;
      if (_stationSortColumn == 'name') {
        cmp = (a['name'] ?? '').compareTo(b['name'] ?? '');
      } else if (_stationSortColumn == 'status') {
        final aOnline = a['online'] == true ? 1 : 0;
        final bOnline = b['online'] == true ? 1 : 0;
        cmp = aOnline.compareTo(bOnline);
      } else {
        final aLiters = (a['todayLiters'] ?? 0.0) as double;
        final bLiters = (b['todayLiters'] ?? 0.0) as double;
        cmp = aLiters.compareTo(bLiters);
      }
      return _stationSortAscending ? cmp : -cmp;
    });

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.leaderboard_rounded, color: HOColors.accent, size: 20),
                SizedBox(width: 8),
                Text(
                  "Today's Sales Liter per Station",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedList.isEmpty)
              const SizedBox(
                height: 300,
                child: Center(
                  child: Text('No station ranking data available', style: TextStyle(color: Colors.white38)),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 8,
                      sortColumnIndex: _stationSortColumn == 'name'
                          ? 1
                          : _stationSortColumn == 'status'
                              ? 2
                              : 3,
                      sortAscending: _stationSortAscending,
                      columns: [
                        const DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white60))),
                        DataColumn(
                          label: const Text('Station', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _stationSortColumn = 'name';
                              _stationSortAscending = ascending;
                            });
                          },
                        ),
                        DataColumn(
                          label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _stationSortColumn = 'status';
                              _stationSortAscending = ascending;
                            });
                          },
                        ),
                        DataColumn(
                          label: const Text('Today Liters', style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true,
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _stationSortColumn = 'liters';
                              _stationSortAscending = ascending;
                            });
                          },
                        ),
                        const DataColumn(
                          label: Text('Today Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                          numeric: true,
                        ),
                      ],
                      rows: sortedList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final rank = _stationSortAscending ? sortedList.length - index : index + 1;
                        final isOnline = item['online'] == true;
                        final liters = (item['todayLiters'] ?? 0.0) as double;
                        final amount = (item['todayAmount'] ?? 0.0) as double;

                        return DataRow(
                          cells: [
                            DataCell(Text('#$rank', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
                            DataCell(Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOnline ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color: isOnline ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(NumberFormat('#,##0.00').format(liters), style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold))),
                            DataCell(Text('${NumberFormat('#,###').format(amount)} Ks', style: const TextStyle(color: Colors.white70))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAndRankingSection(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          _buildLiveTransactionsCard(),
          const SizedBox(height: 20),
          _buildStationRankingCard(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildLiveTransactionsCard()),
        const SizedBox(width: 20),
        Expanded(child: _buildStationRankingCard()),
      ],
    );
  }

  Widget _buildFleetGpsTrackerCard(bool isMobile) {
    if (_subAccountGpsStats.isEmpty) {
      return Card(
        color: HOColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text('No GPS tracking statistics available', style: TextStyle(color: Colors.white38)),
          ),
        ),
      );
    }

    final statsList = _subAccountGpsStats.entries
        .where((e) => e.key != 'All Sub Accounts')
        .toList();
    
    statsList.sort((a, b) => a.key.compareTo(b.key));

    final allStats = _subAccountGpsStats['All Sub Accounts'] ?? {'total': 0, 'moving': 0, 'idle': 0, 'offline': 0};

    // Build markers
    final markers = <Marker>[];
    for (var b in _liveBowsers) {
      final double? lat = b['lat'];
      final double? lng = b['lng'];
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final isOnline = b['isOnline'] == true;
        final isAccOn = b['isAccOn'] == true;
        final double heading = double.tryParse(b['direction']?.toString() ?? '0') ?? 0.0;

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 75,
            height: 75,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${b['deviceName']}\nSpeed: ${b['speed']} km/h\nStatus: ${isOnline ? (isAccOn ? "Moving" : "Idle") : "Offline"}',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: VehicleMarker(
                name: b['deviceName'] ?? '-',
                isOnline: isOnline,
                isAccOn: isAccOn,
                heading: heading,
                vehicleIcon: b['vehicleIcon']?.toString(),
              ),
            ),
          ),
        );
      }
    }

    final mapCenter = _getMapCenter();

    // Map Widget using Google Maps and OpenStreetMap templates
    final mapWidget = Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: _currentZoom,
                onPositionChanged: (position, hasGesture) {
                  if (position.zoom != _currentZoom) {
                    _currentZoom = position.zoom;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapUrlTemplate,
                  userAgentPackageName: 'com.moonsun.ms_dashboard',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            // Map Type Selector
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: HOColors.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mapType,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.layers_rounded, color: HOColors.accent, size: 14),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _mapType = v;
                        });
                      }
                    },
                    items: ['Google Maps', 'Google Satellite', 'OpenStreetMap']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
            // Map Legend
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HOColors.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem('Moving', Colors.greenAccent),
                    const SizedBox(height: 4),
                    _legendItem('Idle', Colors.orangeAccent),
                    const SizedBox(height: 4),
                    _legendItem('Offline', Colors.redAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Responsive body layout
    Widget bodyContent;
    if (isMobile) {
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildStatsTable(allStats, statsList, isMobile),
            ),
          ),
          const SizedBox(height: 20),
          mapWidget,
        ],
      );
    } else {
      bodyContent = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildStatsTable(allStats, statsList, isMobile),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: mapWidget,
          ),
        ],
      );
    }

    return Card(
      color: HOColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, color: Colors.blueAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Fleet GPS Tracker',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalGpsBowsers Total Bowsers',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            bodyContent,
          ],
        ),
      ),
    );
  }

  LatLng _getMapCenter() {
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;
    for (var b in _liveBowsers) {
      final double? lat = b['lat'];
      final double? lng = b['lng'];
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        totalLat += lat;
        totalLng += lng;
        count++;
      }
    }
    if (count > 0) {
      return LatLng(totalLat / count, totalLng / count);
    }
    return const LatLng(16.8409, 96.1735); // Yangon Default
  }

  String get _mapUrlTemplate {
    switch (_mapType) {
      case 'Google Satellite':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'OpenStreetMap':
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'Google Maps':
      default:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatsTable(Map<String, int> allStats, List<MapEntry<String, Map<String, int>>> statsList, bool isMobile) {
    return DataTable(
      columnSpacing: isMobile ? 12 : 24,
      horizontalMargin: 8,
      headingTextStyle: const TextStyle(
        color: HOColors.accent,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      columns: const [
        DataColumn(label: Text('SUB ACCOUNT')),
        DataColumn(label: Text('TOTAL'), numeric: true),
        DataColumn(label: Text('MOVING'), numeric: true),
        DataColumn(label: Text('IDLE'), numeric: true),
        DataColumn(label: Text('OFFLINE'), numeric: true),
      ],
      rows: [
        DataRow(
          selected: true,
          cells: [
            const DataCell(Text('ALL SUB ACCOUNTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            DataCell(Text('${allStats['total']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            DataCell(Text('${allStats['moving']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent))),
            DataCell(Text('${allStats['idle']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent))),
            DataCell(Text('${allStats['offline']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
          ],
        ),
        ...statsList.map((entry) {
          final name = entry.key;
          final s = entry.value;
          return DataRow(
            cells: [
              DataCell(Text(name, style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${s['total']}', style: const TextStyle(color: Colors.white70))),
              DataCell(Text('${s['moving']}', style: const TextStyle(color: Colors.greenAccent))),
              DataCell(Text('${s['idle']}', style: const TextStyle(color: Colors.orangeAccent))),
              DataCell(Text('${s['offline']}', style: const TextStyle(color: Colors.redAccent))),
            ],
          );
        }).toList(),
      ],
    );
  }

  String _getStationNameFromId(String? id) {
    if (id == null) return 'Unknown';
    try {
      final s = _stationsData.firstWhere(
        (element) => element['station_id']?.toString() == id.toString(),
      );
      return s['name']?.toString() ?? id;
    } catch (_) {
      return 'Station $id';
    }
  }

  Widget _buildTodayStationSalesCard(bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Station Sales (Liters)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            isDesktop
                ? Expanded(child: _buildTodayStationSalesList())
                : SizedBox(height: 300, child: _buildTodayStationSalesList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelTypeCard(bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fuel Type Distribution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            isDesktop
                ? Expanded(child: _buildFuelTypeChart())
                : SizedBox(height: 300, child: _buildFuelTypeChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerSummaryCards(double width, double? progress, String label) {
    final cards = [
      HOShimmerPlaceholder(width: double.infinity, height: 120, progress: progress, label: label, showProgress: false),
      HOShimmerPlaceholder(width: double.infinity, height: 120, progress: progress, label: label, showProgress: true),
      HOShimmerPlaceholder(width: double.infinity, height: 120, progress: progress, label: label, showProgress: false),
    ];
    return _layoutCards(width, cards);
  }

  Widget _buildShimmerLiveAndRankingSection(bool isMobile, double? progress) {
    final shimmers = [
      HOShimmerPlaceholder(width: double.infinity, height: 380, progress: progress, label: 'Loading Logs', showProgress: true),
      HOShimmerPlaceholder(width: double.infinity, height: 380, progress: progress, label: 'Loading Ranking', showProgress: false),
    ];
    if (isMobile) {
      return Column(
        children: [
          shimmers[0],
          const SizedBox(height: 20),
          shimmers[1],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: shimmers[0]),
        const SizedBox(width: 20),
        Expanded(child: shimmers[1]),
      ],
    );
  }

  Widget _buildShimmerSalesCharts(bool isMobile, double? progress) {
    if (isMobile) {
      return Column(
        children: [
          HOShimmerPlaceholder(width: double.infinity, height: 300, progress: progress, label: 'Loading Sales Chart', showProgress: true),
          const SizedBox(height: 20),
          HOShimmerPlaceholder(width: double.infinity, height: 300, progress: progress, showProgress: false),
        ],
      );
    }
    return SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: HOShimmerPlaceholder(width: double.infinity, height: 400, progress: progress, label: 'Loading Sales Charts', showProgress: true),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: HOShimmerPlaceholder(width: double.infinity, height: 400, progress: progress, showProgress: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width <= 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (width < 600)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadAllData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HOColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            )
          else
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

          Text(
            'STATION STATS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _stationStatsProgress == null || _stationStatsProgress! < 1.0
              ? _buildShimmerSummaryCards(width, _stationStatsProgress, 'Loading Station Stats')
              : _buildStationSummaryCards(width),
          const SizedBox(height: 24),

          Text(
            'LOYALTY APP STATS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _loyaltyStatsProgress == null || _loyaltyStatsProgress! < 1.0
              ? _buildShimmerSummaryCards(width, _loyaltyStatsProgress, 'Loading Loyalty Stats')
              : _buildLoyaltySummaryCards(width),
          const SizedBox(height: 32),

          if (_userLevelProgress == 1.0 && _userLevel <= 2) ...[
            Text(
              'LIVE STATIONS MONITOR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _liveMonitorProgress == null || _liveMonitorProgress! < 1.0
                ? _buildShimmerLiveAndRankingSection(width < 1024, _liveMonitorProgress)
                : _buildLiveAndRankingSection(width < 1024),
            const SizedBox(height: 32),

            Text(
              'FLEET GPS STATS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _fleetGpsProgress == null || _fleetGpsProgress! < 1.0
                ? HOShimmerPlaceholder(width: double.infinity, height: 480, progress: _fleetGpsProgress, label: 'Loading GPS Tracker')
                : _buildFleetGpsTrackerCard(width < 950),
            const SizedBox(height: 32),
          ],

          Text(
            'TODAY\'S SALES CHARTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _salesChartsProgress == null || _salesChartsProgress! < 1.0
              ? _buildShimmerSalesCharts(width < 1024, _salesChartsProgress)
              : (width < 1024
                  ? Column(
                      children: [
                        _buildTodayStationSalesCard(false),
                        const SizedBox(height: 20),
                        _buildFuelTypeCard(false),
                      ],
                    )
                  : SizedBox(
                      height: 400,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildTodayStationSalesCard(true),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildFuelTypeCard(true),
                          ),
                        ],
                      ),
                    )),
        ],
      ),
    );
  }

  Widget _buildTodayStationSalesList() {
    final sortedStations = List<Map<String, dynamic>>.from(_stationsData)
      ..sort((a, b) => ((b['todayLiters'] ?? 0.0) as double).compareTo((a['todayLiters'] ?? 0.0) as double));

    if (sortedStations.isEmpty || sortedStations.every((element) => (element['todayLiters'] ?? 0.0) == 0.0)) {
      return const Center(child: Text('No station sales data for today', style: TextStyle(color: Colors.white38)));
    }

    final double maxLiters = sortedStations.isEmpty
        ? 1.0
        : ((sortedStations.first['todayLiters'] ?? 0.0) as double);
    final double divisor = maxLiters > 0.0 ? maxLiters : 1.0;

    return ListView.builder(
      itemCount: sortedStations.length,
      padding: const EdgeInsets.only(right: 16),
      itemBuilder: (context, index) {
        final station = sortedStations[index];
        final double liters = (station['todayLiters'] ?? 0.0) as double;
        final percentage = liters / divisor;

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
                      station['name'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,##0.0').format(liters)} L',
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
                    widthFactor: percentage > 0.0 ? percentage : 0.001,
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
    if (_todayFuelDistribution.isEmpty) {
      return const Center(child: Text('No fuel sales data for today', style: TextStyle(color: Colors.white38)));
    }

    final colors = [
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
    ];

    int colorIndex = 0;
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: _todayFuelDistribution.entries.map((e) {
          final name = e.key;
          final val = e.value;
          final is92 = name.contains('92');
          final is95 = name.contains('95');
          final isDiesel = name.toLowerCase().contains('diesel');
          
          Color sectionColor = colors[colorIndex % colors.length];
          colorIndex++;
          if (is92) sectionColor = Colors.orangeAccent;
          if (is95) sectionColor = Colors.redAccent;
          if (isDiesel) sectionColor = Colors.greenAccent;

          return PieChartSectionData(
            color: sectionColor,
            value: val,
            title: '$name\n${NumberFormat('#,##0').format(val)} L',
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

class HOShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double? progress;
  final String label;
  final bool showProgress;

  const HOShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.progress,
    this.label = 'Loading',
    this.showProgress = true,
  });

  @override
  State<HOShimmerPlaceholder> createState() => _HOShimmerPlaceholderState();
}

class _HOShimmerPlaceholderState extends State<HOShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.progress != null ? (widget.progress! * 100).toInt() : null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: HOColors.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FractionallySizedBox(
                    widthFactor: 2.0,
                    alignment: Alignment(-1.0 + (_controller.value * 2.0), 0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.05),
                            Colors.transparent,
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showProgress)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.progress != null) ...[
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            value: widget.progress,
                            strokeWidth: 3,
                            color: HOColors.accent,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.label}... $percent%',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: HOColors.accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.label}...',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class VehicleMarker extends StatelessWidget {
  final String name;
  final bool isOnline;
  final bool isAccOn;
  final double heading;
  final String? vehicleIcon;

  const VehicleMarker({
    super.key,
    required this.name,
    required this.isOnline,
    required this.isAccOn,
    required this.heading,
    this.vehicleIcon,
  });

  IconData _getVehicleIcon(String? iconType) {
    switch (iconType?.toLowerCase()) {
      case 'automobile':
      case 'car':
        return Icons.directions_car_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      case 'blender':
        return Icons.engineering_rounded;
      case 'excavator':
        return Icons.construction_rounded;
      default:
        return Icons.local_shipping_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color markerColor = Colors.redAccent;
    if (isOnline) {
      markerColor = isAccOn ? Colors.greenAccent : Colors.orangeAccent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: markerColor.withOpacity(0.6), width: 1),
          ),
          child: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        // Icon / pin with directional pointer
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: heading * 3.141592653589793 / 180,
              child: Align(
                alignment: const Alignment(0, -1.6),
                child: Icon(
                  Icons.arrow_drop_up_rounded,
                  color: markerColor,
                  size: 18,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: HOColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: markerColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: markerColor.withOpacity(0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getVehicleIcon(vehicleIcon),
                  color: markerColor,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
