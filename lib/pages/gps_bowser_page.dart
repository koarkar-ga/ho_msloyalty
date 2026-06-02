import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:intl/intl.dart';

class GpsBowserPage extends StatefulWidget {
  const GpsBowserPage({super.key});

  @override
  State<GpsBowserPage> createState() => _GpsBowserPageState();
}

class _GpsBowserPageState extends State<GpsBowserPage> {
  final HODataService _dataService = HODataService();
  List<Map<String, dynamic>> _bowsers = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getBowserGpsList();
      setState(() {
        _bowsers = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBowsers {
    if (_searchQuery.isEmpty) return _bowsers;
    return _bowsers.where((b) {
      final name = b['device_name']?.toString().toLowerCase() ?? "";
      final imei = b['imei_code']?.toString().toLowerCase() ?? "";
      final owner = b['owner_name']?.toString().toLowerCase() ?? "";
      return name.contains(_searchQuery.toLowerCase()) ||
          imei.contains(_searchQuery.toLowerCase()) ||
          owner.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 850;
    final double pagePadding = isMobile ? 16.0 : 32.0;
    final double gapHeight = isMobile ? 16.0 : 32.0;

    return Padding(
      padding: EdgeInsets.all(pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          SizedBox(height: gapHeight),
          _buildFilters(isMobile),
          const SizedBox(height: 24),
          Expanded(child: _buildGlassyTable()),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GPS BOWSER MANAGEMENT',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: isMobile ? 20.0 : 28.0,
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
    );

    final buttonWidget = ElevatedButton.icon(
      onPressed: () => _showAddEditDialog(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('ADD NEW BOWSER'),
      style: ElevatedButton.styleFrom(
        backgroundColor: HOColors.accent,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 12 : 18,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: buttonWidget,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        titleWidget,
        buttonWidget,
      ],
    );
  }

  Widget _buildFilters(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by Device Name, IMEI or Owner...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 20),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: HOColors.accent),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyTable() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: HOColors.accent),
      );
    }

    final filtered = _filteredBowsers;

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
                columnSpacing: 24,
                horizontalMargin: 24,
                headingRowHeight: 70,
                dataRowHeight: 80,
                headingTextStyle: const TextStyle(
                  color: HOColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
                columns: const [
                  DataColumn(label: Text('DEVICE NAME')),
                  DataColumn(label: Text('GL')),
                  DataColumn(label: Text('VEHICLE TYPE')),
                  DataColumn(label: Text('OWNER')),
                  DataColumn(label: Text('PHONE')),
                  DataColumn(label: Text('IMEI CODE')),
                  DataColumn(label: Text('MODEL')),
                  DataColumn(label: Text('PPRD CONNECT')),
                  DataColumn(label: Text('EXPIRE SUB')),
                  DataColumn(label: Text('ACTIONS')),
                ],
                rows: filtered.map((b) => _buildDataRow(b)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> b) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            b['device_name'] ?? '-',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Text(
            b['gl']?.toString() ?? '0',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            b['vehicle_type'] ?? '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            b['owner_name'] ?? '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            b['ph_no'] ?? '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            b['imei_code'] ?? '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Text(
            b['device_model'] ?? '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (b['pprd_connect'] == 'Connected')
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (b['pprd_connect'] == 'Connected')
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
              ),
            ),
            child: Text(
              b['pprd_connect'] ?? 'Disconnected',
              style: TextStyle(
                color: (b['pprd_connect'] == 'Connected')
                    ? Colors.greenAccent
                    : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            b['expire_subscription'] != null
                ? DateFormat(
                    'dd MMM yyyy',
                  ).format(DateTime.parse(b['expire_subscription']))
                : '-',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                onPressed: () => _showAddEditDialog(bowser: b),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _showDeleteConfirm(b['id']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddEditDialog({Map<String, dynamic>? bowser}) {
    final isEdit = bowser != null;
    final formKey = GlobalKey<FormState>();

    final controllers = {
      'device_name': TextEditingController(text: bowser?['device_name']),
      'gl': TextEditingController(text: bowser?['gl']?.toString()),
      'vehicle_type': TextEditingController(text: bowser?['vehicle_type']),
      'owner_name': TextEditingController(text: bowser?['owner_name']),
      'ph_no': TextEditingController(text: bowser?['ph_no']),
      'imei_code': TextEditingController(text: bowser?['imei_code']),
      'device_model': TextEditingController(text: bowser?['device_model']),
      'pprd_connect': TextEditingController(
        text: bowser?['pprd_connect'] ?? 'Connected',
      ),
      'expire_subscription': TextEditingController(
        text: bowser?['expire_subscription'] != null
            ? DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.parse(bowser!['expire_subscription']))
            : '',
      ),
      'remark': TextEditingController(text: bowser?['remark']),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: Text(
          isEdit ? 'EDIT BOWSER' : 'ADD NEW BOWSER',
          style: const TextStyle(color: Colors.white),
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildField(
                    controllers['device_name']!,
                    'Device Name',
                    Icons.devices,
                  ),
                  _buildField(controllers['gl']!, 'GL', Icons.pin, isNum: true),
                  _buildField(
                    controllers['vehicle_type']!,
                    'Vehicle Type',
                    Icons.local_shipping,
                  ),
                  _buildField(
                    controllers['owner_name']!,
                    'Owner Name',
                    Icons.person,
                  ),
                  _buildField(controllers['ph_no']!, 'Phone No', Icons.phone),
                  _buildField(
                    controllers['imei_code']!,
                    'IMEI Code',
                    Icons.qr_code,
                  ),
                  _buildField(
                    controllers['device_model']!,
                    'Device Model',
                    Icons.model_training,
                  ),
                  _buildDropdownField(
                    controllers['pprd_connect']!,
                    'PPRD Connect',
                    Icons.link,
                    ['Connected', 'Disconnected'],
                  ),
                  _buildDateField(
                    controllers['expire_subscription']!,
                    'Expire Subscription',
                    Icons.event_available,
                  ),
                  _buildField(
                    controllers['remark']!,
                    'Remark',
                    Icons.note,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HOColors.accent),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final data = {
                  'device_name': controllers['device_name']!.text,
                  'gl': int.tryParse(controllers['gl']!.text) ?? 0,
                  'vehicle_type': controllers['vehicle_type']!.text,
                  'owner_name': controllers['owner_name']!.text,
                  'ph_no': controllers['ph_no']!.text,
                  'imei_code': controllers['imei_code']!.text,
                  'device_model': controllers['device_model']!.text,
                  'pprd_connect': controllers['pprd_connect']!.text,
                  'expire_subscription':
                      controllers['expire_subscription']!.text.isNotEmpty
                      ? controllers['expire_subscription']!.text
                      : null,
                  'remark': controllers['remark']!.text,
                };

                try {
                  if (isEdit) {
                    await _dataService.updateBowserGps(bowser['id'], data);
                  } else {
                    await _dataService.createBowserGps(data);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Success!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              isEdit ? 'UPDATE' : 'CREATE',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNum = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: HOColors.accent, size: 18),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _buildDropdownField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    List<String> options,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: options.contains(ctrl.text) ? ctrl.text : options.first,
        dropdownColor: HOColors.surface,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: HOColors.accent, size: 18),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: options
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => ctrl.text = v ?? options.first,
      ),
    );
  }

  Widget _buildDateField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: HOColors.accent, size: 18),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: HOColors.accent,
                    onPrimary: Colors.black,
                    surface: HOColors.surface,
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            ctrl.text = DateFormat('yyyy-MM-dd').format(date);
          }
        },
      ),
    );
  }

  void _showDeleteConfirm(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text(
          'CONFIRM DELETE',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this bowser GPS record?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                await _dataService.deleteBowserGps(id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'DELETE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
