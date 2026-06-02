import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/tracksolid_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class FleetManagementPage extends StatefulWidget {
  const FleetManagementPage({super.key});

  @override
  State<FleetManagementPage> createState() => _FleetManagementPageState();
}

class _FleetManagementPageState extends State<FleetManagementPage> {
  final TracksolidService _tracksolidService = TracksolidService();
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _liveLocations = [];
  bool _isLoading = true;
  String _searchQuery = "";
  String _selectedSubAccount = "All Sub Accounts";
  String _selectedStatus = "All"; // All, Moving, Idle, Offline
  String _selectedVehicleType = "All Types";
  Timer? _liveTimer;
  String _mapType = "Google Maps";
  double _currentZoom = 11.0;

  // Address geocoding cache and queue
  final Map<String, String> _addressCache = {};
  final Set<String> _geocodingQueue = {};
  bool _isProcessingQueue = false;

  // Map Controls & Selected States
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedDevice;
  Map<String, dynamic>? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh live locations every 30 seconds
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshLiveLocations();
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final deviceList = await _tracksolidService.getDeviceList();
      setState(() {
        _devices = deviceList;
      });

      final imeis = deviceList
          .map((d) => d['imei']?.toString() ?? '')
          .where((imei) => imei.isNotEmpty)
          .toList();

