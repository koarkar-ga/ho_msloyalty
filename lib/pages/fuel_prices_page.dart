import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';

class FuelPricesPage extends StatefulWidget {
  const FuelPricesPage({super.key});

  @override
  State<FuelPricesPage> createState() => _FuelPricesPageState();
}

class _FuelPricesPageState extends State<FuelPricesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HODataService _dataService = HODataService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _fuelPrices = [];
  List<dynamic> _stations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prices = await _dataService.getFuelPrices();
      final stations = await _dataService.getStationsForDropdown();
      if (mounted) {
        setState(() {
          _fuelPrices = prices;
          _stations = stations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditRegionalDialog([Map<String, dynamic>? existing]) {
    showDialog(
      context: context,
      builder: (context) => _EditFuelPriceDialog(
        dataService: _dataService,
        priceData: existing,
        isRegional: true,
        onSaved: _loadData,
      ),
    );
  }

  void _showEditStationDialog(
    Map<String, dynamic> station,
    Map<String, dynamic>? overrideData,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditFuelPriceDialog(
        dataService: _dataService,
        priceData: overrideData,
        isRegional: false,
        station: station,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _deleteOverride(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text(
          'Delete Override',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this station override?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dataService.deleteFuelPrice(id);
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: HOColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: HOColors.accent,
                labelColor: HOColors.accent,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(icon: Icon(Icons.public), text: 'Regional Prices'),
                  Tab(icon: Icon(Icons.ev_station), text: 'Station Overrides'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _showEditRegionalDialog();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Click the Edit button next to a Station to override.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Region'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.accent,
                    foregroundColor: HOColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [_buildRegionalTab(), _buildStationTab()],
                ),
        ),
      ],
    );
  }

  Widget _buildRegionalTab() {
    final regionalPrices = _fuelPrices
        .where((p) => p['station_id'] == null)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: HOColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: HOColors.accent,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(color: Colors.white),
              columns: const [
                DataColumn(label: Text('Region')),
                DataColumn(label: Text('Octane 92')),
                DataColumn(label: Text('Octane 95')),
                DataColumn(label: Text('Diesel')),
                DataColumn(label: Text('Premium Diesel')),
                DataColumn(label: Text('Actions')),
              ],
              rows: regionalPrices.map((region) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        region['region'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataCell(Text('${region['octane_92'] ?? 0} MMK')),
                    DataCell(Text('${region['octane_95'] ?? 0} MMK')),
                    DataCell(Text('${region['diesel'] ?? 0} MMK')),
                    DataCell(Text('${region['premium_diesel'] ?? 0} MMK')),
                    DataCell(
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.amber,
                          size: 20,
                        ),
                        onPressed: () => _showEditRegionalDialog(region),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationTab() {
    final overridePrices = _fuelPrices
        .where((p) => p['station_id'] != null)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: HOColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: HOColors.accent,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(color: Colors.white),
              columns: const [
                DataColumn(label: Text('Station Name')),
                DataColumn(label: Text('Region')),
                DataColumn(label: Text('Octane 92')),
                DataColumn(label: Text('Octane 95')),
                DataColumn(label: Text('Diesel')),
                DataColumn(label: Text('Prem. Diesel')),
                DataColumn(label: Text('Override Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _stations.map((station) {
                final stationId = station['id'].toString();
                // Find if this station has an override
                final overrideData = overridePrices
                    .cast<Map<String, dynamic>?>()
                    .firstWhere(
                      (p) => p != null && p['station_id'] == stationId,
                      orElse: () => null,
                    );

                // If no override, find the regional price
                Map<String, dynamic>? displayData = overrideData;
                if (displayData == null) {
                  final stationRegion = station['region'] ?? '';
                  displayData = _fuelPrices
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                        (p) =>
                            p != null &&
                            p['station_id'] == null &&
                            p['region'] == stationRegion,
                        orElse: () => null,
                      );
                }

                final bool hasOverride = overrideData != null;

                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            station['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ID: ${station['station_id'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(station['region'] ?? 'Unknown')),
                    DataCell(Text('${displayData?['octane_92'] ?? '-'} MMK')),
                    DataCell(Text('${displayData?['octane_95'] ?? '-'} MMK')),
                    DataCell(Text('${displayData?['diesel'] ?? '-'} MMK')),
                    DataCell(
                      Text('${displayData?['premium_diesel'] ?? '-'} MMK'),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasOverride
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasOverride ? 'Overridden' : 'Regional Default',
                          style: TextStyle(
                            color: hasOverride
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.amber,
                              size: 20,
                            ),
                            tooltip: 'Edit Override',
                            onPressed: () => _showEditStationDialog(
                              station as Map<String, dynamic>,
                              overrideData,
                            ),
                          ),
                          if (hasOverride)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: 'Remove Override',
                              onPressed: () =>
                                  _deleteOverride(overrideData['id']),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditFuelPriceDialog extends StatefulWidget {
  final HODataService dataService;
  final Map<String, dynamic>? priceData;
  final bool isRegional;
  final Map<String, dynamic>? station;
  final VoidCallback onSaved;

  const _EditFuelPriceDialog({
    required this.dataService,
    this.priceData,
    required this.isRegional,
    this.station,
    required this.onSaved,
  });

  @override
  State<_EditFuelPriceDialog> createState() => _EditFuelPriceDialogState();
}

class _EditFuelPriceDialogState extends State<_EditFuelPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _octane92Controller;
  late TextEditingController _octane95Controller;
  late TextEditingController _dieselController;
  late TextEditingController _premiumDieselController;
  bool _isSaving = false;
  List<String> _availableRegions = [];
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    final data = widget.priceData ?? {};
    _selectedRegion = data['region']?.toString();
    _octane92Controller = TextEditingController(
      text: data['octane_92']?.toString() ?? '',
    );
    _octane95Controller = TextEditingController(
      text: data['octane_95']?.toString() ?? '',
    );
    _dieselController = TextEditingController(
      text: data['diesel']?.toString() ?? '',
    );
    _premiumDieselController = TextEditingController(
      text: data['premium_diesel']?.toString() ?? '',
    );
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    try {
      final regions = await widget.dataService.getRegions();
      if (mounted) {
        setState(() {
          _availableRegions = regions;
          if (_selectedRegion != null &&
              !_availableRegions.contains(_selectedRegion)) {
            _availableRegions.add(_selectedRegion!);
          }
        });
      }
    } catch (e) {
      // silent fail
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.dataService.upsertFuelPrice(
        id: widget.priceData?['id'],
        region: widget.isRegional ? _selectedRegion : null,
        stationId: widget.isRegional ? null : widget.station?['id'].toString(),
        octane92: int.parse(_octane92Controller.text),
        octane95: int.parse(_octane95Controller.text),
        diesel: int.parse(_dieselController.text),
        premiumDiesel: int.parse(_premiumDieselController.text),
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isRegional
        ? (widget.priceData == null
              ? 'Add Regional Prices'
              : 'Edit Regional Prices')
        : 'Set Station Override';
    String subtitle = widget.isRegional
        ? 'Set baseline prices for a region.'
        : 'Override for: ${widget.station?['name'] ?? 'Unknown'}';

    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isRegional) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedRegion,
                  dropdownColor: HOColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Select Region",
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _availableRegions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: widget.priceData != null
                      ? null
                      : (v) => setState(() => _selectedRegion = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
              ],

              _buildField(
                _octane92Controller,
                "Octane 92 (MMK)",
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                _octane95Controller,
                "Octane 95 (MMK)",
                isNumber: true,
              ),
              const SizedBox(height: 16),
              _buildField(_dieselController, "Diesel (MMK)", isNumber: true),
              const SizedBox(height: 16),
              _buildField(
                _premiumDieselController,
                "Premium Diesel (MMK)",
                isNumber: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: HOColors.primary),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Save Prices',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (isNumber && int.tryParse(v) == null) {
          return 'Must be a valid integer';
        }
        return null;
      },
    );
  }
}
