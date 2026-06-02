import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ITAssetsPage extends StatefulWidget {
  const ITAssetsPage({super.key});

  @override
  State<ITAssetsPage> createState() => _ITAssetsPageState();
}

class _ITAssetsPageState extends State<ITAssetsPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _filteredAssets = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';

  List<String> _categories = [
    'ALL',
    'Laptop',
    'Desktop',
    'Printer',
    'UPS',
    'Network Device',
    'Server',
    'License/Software',
    'Other'
  ];

  final List<String> _statuses = [
    'ALL',
    'Active',
    'In Storage',
    'Under Repair',
    'Transferred',
    'Retired'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final assetsList = await _dataService.getITAssets();
      final dbCategories = await _dataService.getITAssetCategories();
      if (mounted) {
        setState(() {
          _assets = assetsList;
          if (dbCategories.isNotEmpty) {
            _categories = ['ALL', ...dbCategories];
          }
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAssets = _assets.where((asset) {
        final matchesSearch = (asset['asset_code']?.toString().toLowerCase().contains(query) ?? false) ||
            (asset['name']?.toString().toLowerCase().contains(query) ?? false) ||
            (asset['serial_number']?.toString().toLowerCase().contains(query) ?? false) ||
            (asset['assigned_user']?.toString().toLowerCase().contains(query) ?? false);

        final matchesCategory = _selectedCategory == 'ALL' || asset['category'] == _selectedCategory;
        final matchesStatus = _selectedStatus == 'ALL' || asset['status'] == _selectedStatus;

        return matchesSearch && matchesCategory && matchesStatus;
      }).toList();
    });
  }

  void _showAddEditDialog([Map<String, dynamic>? asset]) {
    showDialog(
      context: context,
      builder: (context) => _AssetFormDialog(
        asset: asset,
        dataService: _dataService,
        onSaved: _loadData,
      ),
    );
  }

  void _showComponentsDialog(Map<String, dynamic> asset) {
    showDialog(
      context: context,
      builder: (context) => _AssetComponentsDialog(
        asset: asset,
        dataService: _dataService,
      ),
    );
  }

  void _showQRCodeDialog(Map<String, dynamic> asset) {
    final allocation = [
      if (asset['assigned_user'] != null && asset['assigned_user'].toString().isNotEmpty)
        asset['assigned_user'],
      if (asset['assigned_station'] != null && asset['assigned_station'].toString().isNotEmpty)
        asset['assigned_station'],
    ].join(' @ ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.background,
        title: const Text(
          'IT Asset QR Label',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Label Sticker Preview (50mm x 30mm)',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            // Sticker preview card (White background like physical label)
            Container(
              width: 320,
              height: 192,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MOON SUN ENERGY',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Divider(color: Colors.black26, height: 1, thickness: 1),
                        Text(
                          asset['asset_code'] ?? '',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          asset['name'] ?? '',
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Category: ${asset['category'] ?? ''}',
                          style: const TextStyle(color: Colors.black54, fontSize: 10),
                        ),
                        Text(
                          allocation.isNotEmpty ? allocation : 'Unassigned',
                          style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: QrImageView(
                      data: asset['asset_code'] ?? '',
                      version: QrVersions.auto,
                      size: 90.0,
                      gapless: false,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => _printStickerLabel(asset),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Label', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: HOColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printStickerLabel(Map<String, dynamic> asset) async {
    final assetCode = asset['asset_code'] ?? '';
    final name = asset['name'] ?? '';
    final category = asset['category'] ?? '';
    final location = [
      if (asset['assigned_user'] != null && asset['assigned_user'].toString().isNotEmpty)
        asset['assigned_user'],
      if (asset['assigned_station'] != null && asset['assigned_station'].toString().isNotEmpty)
        asset['assigned_station'],
    ].join(' @ ');

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'MOON SUN ENERGY',
                        style: pw.TextStyle(
                          fontSize: 5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Divider(thickness: 0.2, height: 1),
                      pw.Text(
                        assetCode,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        name,
                        style: const pw.TextStyle(fontSize: 6),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                      pw.Text(
                        'Category: $category',
                        style: const pw.TextStyle(fontSize: 5),
                      ),
                      pw.Text(
                        location.isNotEmpty ? location : 'Unassigned',
                        style: const pw.TextStyle(fontSize: 5),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 4),
                pw.Container(
                  width: 20 * PdfPageFormat.mm,
                  height: 20 * PdfPageFormat.mm,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: assetCode,
                    drawText: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Label-$assetCode',
    );
  }

  Future<void> _deleteAsset(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.surface,
        title: const Text('Delete Asset', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this asset?', style: TextStyle(color: Colors.white70)),
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
        await _dataService.deleteITAsset(id);
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

  void _triggerCsvDownload(String csvData, String fileName) {
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  void _downloadTemplate() {
    final headers = [
      'Asset Code',
      'Name',
      'Category',
      'Model',
      'Serial Number',
      'Purchase Date (YYYY-MM-DD)',
      'Purchase Cost',
      'Status',
      'Assigned Employee',
      'Assigned Station',
      'Assigned Department',
      'Description'
    ];
    final exampleRow = [
      'AST-999',
      'Dell Latitude 5420',
      'Laptop',
      'Latitude 5420',
      'DELL-SN-123',
      '2026-05-27',
      '1500000',
      'Active',
      'U Aung',
      'Head Office',
      'Finance',
      'Standard staff laptop'
    ];
    final csvString = csv.encode([headers, exampleRow]);
    _triggerCsvDownload(csvString, 'IT_Assets_Import_Template.csv');
  }

  void _exportAssetsCSV() {
    final headers = [
      'Asset Code',
      'Name',
      'Category',
      'Model',
      'Serial Number',
      'Purchase Date (YYYY-MM-DD)',
      'Purchase Cost',
      'Status',
      'Assigned Employee',
      'Assigned Station',
      'Assigned Department',
      'Description'
    ];

    final List<List<dynamic>> rows = [headers];

    for (var asset in _filteredAssets) {
      rows.add([
        asset['asset_code'] ?? '',
        asset['name'] ?? '',
        asset['category'] ?? '',
        asset['model'] ?? '',
        asset['serial_number'] ?? '',
        asset['purchase_date'] ?? '',
        asset['purchase_cost'] ?? 0,
        asset['status'] ?? '',
        asset['assigned_user'] ?? '',
        asset['assigned_station'] ?? '',
        asset['assigned_department'] ?? '',
        asset['description'] ?? '',
      ]);
    }

    final csvString = csv.encode(rows);
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    _triggerCsvDownload(csvString, 'IT_Assets_Export_$dateStr.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assets exported successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _importAssetsCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Could not read file data.');
      }

      String csvString = utf8.decode(bytes);
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      List<List<dynamic>> rows = csv.decode(csvString);
      if (rows.isEmpty) {
        throw Exception('The selected file is empty.');
      }

      final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();

      int idxCode = headers.indexOf('asset code');
      int idxName = headers.indexOf('name');
      int idxCategory = headers.indexOf('category');
      int idxModel = headers.indexOf('model');
      int idxSerial = headers.indexOf('serial number');
      int idxDate = headers.indexOf('purchase date (yyyy-mm-dd)');
      if (idxDate == -1) idxDate = headers.indexOf('purchase date');
      int idxCost = headers.indexOf('purchase cost');
      int idxStatus = headers.indexOf('status');
      int idxUser = headers.indexOf('assigned employee');
      if (idxUser == -1) idxUser = headers.indexOf('assigned user');
      int idxStation = headers.indexOf('assigned station');
      int idxDept = headers.indexOf('assigned department');
      int idxDesc = headers.indexOf('description');

      if (idxCode == -1 || idxName == -1) {
        throw Exception('Invalid CSV template. "Asset Code" and "Name" columns are required.');
      }

      List<Map<String, dynamic>> importedAssets = [];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= idxCode || row.length <= idxName) continue;

        final code = row[idxCode]?.toString().trim() ?? '';
        final name = row[idxName]?.toString().trim() ?? '';

        if (code.isEmpty || name.isEmpty) continue;

        final categoryRaw = idxCategory != -1 && row.length > idxCategory ? row[idxCategory]?.toString().trim() ?? 'Other' : 'Other';
        // Validate category by finding match in standard categories or defaulting
        final category = _categories.contains(categoryRaw) ? categoryRaw : 'Other';

        final model = idxModel != -1 && row.length > idxModel ? row[idxModel]?.toString().trim() ?? '' : '';
        final serial = idxSerial != -1 && row.length > idxSerial ? row[idxSerial]?.toString().trim() ?? '' : '';

        String? purchaseDateStr = idxDate != -1 && row.length > idxDate ? row[idxDate]?.toString().trim() : null;
        String? purchaseDate;
        if (purchaseDateStr != null && purchaseDateStr.isNotEmpty) {
          try {
            DateTime.parse(purchaseDateStr);
            purchaseDate = purchaseDateStr;
          } catch (_) {}
        }

        final costStr = idxCost != -1 && row.length > idxCost ? row[idxCost]?.toString().trim() ?? '0' : '0';
        final cost = double.tryParse(costStr) ?? 0.0;

        final statusRaw = idxStatus != -1 && row.length > idxStatus ? row[idxStatus]?.toString().trim() ?? 'Active' : 'Active';
        final status = _statuses.contains(statusRaw) ? statusRaw : 'Active';

        final user = idxUser != -1 && row.length > idxUser ? row[idxUser]?.toString().trim() ?? '' : '';
        final station = idxStation != -1 && row.length > idxStation ? row[idxStation]?.toString().trim() ?? '' : '';
        final dept = idxDept != -1 && row.length > idxDept ? row[idxDept]?.toString().trim() ?? '' : '';
        final desc = idxDesc != -1 && row.length > idxDesc ? row[idxDesc]?.toString().trim() ?? '' : '';

        importedAssets.add({
          'asset_code': code,
          'name': name,
          'category': category,
          'model': model,
          'serial_number': serial,
          'purchase_date': purchaseDate,
          'purchase_cost': cost,
          'status': status,
          'assigned_user': user,
          'assigned_station': station,
          'assigned_department': dept,
          'description': desc,
        });
      }

      if (importedAssets.isEmpty) {
        throw Exception('No valid asset rows found in the CSV.');
      }

      setState(() => _isLoading = true);
      await _dataService.upsertITAssets(importedAssets);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${importedAssets.length} assets!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'In Storage':
        return Colors.blue;
      case 'Under Repair':
        return Colors.orange;
      case 'Transferred':
        return Colors.purple;
      case 'Retired':
        return Colors.red;
      default:
        return Colors.grey;
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
                      'IT Asset Inventory',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage all office hardware, licenses, and equipment allocations.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _downloadTemplate,
                      icon: const Icon(Icons.description_outlined, size: 16, color: HOColors.accent),
                      label: const Text('Template', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _importAssetsCSV,
                      icon: const Icon(Icons.upload_rounded, size: 16, color: Colors.greenAccent),
                      label: const Text('Import CSV', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _exportAssetsCSV,
                      icon: const Icon(Icons.download_rounded, size: 16, color: Colors.blueAccent),
                      label: const Text('Export CSV', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Asset'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HOColors.accent,
                        foregroundColor: HOColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by Code, Name, Serial No, or User...',
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: HOColors.surface,
                      labelText: 'Category',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedCategory = v ?? 'ALL');
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: HOColors.surface,
                      labelText: 'Status',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedStatus = v ?? 'ALL');
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAssets.isEmpty
                      ? const Center(
                          child: Text(
                            'No assets found matching filters.',
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
                                DataColumn(label: Text('Code')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Serial No')),
                                DataColumn(label: Text('Allocation')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _filteredAssets.map((asset) {
                                final allocation = [
                                  if (asset['assigned_user'] != null && asset['assigned_user'].toString().isNotEmpty)
                                    asset['assigned_user'],
                                  if (asset['assigned_station'] != null && asset['assigned_station'].toString().isNotEmpty)
                                    asset['assigned_station'],
                                ].join(' @ ');

                                return DataRow(
                                  cells: [
                                    DataCell(Text(asset['asset_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(asset['name'] ?? '')),
                                    DataCell(Text(asset['category'] ?? '')),
                                    DataCell(Text(asset['serial_number'] ?? '-')),
                                    DataCell(Text(allocation.isNotEmpty ? allocation : 'Unassigned')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(asset['status'] ?? '').withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getStatusColor(asset['status'] ?? '').withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          asset['status'] ?? 'Active',
                                          style: TextStyle(
                                            color: _getStatusColor(asset['status'] ?? ''),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.qr_code, color: HOColors.accent, size: 20),
                                            tooltip: 'Generate/Print QR Label',
                                            onPressed: () => _showQRCodeDialog(asset),
                                          ),
                                          if (asset['category'] == 'Laptop' ||
                                              asset['category'] == 'Desktop' ||
                                              asset['category'] == 'Server')
                                            IconButton(
                                              icon: const Icon(Icons.memory_rounded, color: Colors.greenAccent, size: 20),
                                              tooltip: 'Manage Components',
                                              onPressed: () => _showComponentsDialog(asset),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                            tooltip: 'Edit Asset Details',
                                            onPressed: () => _showAddEditDialog(asset),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteAsset(asset['id']),
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
          ],
        ),
      ),
    );
  }
}

class _AssetFormDialog extends StatefulWidget {
  final Map<String, dynamic>? asset;
  final HODataService dataService;
  final VoidCallback onSaved;

  const _AssetFormDialog({
    this.asset,
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _costController;
  late TextEditingController _userController;
  late TextEditingController _descController;
  late TextEditingController _cpuController;
  late TextEditingController _ramController;
  late TextEditingController _storageController;
  late TextEditingController _motherboardController;

  String _category = 'Laptop';
  String _status = 'Active';
  bool _isSaving = false;

  bool _isLoadingStations = true;
  List<String> _stationOptions = ['Unassigned', 'Head Office'];
  String _selectedStationOption = 'Unassigned';

  bool _isLoadingCompanies = true;
  List<String> _companyOptions = ['Trading', 'Construction'];
  String _selectedHoDivision = 'Trading';

  bool _isLoadingDepartments = true;
  List<String> _departmentOptions = [
    'Unassigned',
    'IT',
    'Finance',
    'HR',
    'Operations',
    'Marketing',
    'Logistics',
    'Procurement',
    'Administration',
    'Security',
    'Other'
  ];
  String _selectedDepartmentOption = 'Unassigned';

  List<String> _categories = [
    'Laptop',
    'Desktop',
    'Printer',
    'UPS',
    'Network Device',
    'Server',
    'License/Software',
    'Other'
  ];

  final List<String> _statuses = [
    'Active',
    'In Storage',
    'Under Repair',
    'Transferred',
    'Retired'
  ];

  Future<void> _loadCategories() async {
    try {
      final cats = await widget.dataService.getITAssetCategories();
      if (mounted && cats.isNotEmpty) {
        setState(() {
          _categories = cats;
          if (!_categories.contains(_category)) {
            _categories.add(_category);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final data = widget.asset ?? {};
    _codeController = TextEditingController(text: data['asset_code'] ?? '');
    _nameController = TextEditingController(text: data['name'] ?? '');
    _modelController = TextEditingController(text: data['model'] ?? '');
    _serialController = TextEditingController(text: data['serial_number'] ?? '');
    _costController = TextEditingController(text: data['purchase_cost']?.toString() ?? '0');
    _userController = TextEditingController(text: data['assigned_user'] ?? '');
    _descController = TextEditingController(text: data['description'] ?? '');
    _cpuController = TextEditingController();
    _ramController = TextEditingController();
    _storageController = TextEditingController();
    _motherboardController = TextEditingController();

    if (data['category'] != null) _category = data['category'];
    if (data['status'] != null) _status = data['status'];

    // Setup initial station value
    final initialStation = data['assigned_station']?.toString() ?? '';
    if (initialStation.isEmpty) {
      _selectedStationOption = 'Unassigned';
    } else {
      _selectedStationOption = initialStation;
      if (!_stationOptions.contains(initialStation)) {
        _stationOptions.add(initialStation);
      }
    }

    // Setup initial department and division values
    final initialDept = data['assigned_department']?.toString() ?? '';
    if (initialStation == 'Head Office') {
      if (initialDept.startsWith('Trading - ')) {
        _selectedHoDivision = 'Trading';
        final dept = initialDept.substring('Trading - '.length);
        _selectedDepartmentOption = dept.isEmpty ? 'Unassigned' : dept;
        if (dept.isNotEmpty && !_departmentOptions.contains(dept)) {
          _departmentOptions.add(dept);
        }
      } else if (initialDept.startsWith('Construction - ')) {
        _selectedHoDivision = 'Construction';
        final dept = initialDept.substring('Construction - '.length);
        _selectedDepartmentOption = dept.isEmpty ? 'Unassigned' : dept;
        if (dept.isNotEmpty && !_departmentOptions.contains(dept)) {
          _departmentOptions.add(dept);
        }
      } else {
        _selectedHoDivision = 'Trading'; // default
        _selectedDepartmentOption = initialDept.isEmpty ? 'Unassigned' : initialDept;
        if (initialDept.isNotEmpty && !_departmentOptions.contains(initialDept)) {
          _departmentOptions.add(initialDept);
        }
      }
    } else {
      if (initialDept.isEmpty) {
        _selectedDepartmentOption = 'Unassigned';
      } else {
        _selectedDepartmentOption = initialDept;
        if (!_departmentOptions.contains(initialDept)) {
          _departmentOptions.add(initialDept);
        }
      }
    }

    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoadingStations = true;
      _isLoadingCompanies = true;
      _isLoadingDepartments = true;
    });

    // 1. Load Stations
    try {
      final stations = await widget.dataService.getStationsForDropdown();
      final stationNames = stations
          .map((s) => s['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _stationOptions = ['Unassigned', 'Head Office'];
          for (final name in stationNames) {
            if (!_stationOptions.contains(name)) {
              _stationOptions.add(name);
            }
          }
          if (!_stationOptions.contains(_selectedStationOption)) {
            _stationOptions.add(_selectedStationOption);
          }
          _isLoadingStations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStations = false);
      }
    }

    // 2. Load Companies (HO Divisions)
    try {
      final companies = await widget.dataService.getITCompanies();
      if (mounted) {
        setState(() {
          if (companies.isNotEmpty) {
            _companyOptions = List<String>.from(companies);
          }
          if (!_companyOptions.contains(_selectedHoDivision)) {
            _companyOptions.add(_selectedHoDivision);
          }
          _isLoadingCompanies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCompanies = false);
      }
    }

    // 3. Load Departments
    try {
      final departments = await widget.dataService.getITDepartments();
      if (mounted) {
        setState(() {
          _departmentOptions = ['Unassigned'];
          for (final name in departments) {
            if (!_departmentOptions.contains(name)) {
              _departmentOptions.add(name);
            }
          }
          if (!_departmentOptions.contains(_selectedDepartmentOption)) {
            _departmentOptions.add(_selectedDepartmentOption);
          }
          _isLoadingDepartments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDepartments = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _costController.dispose();
    _userController.dispose();
    _descController.dispose();
    _cpuController.dispose();
    _ramController.dispose();
    _storageController.dispose();
    _motherboardController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String finalDept = '';
    if (_selectedDepartmentOption != 'Unassigned') {
      if (_selectedStationOption == 'Head Office') {
        finalDept = '$_selectedHoDivision - $_selectedDepartmentOption';
      } else {
        finalDept = _selectedDepartmentOption;
      }
    }

    final Map<String, dynamic> data = {
      if (widget.asset != null) 'id': widget.asset!['id'],
      'asset_code': _codeController.text,
      'name': _nameController.text,
      'category': _category,
      'model': _modelController.text,
      'serial_number': _serialController.text,
      'purchase_cost': double.tryParse(_costController.text) ?? 0.0,
      'status': _status,
      'assigned_user': _userController.text,
      'assigned_station': _selectedStationOption == 'Unassigned' ? '' : _selectedStationOption,
      'assigned_department': finalDept,
      'description': _descController.text,
    };

    try {
      if (widget.asset == null) {
        final newAsset = await widget.dataService.createITAsset(data);
        final newAssetId = newAsset['id'];

        final List<Map<String, dynamic>> initialComponents = [];
        if (_category == 'Laptop' || _category == 'Desktop' || _category == 'Server') {
          if (_cpuController.text.trim().isNotEmpty) {
            initialComponents.add({
              'asset_id': newAssetId,
              'component_type': 'CPU',
              'model': _cpuController.text.trim(),
              'spec': 'Initial Spec',
              'status': 'Active',
            });
          }
          if (_ramController.text.trim().isNotEmpty) {
            initialComponents.add({
              'asset_id': newAssetId,
              'component_type': 'RAM',
              'model': _ramController.text.trim(),
              'spec': 'Initial Spec',
              'status': 'Active',
            });
          }
          if (_storageController.text.trim().isNotEmpty) {
            initialComponents.add({
              'asset_id': newAssetId,
              'component_type': 'Storage',
              'model': _storageController.text.trim(),
              'spec': 'Initial Spec',
              'status': 'Active',
            });
          }
          if (_motherboardController.text.trim().isNotEmpty) {
            initialComponents.add({
              'asset_id': newAssetId,
              'component_type': 'Motherboard',
              'model': _motherboardController.text.trim(),
              'spec': 'Initial Spec',
              'status': 'Active',
            });
          }
        }

        if (initialComponents.isNotEmpty) {
          await widget.dataService.upsertAssetComponents(initialComponents);
        }
      } else {
        await widget.dataService.upsertITAsset(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Text(
        widget.asset == null ? 'Add IT Asset' : 'Edit IT Asset',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildField(_codeController, 'Asset Code (e.g. AST-01)', required: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        dropdownColor: HOColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Category'),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? 'Laptop'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField(_nameController, 'Asset Name (e.g. Dell Latitude 5420)', required: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(_modelController, 'Model'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField(_serialController, 'Serial Number'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(_costController, 'Purchase Cost (MMK)', isNumber: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        dropdownColor: HOColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Status'),
                        items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _status = v ?? 'Active'),
                      ),
                    ),
                  ],
                ),
                if (widget.asset == null && (_category == 'Laptop' || _category == 'Desktop' || _category == 'Server')) ...[
                  const SizedBox(height: 24),
                  const Text('Initial Components Specifications', style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildField(_cpuController, 'CPU (e.g. Intel Core i5-11400)')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField(_ramController, 'RAM (e.g. Kingston Fury 8GB DDR4)')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildField(_storageController, 'Storage (e.g. Samsung 980 512GB SSD)')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField(_motherboardController, 'Motherboard (e.g. ASUS Prime B560M)')),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Text('Allocation Details', style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildField(_userController, 'Assigned Employee Name')),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStationOption,
                        dropdownColor: HOColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                          'Assigned Station/Branch',
                          suffixIcon: _isLoadingStations
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: HOColors.accent),
                                  ),
                                )
                              : null,
                        ),
                        items: _stationOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: _isLoadingStations ? null : (v) => setState(() => _selectedStationOption = v ?? 'Unassigned'),
                      ),
                    ),
                  ],
                ),
                if (_selectedStationOption == 'Head Office') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedHoDivision,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      'Head Office Division',
                      suffixIcon: _isLoadingCompanies
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2, color: HOColors.accent),
                              ),
                            )
                          : null,
                    ),
                    items: _companyOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: _isLoadingCompanies ? null : (v) => setState(() => _selectedHoDivision = v ?? 'Trading'),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedDepartmentOption,
                  dropdownColor: HOColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Assigned Department',
                    suffixIcon: _isLoadingDepartments
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: HOColors.accent),
                            ),
                          )
                        : null,
                  ),
                  items: _departmentOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: _isLoadingDepartments ? null : (v) => setState(() => _selectedDepartmentOption = v ?? 'Unassigned'),
                ),
                const SizedBox(height: 16),
                _buildField(_descController, 'Description / Remarks', maxLines: 3),
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
              : const Text('Save Asset', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
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

class _AssetComponentsDialog extends StatefulWidget {
  final Map<String, dynamic> asset;
  final HODataService dataService;

  const _AssetComponentsDialog({required this.asset, required this.dataService});

  @override
  State<_AssetComponentsDialog> createState() => _AssetComponentsDialogState();
}

class _AssetComponentsDialogState extends State<_AssetComponentsDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _components = [];

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.dataService.getAssetComponents(widget.asset['id']);
      if (mounted) {
        setState(() {
          _components = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading components: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddEditComponentDialog([Map<String, dynamic>? component]) {
    showDialog(
      context: context,
      builder: (context) => _ComponentFormDialog(
        assetId: widget.asset['id'],
        component: component,
        dataService: widget.dataService,
        onSaved: _loadComponents,
      ),
    );
  }

  void _showSwapDialog(Map<String, dynamic> oldComponent) {
    showDialog(
      context: context,
      builder: (context) => _SwapComponentDialog(
        assetId: widget.asset['id'],
        oldComponent: oldComponent,
        dataService: widget.dataService,
        onSaved: _loadComponents,
      ),
    );
  }

  Future<void> _deleteComponent(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HOColors.background,
        title: const Text('Delete Component', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this component?', style: TextStyle(color: Colors.white70)),
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
        await widget.dataService.deleteAssetComponent(id);
        _loadComponents();
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
    final activeComponents = _components.where((c) => c['status'] == 'Active').toList();
    final replacedComponents = _components.where((c) => c['status'] == 'Replaced').toList();

    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Components',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.asset['asset_code']} - ${widget.asset['name']}',
                  style: const TextStyle(color: HOColors.accent, fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddEditComponentDialog(),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add Component', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: HOColors.accent,
              foregroundColor: HOColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 500,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: HOColors.accent,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: HOColors.accent,
                      tabs: [
                        Tab(text: 'Active Components'),
                        Tab(text: 'Replacement History'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Active Components Tab
                          activeComponents.isEmpty
                              ? _buildEmptyView('No active components found. Add components to start tracking details.')
                              : ListView.separated(
                                  itemCount: activeComponents.length,
                                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final c = activeComponents[index];
                                    final date = c['installed_at'] != null
                                        ? DateFormat('dd MMM yyyy').format(DateTime.parse(c['installed_at']).toLocal())
                                        : '-';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: HOColors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.memory_rounded, color: HOColors.accent),
                                      ),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: HOColors.accent.withOpacity(0.1),
                                              border: Border.all(color: HOColors.accent.withOpacity(0.3)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c['component_type'] ?? '',
                                              style: const TextStyle(color: HOColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c['model'] ?? '',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Spec: ${c['spec'] ?? '-'}  |  S/N: ${c['serial_number'] ?? '-'}  |  Installed: $date',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.amber, size: 20),
                                            tooltip: 'Swap/Replace Component',
                                            onPressed: () => _showSwapDialog(c),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                            tooltip: 'Edit Component Specs',
                                            onPressed: () => _showAddEditComponentDialog(c),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                            tooltip: 'Delete Component',
                                            onPressed: () => _deleteComponent(c['id']),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                          // Replacement History Tab
                          replacedComponents.isEmpty
                              ? _buildEmptyView('No replacement history found.')
                              : ListView.separated(
                                  itemCount: replacedComponents.length,
                                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final c = replacedComponents[index];
                                    final removedDate = c['replaced_at'] != null
                                        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(c['replaced_at']).toLocal())
                                        : '-';
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.history_rounded, color: Colors.redAccent),
                                      ),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withOpacity(0.1),
                                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              c['component_type'] ?? '',
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              c['model'] ?? '',
                                              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.lineThrough),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Spec: ${c['spec'] ?? '-'}  |  S/N: ${c['serial_number'] ?? '-'}  |  Replaced on: $removedDate',
                                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }

  Widget _buildEmptyView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.memory_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SwapComponentDialog extends StatefulWidget {
  final String assetId;
  final Map<String, dynamic> oldComponent;
  final HODataService dataService;
  final VoidCallback onSaved;

  const _SwapComponentDialog({
    required this.assetId,
    required this.oldComponent,
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_SwapComponentDialog> createState() => _SwapComponentDialogState();
}

class _SwapComponentDialogState extends State<_SwapComponentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _specController = TextEditingController();
  final _serialController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _modelController.dispose();
    _specController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final newComponentData = {
      'asset_id': widget.assetId,
      'component_type': widget.oldComponent['component_type'],
      'model': _modelController.text,
      'spec': _specController.text,
      'serial_number': _serialController.text,
      'status': 'Active',
      'installed_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await widget.dataService.swapAssetComponent(widget.oldComponent['id'], newComponentData);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error swapping component: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Text(
        'Swap ${widget.oldComponent['component_type']}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Replacing old component:',
                style: TextStyle(color: HOColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.oldComponent['model'] ?? ''} ${widget.oldComponent['spec'] ?? ''} (S/N: ${widget.oldComponent['serial_number'] ?? ''})',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
              ),
              const Divider(color: Colors.white10, height: 24),
              const Text(
                'New Component Details:',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildField(_modelController, 'Model (e.g. Kingston Fury DDR4)', required: true),
              const SizedBox(height: 12),
              _buildField(_specController, 'Specification (e.g. 16GB DDR4 3200MHz)', required: true),
              const SizedBox(height: 12),
              _buildField(_serialController, 'Serial Number'),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Swap Component', style: TextStyle(color: Colors.white)),
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

  Widget _buildField(TextEditingController controller, String label, {bool required = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return 'Required';
        return null;
      },
    );
  }
}

class _ComponentFormDialog extends StatefulWidget {
  final String assetId;
  final Map<String, dynamic>? component;
  final HODataService dataService;
  final VoidCallback onSaved;

  const _ComponentFormDialog({
    required this.assetId,
    this.component,
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_ComponentFormDialog> createState() => _ComponentFormDialogState();
}

class _ComponentFormDialogState extends State<_ComponentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _modelController;
  late TextEditingController _specController;
  late TextEditingController _serialController;
  String _componentType = 'RAM';
  bool _isSaving = false;

  final List<String> _types = [
    'RAM',
    'Storage',
    'CPU',
    'Motherboard',
    'GPU',
    'Power Supply',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.component ?? {};
    _modelController = TextEditingController(text: c['model'] ?? '');
    _specController = TextEditingController(text: c['spec'] ?? '');
    _serialController = TextEditingController(text: c['serial_number'] ?? '');
    if (c['component_type'] != null) _componentType = c['component_type'];
  }

  @override
  void dispose() {
    _modelController.dispose();
    _specController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      if (widget.component != null) 'id': widget.component!['id'],
      'asset_id': widget.assetId,
      'component_type': _componentType,
      'model': _modelController.text,
      'spec': _specController.text,
      'serial_number': _serialController.text,
      'status': widget.component != null ? widget.component!['status'] : 'Active',
      if (widget.component == null) 'installed_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await widget.dataService.upsertAssetComponent(data);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving component: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Text(
        widget.component == null ? 'Add Component' : 'Edit Component',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _componentType,
                dropdownColor: HOColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Component Type'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _componentType = v ?? 'RAM'),
              ),
              const SizedBox(height: 12),
              _buildField(_modelController, 'Model (e.g. Crucial DDR5)', required: true),
              const SizedBox(height: 12),
              _buildField(_specController, 'Specification (e.g. 8GB DDR5 4800MHz)', required: true),
              const SizedBox(height: 12),
              _buildField(_serialController, 'Serial Number'),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Component', style: TextStyle(color: Colors.white)),
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

  Widget _buildField(TextEditingController controller, String label, {bool required = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      validator: (v) {
        if (required && (v == null || v.isEmpty)) return 'Required';
        return null;
      },
    );
  }
}
