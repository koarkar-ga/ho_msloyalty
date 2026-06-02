import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:intl/intl.dart';

class AssetMaintenancePage extends StatefulWidget {
  const AssetMaintenancePage({super.key});

  @override
  State<AssetMaintenancePage> createState() => _AssetMaintenancePageState();
}

class _AssetMaintenancePageState extends State<AssetMaintenancePage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _maintenances = [];
  List<Map<String, dynamic>> _filteredMaintenances = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataService.getAssetMaintenances();
      if (mounted) {
        setState(() {
          _maintenances = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading maintenance logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaintenances = _maintenances.where((m) {
        final asset = m['it_assets'] as Map<String, dynamic>? ?? {};
        final matchesSearch = (asset['asset_code']?.toString().toLowerCase().contains(query) ?? false) ||
            (asset['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (m['service_provider']?.toString().toLowerCase().contains(query) ?? false) ||
            (m['description']?.toString().toLowerCase().contains(query) ?? false);

        return matchesSearch;
      }).toList();
    });
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _MaintenanceFormDialog(
        dataService: _dataService,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _deleteLog(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Delete Log', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this maintenance log?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
      try {
        await _dataService.deleteAssetMaintenance(id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
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
                      'Asset Maintenance Logs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Record servicing, repairs, and upgrade costs for inventory hardware.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.build, size: 16),
                  label: const Text('Log Maintenance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.accent,
                    foregroundColor: HOColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by Asset, Provider, or Description...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: HOColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => _applyFilters(),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMaintenances.isEmpty
                      ? const Center(
                          child: Text(
                            'No asset maintenance logs found.',
                            style: TextStyle(color: Colors.white30, fontSize: 16),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: HOColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: HOColors.accent,
                              ),
                              dataTextStyle: const TextStyle(color: Colors.white),
                              columns: const [
                                DataColumn(label: Text('Asset')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Maintenance Date')),
                                DataColumn(label: Text('Cost (MMK)')),
                                DataColumn(label: Text('Service Provider')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Next Service')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _filteredMaintenances.map((m) {
                                final assetMap = m['it_assets'] as Map<String, dynamic>? ?? {};
                                final assetLabel = "${assetMap['asset_code'] ?? ''} - ${assetMap['name'] ?? ''}";
                                final date = m['maintenance_date'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(m['maintenance_date']))
                                    : '-';
                                final nextDate = m['next_service_date'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(m['next_service_date']))
                                    : '-';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(assetLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(m['maintenance_type'] ?? '')),
                                    DataCell(Text(date)),
                                    DataCell(Text(NumberFormat('#,###').format(m['cost'] ?? 0))),
                                    DataCell(Text(m['service_provider'] ?? '-')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(m['status'] ?? '').withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getStatusColor(m['status'] ?? '').withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          m['status'] ?? 'Completed',
                                          style: TextStyle(
                                            color: _getStatusColor(m['status'] ?? ''),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(nextDate)),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteLog(m['id']),
                                      ),
                                    ),
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
}

class _MaintenanceFormDialog extends StatefulWidget {
  final HODataService dataService;
  final VoidCallback onSaved;

  const _MaintenanceFormDialog({
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_MaintenanceFormDialog> createState() => _MaintenanceFormDialogState();
}

class _MaintenanceFormDialogState extends State<_MaintenanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _assets = [];
  String? _selectedAssetId;
  bool _loadingAssets = true;
  bool _isSaving = false;

  final TextEditingController _costController = TextEditingController(text: '0');
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _maintType = 'Routine Service';
  String _status = 'Completed';
  DateTime _maintDate = DateTime.now();
  DateTime? _nextServiceDate;

  final List<String> _types = [
    'Routine Service',
    'Hardware Repair',
    'Software Upgrade',
    'Inspection',
    'Other'
  ];

  final List<String> _statuses = ['Scheduled', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    try {
      final list = await widget.dataService.getITAssets();
      setState(() {
        _assets = list;
        _loadingAssets = false;
      });
    } catch (e) {
      setState(() => _loadingAssets = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAssetId == null) return;
    setState(() => _isSaving = true);

    final data = {
      'asset_id': _selectedAssetId,
      'maintenance_date': _maintDate.toIso8601String().split('T')[0],
      'maintenance_type': _maintType,
      'cost': double.tryParse(_costController.text) ?? 0.0,
      'service_provider': _providerController.text,
      'description': _descController.text,
      'status': _status,
      if (_nextServiceDate != null) 'next_service_date': _nextServiceDate!.toIso8601String().split('T')[0],
    };

    try {
      await widget.dataService.createAssetMaintenance(data);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HOColors.background,
      title: const Text('Log Asset Maintenance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        child: _loadingAssets
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedAssetId,
                        dropdownColor: HOColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Select Asset'),
                        items: _assets
                            .map((a) => DropdownMenuItem(
                                  value: a['id'].toString(),
                                  child: Text("${a['asset_code']} - ${a['name']}"),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedAssetId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _maintType,
                              dropdownColor: HOColors.surface,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Maintenance Type'),
                              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _maintType = v ?? 'Routine Service'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              dropdownColor: HOColors.surface,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration('Status'),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? 'Completed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _maintDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _maintDate = picked);
                              },
                              child: InputDecorator(
                                decoration: _inputDecoration('Maintenance Date'),
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_maintDate),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _nextServiceDate ?? DateTime.now().add(const Duration(days: 90)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _nextServiceDate = picked);
                              },
                              child: InputDecorator(
                                decoration: _inputDecoration('Next Service Due (Opt)'),
                                child: Text(
                                  _nextServiceDate != null ? DateFormat('dd MMM yyyy').format(_nextServiceDate!) : 'Select Date',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildField(_costController, 'Maintenance Cost (MMK)', required: true, isNumber: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildField(_providerController, 'Service Provider / Technician')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildField(_descController, 'Service Details / Remarks', required: true, maxLines: 3),
                    ],
                  ),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Log', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool required = false, bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return 'Required';
        if (isNumber && v != null && v.isNotEmpty && double.tryParse(v) == null) {
          return 'Must be a valid number';
        }
        return null;
      },
    );
  }
}
