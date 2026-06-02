import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:intl/intl.dart';

class AssetTransferPage extends StatefulWidget {
  const AssetTransferPage({super.key});

  @override
  State<AssetTransferPage> createState() => _AssetTransferPageState();
}

class _AssetTransferPageState extends State<AssetTransferPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _transfers = [];
  List<Map<String, dynamic>> _filteredTransfers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataService.getAssetTransfers();
      if (mounted) {
        setState(() {
          _transfers = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transfers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTransfers = _transfers.where((t) {
        final asset = t['it_assets'] as Map<String, dynamic>? ?? {};
        final matchesSearch = (asset['asset_code']?.toString().toLowerCase().contains(query) ?? false) ||
            (asset['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (t['from_user']?.toString().toLowerCase().contains(query) ?? false) ||
            (t['to_user']?.toString().toLowerCase().contains(query) ?? false) ||
            (t['from_location']?.toString().toLowerCase().contains(query) ?? false) ||
            (t['to_location']?.toString().toLowerCase().contains(query) ?? false);

        return matchesSearch;
      }).toList();
    });
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _TransferFormDialog(
        dataService: _dataService,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _deleteTransfer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Delete Log', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this transfer log?', style: TextStyle(color: Colors.white70)),
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
        await _dataService.deleteAssetTransfer(id);
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
                      'Asset Transfer Log',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track movement and custody changes of IT assets across locations and users.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Transfer Asset'),
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
                hintText: 'Search by Asset, Users, or Locations...',
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
                  : _filteredTransfers.isEmpty
                      ? const Center(
                          child: Text(
                            'No asset transfer records found.',
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
                                DataColumn(label: Text('Transfer Date')),
                                DataColumn(label: Text('From User')),
                                DataColumn(label: Text('To User')),
                                DataColumn(label: Text('From Location')),
                                DataColumn(label: Text('To Location')),
                                DataColumn(label: Text('Reason')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _filteredTransfers.map((t) {
                                final assetMap = t['it_assets'] as Map<String, dynamic>? ?? {};
                                final assetLabel = "${assetMap['asset_code'] ?? ''} - ${assetMap['name'] ?? ''}";
                                final date = t['transfer_date'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(t['transfer_date']))
                                    : '-';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(assetLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(date)),
                                    DataCell(Text(t['from_user'] ?? '-')),
                                    DataCell(Text(t['to_user'] ?? '-')),
                                    DataCell(Text(t['from_location'] ?? '-')),
                                    DataCell(Text(t['to_location'] ?? '-')),
                                    DataCell(Text(t['reason'] ?? '-')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _deleteTransfer(t['id']),
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

class _TransferFormDialog extends StatefulWidget {
  final HODataService dataService;
  final VoidCallback onSaved;

  const _TransferFormDialog({
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends State<_TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _assets = [];
  String? _selectedAssetId;
  bool _loadingAssets = true;
  bool _isSaving = false;

  final TextEditingController _fromUserController = TextEditingController();
  final TextEditingController _toUserController = TextEditingController();
  final TextEditingController _fromLocController = TextEditingController();
  final TextEditingController _toLocController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    try {
      final list = await widget.dataService.getITAssets();
      // Filter list to show active or in storage assets
      setState(() {
        _assets = list.where((a) => a['status'] == 'Active' || a['status'] == 'In Storage').toList();
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
      'from_user': _fromUserController.text,
      'to_user': _toUserController.text,
      'from_location': _fromLocController.text,
      'to_location': _toLocController.text,
      'reason': _reasonController.text,
      'transfer_date': DateTime.now().toUtc().toIso8601String().split('T')[0],
      'status': 'Completed',
    };

    try {
      await widget.dataService.createAssetTransfer(data);
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
      title: const Text('New Asset Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        decoration: _inputDecoration('Select Asset to Transfer'),
                        items: _assets
                            .map((a) => DropdownMenuItem(
                                  value: a['id'].toString(),
                                  child: Text("${a['asset_code']} - ${a['name']}"),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedAssetId = v;
                            final selected = _assets.firstWhere((a) => a['id'] == v);
                            _fromUserController.text = selected['assigned_user'] ?? '';
                            _fromLocController.text = selected['assigned_station'] ?? '';
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildField(_fromUserController, 'Current Custodian')),
                          const SizedBox(width: 16),
                          Expanded(child: _buildField(_fromLocController, 'Current Location')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildField(_toUserController, 'New Custodian', required: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildField(_toLocController, 'New Location', required: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildField(_reasonController, 'Transfer Reason', required: true, maxLines: 2),
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
              : const Text('Register Transfer', style: TextStyle(color: Colors.white)),
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

  Widget _buildField(TextEditingController controller, String label, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return 'Required';
        return null;
      },
    );
  }
}