      if (imeis.isNotEmpty) {
        final locations = await _tracksolidService.getLocations(imeis);
        setState(() {
          _liveLocations = locations;
          _isLoading = false;
        });
      } else {
        setState(() {
          _liveLocations = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fleet data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _refreshLiveLocations() async {
    if (_devices.isEmpty) return;
    try {
      final imeis = _devices
          .map((d) => d['imei']?.toString() ?? '')
          .where((imei) => imei.isNotEmpty)
          .toList();
      if (imeis.isNotEmpty) {
        final locations = await _tracksolidService.getLocations(imeis);
        if (mounted) {
          setState(() {
            _liveLocations = locations;
          });
          // Update selected device's location details if open
          if (_selectedDevice != null) {
            final imei = _selectedDevice!['imei']?.toString() ?? '';
            final updatedLoc = locations.firstWhere((l) => l['imei']?.toString() == imei, orElse: () => <String, dynamic>{});
            if (updatedLoc.isNotEmpty) {
              setState(() {
                _selectedLocation = updatedLoc;
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredDevices {
    List<Map<String, dynamic>> list = _devices;

    // 1. Filter by Sub Account
    if (_selectedSubAccount != 'All Sub Accounts') {
      list = list.where((d) => d['subAccountName']?.toString() == _selectedSubAccount).toList();
    }

    // 2. Filter by Status (Moving, Idle, Offline)
    final Map<String, Map<String, dynamic>> liveMap = {};
    for (var loc in _liveLocations) {
      if (loc['imei'] != null) {
        liveMap[loc['imei'].toString()] = loc;
      }
    }

    if (_selectedStatus != 'All') {
      list = list.where((d) {
        final imei = d['imei']?.toString() ?? '';
        final live = liveMap[imei];
        final isOnline = live != null && (live['status'] == '1' || live['status'] == 1);
        final isAccOn = live != null && (live['accStatus'] == '1' || live['accStatus'] == 1);

        if (_selectedStatus == 'Moving') {
          return isOnline && isAccOn;
        } else if (_selectedStatus == 'Idle') {
          return isOnline && !isAccOn;
        } else if (_selectedStatus == 'Offline') {
          return !isOnline;
        }
        return true;
      }).toList();
    }

    // 3. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) {
        final name = d['deviceName']?.toString().toLowerCase() ?? "";
        final imei = d['imei']?.toString().toLowerCase() ?? "";
        return name.contains(_searchQuery.toLowerCase()) || imei.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 4. Filter by Vehicle Type
    if (_selectedVehicleType != 'All Types') {
      list = list.where((d) {
        final icon = d['vehicleIcon']?.toString() ?? 'other';
        return icon.toLowerCase() == _selectedVehicleType.toLowerCase();
      }).toList();
    }

    return list;
  }

  List<String> get _subAccountNames {
    final names = _devices
        .map((d) => d['subAccountName']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return ['All Sub Accounts', ...names];
  }

  List<String> get _vehicleTypes {
    final types = _devices
        .map((d) => d['vehicleIcon']?.toString() ?? 'other')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    types.sort();
    return ['All Types', ...types];
  }

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

  Map<String, Map<String, int>> _calculateSubAccountStats() {
    final Map<String, Map<String, int>> stats = {};

    final subAccounts = _subAccountNames;
    for (var acc in subAccounts) {
      stats[acc] = {
        'total': 0,
        'moving': 0,
        'idle': 0,
        'offline': 0,
      };
    }

    final Map<String, Map<String, dynamic>> liveMap = {};
    for (var loc in _liveLocations) {
      if (loc['imei'] != null) {
        liveMap[loc['imei'].toString()] = loc;
      }
    }

    for (var d in _devices) {
      if (_selectedVehicleType != 'All Types') {
        final icon = d['vehicleIcon']?.toString() ?? 'other';
        if (icon.toLowerCase() != _selectedVehicleType.toLowerCase()) {
          continue;
        }
      }

      final subAcc = d['subAccountName']?.toString() ?? '';
      if (subAcc.isEmpty) continue;
      final imei = d['imei']?.toString() ?? '';
      final live = liveMap[imei];

      final isOnline = live != null && (live['status'] == '1' || live['status'] == 1);
      final isAccOn = live != null && (live['accStatus'] == '1' || live['accStatus'] == 1);

      void increment(String key) {
        if (stats.containsKey(key)) {
          stats[key]!['total'] = (stats[key]!['total'] ?? 0) + 1;
          if (isOnline) {
            if (isAccOn) {
              stats[key]!['moving'] = (stats[key]!['moving'] ?? 0) + 1;
            } else {
              stats[key]!['idle'] = (stats[key]!['idle'] ?? 0) + 1;
            }
          } else {
            stats[key]!['offline'] = (stats[key]!['offline'] ?? 0) + 1;
          }
        }
      }

      increment(subAcc);
      increment('All Sub Accounts');
    }

    return stats;
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=my,en';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'moonsun-dashboard-app',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name']?.toString();
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _addToGeocodingQueue(String imei, double lat, double lng) async {
    final cacheKey = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";
    if (_addressCache.containsKey(cacheKey)) {
      return;
    }

    if (!_geocodingQueue.contains(imei)) {
      _geocodingQueue.add(imei);
      // Process queue asynchronously
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _geocodingQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_geocodingQueue.isNotEmpty) {
      final imei = _geocodingQueue.first;
      _geocodingQueue.remove(imei);

      final loc = _liveLocations.firstWhere(
        (l) => l['imei']?.toString() == imei,
        orElse: () => <String, dynamic>{},
      );

      if (loc.isNotEmpty) {
        final latVal = double.tryParse(loc['lat']?.toString() ?? '');
        final lngVal = double.tryParse(loc['lng']?.toString() ?? '');

        if (latVal != null && lngVal != null && latVal != 0.0 && lngVal != 0.0) {
          final cacheKey = "${latVal.toStringAsFixed(4)},${lngVal.toStringAsFixed(4)}";

          if (!_addressCache.containsKey(cacheKey)) {
            final address = await _reverseGeocode(latVal, lngVal);
            if (address != null && address.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _addressCache[cacheKey] = address;
                });
              }
            }
            // Sleep for 1.5 seconds to respect Nominatim limits
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
      }
    }

    _isProcessingQueue = false;
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

  LatLng _getMapCenter() {
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;
    for (var loc in _liveLocations) {
      final lat = double.tryParse(loc['lat']?.toString() ?? '');
      final lng = double.tryParse(loc['lng']?.toString() ?? '');
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        totalLat += lat;
        totalLng += lng;
        count++;
      }
    }
    if (count > 0) {
      return LatLng(totalLat / count, totalLng / count);
    }
    return const LatLng(16.8409, 96.1735); // Yangon default
  }

  void _zoomToDevice(dynamic lat, dynamic lng, Map<String, dynamic> device, Map<String, dynamic> location) {
    final latVal = double.tryParse(lat.toString()) ?? 0.0;
    final lngVal = double.tryParse(lng.toString()) ?? 0.0;
    if (latVal == 0.0 && lngVal == 0.0) return;

    setState(() {
      _selectedDevice = device;
      _selectedLocation = location;
      _currentZoom = 15.0;
    });

    _mapController.move(LatLng(latVal, lngVal), 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;
    final bool isWide = screenWidth > 1200;
    final double pagePadding = isMobile ? 12.0 : 32.0;
    final double gapHeight = isMobile ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.all(pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            SizedBox(height: gapHeight),
            if (isWide)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (60% width)
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(isMobile),
                          const SizedBox(height: 24),
                          _buildSubAccountsCarousel(),
                          const SizedBox(height: 24),
                          _buildFilters(isMobile),
                          const SizedBox(height: 24),
                          Expanded(child: _buildLiveTable(isMobile)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right Column (40% width)
                    Expanded(
                      flex: 4,
                      child: _buildMapPanel(),
                    ),
                  ],
                ),
              )
            else
              // Standard layout on smaller screens / mobile
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(isMobile),
                      const SizedBox(height: 24),
                      _buildSubAccountsCarousel(),
                      const SizedBox(height: 24),
                      _buildFilters(isMobile),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: isMobile ? 350 : 450,
                        child: _buildLiveTable(isMobile),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: isMobile ? 350 : 450,
                        child: _buildMapPanel(),
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

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FLEET MANAGEMENT SYSTEM',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: isMobile ? 18.0 : 28.0,
                letterSpacing: isMobile ? 1.0 : 2.0,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: isMobile ? 50 : 80,
              height: 4,
              decoration: BoxDecoration(
                gradient: HOColors.premiumGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _loadData,
          icon: Icon(Icons.refresh, color: HOColors.accent, size: isMobile ? 22 : 28),
          tooltip: 'Refresh Fleet Data',
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    if (_isLoading && _liveLocations.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: HOColors.accent)));
    }

    // Calculate stats based on the selected Sub Account and Search Query (without applying status filter)
    final baseFiltered = _devices.where((d) {
      // 1. Filter by Sub Account
      if (_selectedSubAccount != 'All Sub Accounts' && d['subAccountName']?.toString() != _selectedSubAccount) {
        return false;
      }
      // 2. Filter by Search Query
      if (_searchQuery.isNotEmpty) {
        final name = d['deviceName']?.toString().toLowerCase() ?? "";
        final imei = d['imei']?.toString().toLowerCase() ?? "";
        if (!name.contains(_searchQuery.toLowerCase()) && !imei.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      // 3. Filter by Vehicle Type
      if (_selectedVehicleType != 'All Types') {
        final icon = d['vehicleIcon']?.toString() ?? 'other';
        if (icon.toLowerCase() != _selectedVehicleType.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    final baseImeis = baseFiltered.map((d) => d['imei']?.toString() ?? '').toSet();

    final total = baseFiltered.length;
    final onlineCount = _liveLocations.where((l) => baseImeis.contains(l['imei']?.toString()) && (l['status'] == '1' || l['status'] == 1)).length;
    final accOnCount = _liveLocations.where((l) => baseImeis.contains(l['imei']?.toString()) && (l['status'] == '1' || l['status'] == 1) && (l['accStatus'] == '1' || l['accStatus'] == 1)).length;
    final accOffCount = onlineCount - accOnCount;
    final offlineCount = total - onlineCount;

    final card1 = _buildStatCard('TOTAL VEHICLES', total.toString(), Icons.local_shipping, Colors.blueAccent, _selectedStatus == 'All', () {
      setState(() => _selectedStatus = 'All');
    });
    final card2 = _buildStatCard('MOVING (ACC ON)', accOnCount.toString(), Icons.play_arrow_rounded, Colors.greenAccent, _selectedStatus == 'Moving', () {
      setState(() => _selectedStatus = 'Moving');
    });
    final card3 = _buildStatCard('IDLE (ACC OFF)', accOffCount.toString(), Icons.pause_rounded, Colors.orangeAccent, _selectedStatus == 'Idle', () {
      setState(() => _selectedStatus = 'Idle');
    });
    final card4 = _buildStatCard('OFFLINE', offlineCount.toString(), Icons.power_settings_new_rounded, Colors.redAccent, _selectedStatus == 'Offline', () {
      setState(() => _selectedStatus = 'Offline');
    });

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              card1,
              const SizedBox(width: 12),
              card2,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              card3,
              const SizedBox(width: 12),
              card4,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        card1,
        const SizedBox(width: 16),
        card2,
        const SizedBox(width: 16),
        card3,
        const SizedBox(width: 16),
        card4,
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HOColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? color : Colors.white10,
              width: isActive ? 2.0 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(isActive ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    final accounts = _subAccountNames;
    if (!accounts.contains(_selectedSubAccount)) {
      _selectedSubAccount = 'All Sub Accounts';
    }

    final types = _vehicleTypes;
    if (!types.contains(_selectedVehicleType)) {
      _selectedVehicleType = 'All Types';
    }

    final searchField = TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search by Vehicle Name or IMEI...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final subAccountDropdown = DropdownButtonFormField<String>(
      value: _selectedSubAccount,
      dropdownColor: HOColors.surface,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Sub Account Filter',
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        prefixIcon: const Icon(Icons.business_rounded, color: HOColors.accent, size: 18),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: accounts
          .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedSubAccount = v ?? 'All Sub Accounts';
        });
      },
    );

    final vehicleTypeDropdown = DropdownButtonFormField<String>(
      value: _selectedVehicleType,
      dropdownColor: HOColors.surface,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Vehicle Type Filter',
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        prefixIcon: const Icon(Icons.category_rounded, color: HOColors.accent, size: 18),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: types
          .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedVehicleType = v ?? 'All Types';
        });
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: isMobile
              ? Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    subAccountDropdown,
                    const SizedBox(height: 12),
                    vehicleTypeDropdown,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: searchField,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: subAccountDropdown,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: vehicleTypeDropdown,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSubAccountsCarousel() {
    if (_isLoading && _devices.isEmpty) {
      return const SizedBox();
    }
    final stats = _calculateSubAccountStats();
    final accounts = _subAccountNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SUB ACCOUNT STATUS OVERVIEW (TAP TO FILTER)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final accName = accounts[index];
              final accStats = stats[accName] ?? {
                'total': 0,
                'moving': 0,
                'idle': 0,
                'offline': 0,
              };

              final isSelected = _selectedSubAccount == accName;

              return _buildSubAccountCard(accName, accStats, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubAccountCard(String accName, Map<String, int> accStats, bool isSelected) {
    final total = accStats['total'] ?? 0;
    final moving = accStats['moving'] ?? 0;
    final idle = accStats['idle'] ?? 0;
    final offline = accStats['offline'] ?? 0;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? HOColors.accent : Colors.white.withOpacity(0.05),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: HOColors.accent.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _selectedSubAccount = accName;
                _selectedStatus = 'All';
              });
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    accName == 'All Sub Accounts' ? 'ALL ACCOUNTS' : accName.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? HOColors.accent : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$total Veh',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStatusBadge(
                label: 'MOV',
                count: moving,
                color: Colors.greenAccent,
                isActive: isSelected && _selectedStatus == 'Moving',
                onTap: () {
                  setState(() {
                    _selectedSubAccount = accName;
                    _selectedStatus = 'Moving';
                  });
                },
              ),
              _buildMiniStatusBadge(
                label: 'IDL',
                count: idle,
                color: Colors.orangeAccent,
                isActive: isSelected && _selectedStatus == 'Idle',
                onTap: () {
                  setState(() {
                    _selectedSubAccount = accName;
                    _selectedStatus = 'Idle';
                  });
                },
              ),
              _buildMiniStatusBadge(
                label: 'OFF',
                count: offline,
                color: Colors.redAccent,
                isActive: isSelected && _selectedStatus == 'Offline',
                onTap: () {
                  setState(() {
                    _selectedSubAccount = accName;
                    _selectedStatus = 'Offline';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatusBadge({
    required String label,
    required int count,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$label: $count',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataCell _doubleClickableCell({required Widget child, required Map<String, dynamic> device, required Map<String, dynamic>? live}) {
    return DataCell(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: live != null && live['lat'] != null && live['lng'] != null
            ? () => _zoomToDevice(live['lat'], live['lng'], device, live)
            : null,
        child: child,
      ),
    );
  }

  Widget _buildLiveTable(bool isMobile) {
    if (_isLoading && _liveLocations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: HOColors.accent));
    }

    final filtered = _filteredDevices;
    if (filtered.isEmpty) {
      return const Center(child: Text('No vehicles found.', style: TextStyle(color: Colors.white30, fontSize: 16)));
    }

    final Map<String, Map<String, dynamic>> liveMap = {};
    for (var loc in _liveLocations) {
      if (loc['imei'] != null) {
        liveMap[loc['imei'].toString()] = loc;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: isMobile ? 12 : 18,
                horizontalMargin: isMobile ? 8 : 16,
                headingRowHeight: isMobile ? 50 : 60,
                dataRowHeight: isMobile ? 60 : 70,
                headingTextStyle: const TextStyle(
                  color: HOColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
                columns: const [
                  DataColumn(label: Text('VEHICLE NAME')),
                  DataColumn(label: Text('SUB ACCOUNT')),
                  DataColumn(label: Text('IMEI CODE')),
                  DataColumn(label: Text('ACC')),
                  DataColumn(label: Text('SPEED')),
                  DataColumn(label: Text('GPS STATUS')),
                  DataColumn(label: Text('LAST SIGNAL')),
                  DataColumn(label: Text('ADDRESS / LOCATION')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: filtered.map((d) {
                  final imei = d['imei']?.toString() ?? '';
                  final live = liveMap[imei];
                  final subAccountName = d['subAccountName']?.toString() ?? '-';

                  final isOnline = live != null && (live['status'] == '1' || live['status'] == 1);
                  final isAccOn = live != null && (live['accStatus'] == '1' || live['accStatus'] == 1);
                  final speed = live != null ? '${live['speed'] ?? '0'} km/h' : '0 km/h';

                  String gpsTimeStr = '-';
                  if (live != null && live['gpsTime'] != null) {
                    try {
                      final rawTime = live['gpsTime'].toString();
                      if (rawTime.contains('-')) {
                        gpsTimeStr = DateFormat('dd MMM HH:mm').format(DateTime.parse(rawTime).toLocal());
                      } else {
                        final ms = int.tryParse(rawTime);
                        if (ms != null) {
                          gpsTimeStr = DateFormat('dd MMM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms).toLocal());
                        } else {
                          gpsTimeStr = rawTime;
                        }
                      }
                    } catch (_) {
                      gpsTimeStr = live['gpsTime'].toString();
                    }
                  }

                  final latVal = live != null ? double.tryParse(live['lat']?.toString() ?? '') : null;
                  final lngVal = live != null ? double.tryParse(live['lng']?.toString() ?? '') : null;
                  String address = 'Offline';

                  if (live != null) {
                    if (latVal != null && lngVal != null && latVal != 0.0 && lngVal != 0.0) {
                      final cacheKey = "${latVal.toStringAsFixed(4)},${lngVal.toStringAsFixed(4)}";
                      if (_addressCache.containsKey(cacheKey)) {
                        address = _addressCache[cacheKey]!;
                      } else {
                        address = 'Locating...';
                        _addToGeocodingQueue(imei, latVal, lngVal);
                      }
                    } else {
                      address = 'Invalid coordinates';
                    }
                  }

                  return DataRow(
                    cells: [
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getVehicleIcon(d['vehicleIcon']?.toString()),
                              color: isOnline ? (isAccOn ? Colors.greenAccent : Colors.orangeAccent) : Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d['deviceName'] ?? '-',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Text(
                          subAccountName,
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Text(imei, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAccOn ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAccOn ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: isAccOn ? Colors.greenAccent : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Text(
                          speed,
                          style: TextStyle(
                            color: isOnline && isAccOn ? Colors.greenAccent : Colors.white70,
                            fontWeight: isOnline && isAccOn ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOnline ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: Text(gpsTimeStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      _doubleClickableCell(
                        device: d,
                        live: live,
                        child: SizedBox(
                          width: 150,
                          child: Text(
                            address,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          onPressed: live != null && live['lat'] != null && live['lng'] != null
                              ? () => _zoomToDevice(live['lat'], live['lng'], d, live)
                              : null,
                          icon: const Icon(Icons.location_searching, size: 12),
                          label: const Text('TRACK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HOColors.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildMapPanel() {
    final List<Marker> markers = [];
    final Map<String, Map<String, dynamic>> liveMap = {};
    for (var loc in _liveLocations) {
      if (loc['imei'] != null) {
        liveMap[loc['imei'].toString()] = loc;
      }
    }

    for (var d in _filteredDevices) {
      final imei = d['imei']?.toString() ?? '';
      final live = liveMap[imei];
      if (live != null) {
        final lat = double.tryParse(live['lat']?.toString() ?? '');
        final lng = double.tryParse(live['lng']?.toString() ?? '');
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          final isOnline = live['status'] == '1' || live['status'] == 1;
          final isAccOn = live['accStatus'] == '1' || live['accStatus'] == 1;
          final heading = double.tryParse(live['direction']?.toString() ?? '') ?? 0.0;

          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDevice = d;
                    _selectedLocation = live;
                  });
                  _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
                },
                child: VehicleMarker(
                  name: d['deviceName'] ?? '-',
                  isOnline: isOnline,
                  isAccOn: isAccOn,
                  heading: heading,
                  vehicleIcon: d['vehicleIcon']?.toString(),
                ),
              ),
            ),
          );
        }
      }
    }

    final center = _getMapCenter();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: HOColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _currentZoom,
                onPositionChanged: (position, hasGesture) {
                  if (position.zoom != _currentZoom) {
                    _currentZoom = position.zoom;
                    if (_selectedLocation != null) {
                      final lat = double.tryParse(_selectedLocation!['lat']?.toString() ?? '');
                      final lng = double.tryParse(_selectedLocation!['lng']?.toString() ?? '');
                      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                        _mapController.move(LatLng(lat, lng), _currentZoom);
                      }
                    }
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
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: HOColors.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _mapType,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.layers_rounded, color: HOColors.accent, size: 16),
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
            // Map controls (Zoom buttons)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  _buildMapControlBtn(Icons.add, () {
                    LatLng targetCenter = _mapController.camera.center;
                    if (_selectedLocation != null) {
                      final lat = double.tryParse(_selectedLocation!['lat']?.toString() ?? '');
                      final lng = double.tryParse(_selectedLocation!['lng']?.toString() ?? '');
                      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                        targetCenter = LatLng(lat, lng);
                      }
                    }
                    final nextZoom = _mapController.camera.zoom + 1;
                    _currentZoom = nextZoom;
                    _mapController.move(targetCenter, nextZoom);
                  }),
                  const SizedBox(height: 8),
                  _buildMapControlBtn(Icons.remove, () {
                    LatLng targetCenter = _mapController.camera.center;
                    if (_selectedLocation != null) {
                      final lat = double.tryParse(_selectedLocation!['lat']?.toString() ?? '');
                      final lng = double.tryParse(_selectedLocation!['lng']?.toString() ?? '');
                      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                        targetCenter = LatLng(lat, lng);
                      }
                    }
                    final nextZoom = _mapController.camera.zoom - 1;
                    _currentZoom = nextZoom;
                    _mapController.move(targetCenter, nextZoom);
                  }),
                ],
              ),
            ),
            // Selected Device Details Overlay Card
            if (_selectedDevice != null && _selectedLocation != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildDetailsOverlayCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: HOColors.surface.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: HOColors.accent, size: 18),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildDetailsOverlayCard() {
    final d = _selectedDevice!;
    final live = _selectedLocation!;
    final isOnline = live['status'] == '1' || live['status'] == 1;
    final isAccOn = live['accStatus'] == '1' || live['accStatus'] == 1;
    final speed = '${live['speed'] ?? '0'} km/h';
    final lat = live['lat'];
    final lng = live['lng'];
    final imei = live['imei']?.toString() ?? '';
    final latVal = double.tryParse(lat?.toString() ?? '');
    final lngVal = double.tryParse(lng?.toString() ?? '');
    String address = 'Locating...';

    if (latVal != null && lngVal != null && latVal != 0.0 && lngVal != 0.0) {
      final cacheKey = "${latVal.toStringAsFixed(4)},${lngVal.toStringAsFixed(4)}";
      if (_addressCache.containsKey(cacheKey)) {
        address = _addressCache[cacheKey]!;
      } else {
        _addToGeocodingQueue(imei, latVal, lngVal);
      }
    }
    final subAccountName = d['subAccountName']?.toString() ?? '-';

    Color statusColor = Colors.redAccent;
    if (isOnline) {
      statusColor = isAccOn ? Colors.greenAccent : Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HOColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['deviceName'] ?? '-',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sub Account: $subAccountName',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDevice = null;
                    _selectedLocation = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                isOnline ? (isAccOn ? 'MOVING (ACC ON)' : 'IDLE (ACC OFF)') : 'OFFLINE',
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                speed,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Address: $address',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openMap(lat, lng),
                icon: const Icon(Icons.open_in_new, size: 14, color: HOColors.accent),
                label: const Text('GOOGLE MAPS', style: TextStyle(color: HOColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMap(dynamic lat, dynamic lng) async {
    final latVal = double.tryParse(lat.toString()) ?? 0.0;
    final lngVal = double.tryParse(lng.toString()) ?? 0.0;
    if (latVal == 0.0 && lngVal == 0.0) return;

    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latVal,$lngVal';
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
