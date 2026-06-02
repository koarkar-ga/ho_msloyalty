import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AssetRequestPage extends StatefulWidget {
  const AssetRequestPage({super.key});

  @override
  State<AssetRequestPage> createState() => _AssetRequestPageState();
}

class _AssetRequestPageState extends State<AssetRequestPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _filteredRequests = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';

  final List<String> _statuses = [
    'ALL',
    'Pending Dept Head',
    'Pending Admin',
    'Pending IT Manager',
    'Pending GM',
    'Pending MD Office',
    'Pending MD/Director',
    'Approved',
    'Rejected',
    'Fulfilled'
  ];
  final List<String> _priorities = ['ALL', 'Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dataService.getAssetRequests();
      if (mounted) {
        setState(() {
          _requests = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredRequests = _requests.where((r) {
        final matchesSearch = (r['request_no']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['requester_name']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['asset_type']?.toString().toLowerCase().contains(query) ?? false) ||
            (r['reason']?.toString().toLowerCase().contains(query) ?? false);

        final matchesStatus = _selectedStatus == 'ALL' || r['status'] == _selectedStatus;
        final matchesPriority = _selectedPriority == 'ALL' || r['priority'] == _selectedPriority;

        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  void _showReviewDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => _ReviewRequestDialog(
        request: request,
        dataService: _dataService,
        onSaved: _loadData,
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.startsWith('Pending')) {
      return Colors.amber;
    }
    switch (status) {
      case 'Approved':
        return Colors.blue;
      case 'Rejected':
        return Colors.redAccent;
      case 'Fulfilled':
        return Colors.green;
      default:
        return Colors.white54;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.blue;
      case 'Low':
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asset Procurement Requests',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review and approve procurement requests for new assets submitted by employees or stations.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
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
                      hintText: 'Search by Request No, Requester, Asset Type, Reason...',
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
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    dropdownColor: HOColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: HOColors.surface,
                      labelText: 'Priority',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedPriority = v ?? 'ALL');
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
                  : _filteredRequests.isEmpty
                      ? const Center(
                          child: Text(
                            'No procurement requests found.',
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
                                DataColumn(label: Text('Request No')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Requester')),
                                DataColumn(label: Text('Asset Type')),
                                DataColumn(label: Text('Priority')),
                                DataColumn(label: Text('Reason')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Approver')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _filteredRequests.map((r) {
                                final date = r['created_at'] != null
                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())
                                    : '-';

                                return DataRow(
                                  cells: [
                                    DataCell(Text(r['request_no'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(date)),
                                    DataCell(Text("${r['requester_name'] ?? ''} (${r['department'] ?? ''})")),
                                    DataCell(Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(r['asset_type'] ?? ''),
                                        if (r['it_assets'] != null)
                                          Text(
                                            "${r['it_assets']['asset_code']} - ${r['it_assets']['name']}",
                                            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    )),
                                    DataCell(
                                      Text(
                                        r['priority'] ?? 'Medium',
                                        style: TextStyle(color: _getPriorityColor(r['priority'] ?? ''), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Tooltip(
                                        message: r['reason'] ?? '',
                                        child: SizedBox(
                                          width: 150,
                                          child: Text(
                                            r['reason'] ?? '',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(r['status'] ?? '').withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: _getStatusColor(r['status'] ?? '').withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          r['status'] ?? 'Pending',
                                          style: TextStyle(
                                            color: _getStatusColor(r['status'] ?? ''),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(r['approved_by'] ?? '-')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.gavel, color: Colors.amber, size: 20),
                                        tooltip: 'Review Request',
                                        onPressed: () => _showReviewDialog(r),
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

class _ReviewRequestDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  final HODataService dataService;
  final VoidCallback onSaved;

  const _ReviewRequestDialog({
    required this.request,
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_ReviewRequestDialog> createState() => _ReviewRequestDialogState();
}

class _ReviewRequestDialogState extends State<_ReviewRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _remarksController;
  late TextEditingController _approverNameController;
  bool _isSaving = false;

  // IT Asset controllers
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _modelController;
  late TextEditingController _serialController;
  late TextEditingController _costController;
  late TextEditingController _userController;
  late TextEditingController _stationController;
  late TextEditingController _deptController;
  late TextEditingController _descController;
  String _category = 'Laptop';
  bool _registerAsset = false;

  final List<String> _categories = [
    'Laptop',
    'Desktop',
    'Printer',
    'UPS',
    'Network Device',
    'Server',
    'License/Software',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();

    final currentUser = widget.dataService.supabase.auth.currentUser;
    final defaultApprover = currentUser?.userMetadata?['fullname'] ?? 'HO Admin';
    _approverNameController = TextEditingController(text: defaultApprover);

    // Auto-generate suggested code
    final now = DateTime.now();
    final dateStr = DateFormat('yyMMddHHmmss').format(now);
    _codeController = TextEditingController(text: 'AST-$dateStr');

    _nameController = TextEditingController();
    _modelController = TextEditingController();
    _serialController = TextEditingController();
    _costController = TextEditingController(text: '0');
    _userController = TextEditingController(text: widget.request['requester_name'] ?? '');
    _stationController = TextEditingController(text: widget.request['station_id'] ?? '');
    _deptController = TextEditingController(text: widget.request['department'] ?? '');
    _descController = TextEditingController(text: widget.request['reason'] ?? '');

    if (widget.request['asset_type'] != null && _categories.contains(widget.request['asset_type'])) {
      _category = widget.request['asset_type'];
    }
  }

  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'Pending Dept Head':
        return 'Pending Admin';
      case 'Pending Admin':
        return 'Pending IT Manager';
      case 'Pending IT Manager':
        return 'Pending GM';
      case 'Pending GM':
        return 'Pending MD Office';
      case 'Pending MD Office':
        return 'Pending MD/Director';
      case 'Pending MD/Director':
        return 'Approved';
      default:
        return currentStatus;
    }
  }

  String _getHistStageName(String status) {
    switch (status) {
      case 'Pending Dept Head':
        return 'Dept Head';
      case 'Pending Admin':
        return 'Admin';
      case 'Pending IT Manager':
        return 'IT Manager';
      case 'Pending GM':
        return 'GM';
      case 'Pending MD Office':
        return 'MD Office';
      case 'Pending MD/Director':
        return 'MD/Director';
      default:
        return status;
    }
  }

  Future<void> _processStageDecision({required bool approve}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final currentStatus = widget.request['status'] ?? 'Pending Dept Head';
      final nextStatus = approve ? _getNextStatus(currentStatus) : 'Rejected';

      // Build the new history step
      final newStep = {
        'stage': _getHistStageName(currentStatus),
        'approved_by': _approverNameController.text.trim(),
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'status': approve ? 'Approved' : 'Rejected',
        'remarks': _remarksController.text.trim(),
      };

      // Load existing history and append the new step
      final List<dynamic> currentHistory = List.from(widget.request['approval_history'] ?? []);
      currentHistory.add(newStep);

      await widget.dataService.updateAssetRequestStatus(
        widget.request['id'],
        nextStatus,
        _remarksController.text.trim(),
        approvalHistory: currentHistory,
      );

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

  Future<void> _fulfillRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? assetId;
      final linkedAsset = widget.request['it_assets'];

      if (linkedAsset == null && _registerAsset) {
        final Map<String, dynamic> assetData = {
          'asset_code': _codeController.text.trim(),
          'name': _nameController.text.trim(),
          'category': _category,
          'model': _modelController.text.trim(),
          'serial_number': _serialController.text.trim(),
          'purchase_cost': double.tryParse(_costController.text.trim()) ?? 0.0,
          'status': 'Active',
          'assigned_user': _userController.text.trim(),
          'assigned_station': _stationController.text.trim(),
          'assigned_department': _deptController.text.trim(),
          'description': _descController.text.trim(),
        };
        final newAsset = await widget.dataService.createITAsset(assetData);
        assetId = newAsset['id']?.toString();
      }

      await widget.dataService.updateAssetRequestStatus(
        widget.request['id'],
        'Fulfilled',
        _remarksController.text.trim(),
        assetId: assetId,
      );

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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url'), backgroundColor: Colors.red),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
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
      style: const TextStyle(color: Colors.white, fontSize: 13),
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

  Widget _buildOfficeNoteAttachment(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.15)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No Office Note attached!',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.attachment_rounded, color: HOColors.accent, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed Office Note',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'PDF/Image Attachment',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _launchUrl(url),
            icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
            label: const Text('Open Note', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: HOColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> history, String currentStatus) {
    final stages = [
      {'key': 'Pending Dept Head', 'label': 'Dept Head / Manager'},
      {'key': 'Pending Admin', 'label': 'Admin Approval'},
      {'key': 'Pending IT Manager', 'label': 'IT Manager Approval'},
      {'key': 'Pending GM', 'label': 'GM Approval'},
      {'key': 'Pending MD Office', 'label': 'MD Office Approval'},
      {'key': 'Pending MD/Director', 'label': 'MD / Director Approval'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Approval Progress Timeline',
          style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...List.generate(stages.length, (index) {
          final stageKey = stages[index]['key']!;
          final label = stages[index]['label']!;
          
          final targetHistName = _getHistStageName(stageKey);
          final historyEntry = history.firstWhere(
            (h) => h is Map && (h['stage'] == targetHistName || h['stage'] == stageKey),
            orElse: () => null,
          );

          final isCompleted = historyEntry != null && historyEntry['status'] == 'Approved';
          final isRejected = historyEntry != null && historyEntry['status'] == 'Rejected';
          final isActive = currentStatus == stageKey;

          Color dotColor = Colors.white24;
          IconData icon = Icons.radio_button_off;
          
          if (isCompleted) {
            dotColor = Colors.green;
            icon = Icons.check_circle_rounded;
          } else if (isRejected) {
            dotColor = Colors.redAccent;
            icon = Icons.cancel_rounded;
          } else if (isActive) {
            dotColor = Colors.amber;
            icon = Icons.play_circle_filled_rounded;
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Icon(icon, color: dotColor, size: 20),
                    if (index < stages.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted ? Colors.green : Colors.white10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isActive ? Colors.amber : (isCompleted ? Colors.white : Colors.white30),
                            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        if (historyEntry != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'By: ${historyEntry['approved_by'] ?? '-'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'At: ${historyEntry['approved_at'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(historyEntry['approved_at']).toLocal()) : '-'}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          if (historyEntry['remarks'] != null && historyEntry['remarks'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Text(
                                'Remarks: ${historyEntry['remarks']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ] else if (isActive) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Awaiting decision...',
                            style: TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Pending previous steps',
                            style: TextStyle(color: Colors.white24, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkedAsset = widget.request['it_assets'];
    final currentStatus = widget.request['status'] ?? 'Pending Dept Head';
    final history = widget.request['approval_history'] as List<dynamic>? ?? [];
    final isPending = currentStatus.startsWith('Pending');
    final isApproved = currentStatus == 'Approved';

    return AlertDialog(
      backgroundColor: HOColors.background,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Review Procurement Request: ${widget.request['request_no']}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (currentStatus.startsWith('Pending') ? Colors.amber : (currentStatus == 'Approved' ? Colors.blue : (currentStatus == 'Rejected' ? Colors.redAccent : Colors.green))).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (currentStatus.startsWith('Pending') ? Colors.amber : (currentStatus == 'Approved' ? Colors.blue : (currentStatus == 'Rejected' ? Colors.redAccent : Colors.green))).withOpacity(0.5)
                  ),
                ),
                child: Text(
                  currentStatus,
                  style: TextStyle(
                    color: (currentStatus.startsWith('Pending') ? Colors.amber : (currentStatus == 'Approved' ? Colors.blue : (currentStatus == 'Rejected' ? Colors.redAccent : Colors.green))),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white10),
        ],
      ),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Request Details & Action Panel
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Requester Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, color: HOColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Requester: ${widget.request['requester_name']} (${widget.request['department'] ?? ''})',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.devices_rounded, color: HOColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Asset Type: ${widget.request['asset_type']}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: HOColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Reason: ${widget.request['reason']}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attached Office Note Section
                      _buildOfficeNoteAttachment(widget.request['office_note_url']),
                      const SizedBox(height: 16),

                      if (linkedAsset != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Linked Asset: ${linkedAsset['asset_code'] ?? ''} - ${linkedAsset['name'] ?? ''}",
                                  style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Pending Stage decision controls
                      if (isPending) ...[
                        const Text(
                          'Submit Decision for this Stage',
                          style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        _buildField(_approverNameController, 'Approver Name / Role (e.g. IT Manager, GM)', required: true),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Remarks / Feedback'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter remarks for your decision' : null,
                        ),
                      ],

                      // Approved (Disbursement / Register in Inventory) controls
                      if (isApproved && linkedAsset == null) ...[
                        CheckboxListTile(
                          title: const Text('Register as IT Asset in Inventory', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Directly add this asset to your inventory upon fulfillment', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          value: _registerAsset,
                          activeColor: HOColors.primary,
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) {
                            setState(() => _registerAsset = v ?? false);
                          },
                        ),
                        if (_registerAsset) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'IT Asset Information',
                            style: TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _buildField(_codeController, 'Asset Code', required: true)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _category,
                                  dropdownColor: HOColors.surface,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: _inputDecoration('Category'),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (v) => setState(() => _category = v ?? 'Laptop'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildField(_nameController, 'Asset Name (e.g. Dell Latitude)', required: true),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildField(_modelController, 'Model')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField(_serialController, 'Serial Number')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildField(_costController, 'Purchase Cost (MMK)', isNumber: true)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField(_userController, 'Assigned User')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildField(_stationController, 'Assigned Station/Branch')),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField(_deptController, 'Assigned Department')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildField(_descController, 'Description / Remarks', maxLines: 2),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration('Fulfillment / Disbursement Notes'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Right Column: Timeline tracker
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: _buildTimeline(history, currentStatus),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
        if (isPending) ...[
          ElevatedButton(
            onPressed: _isSaving ? null : () => _processStageDecision(approve: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Reject (ငြင်းပယ်သည်)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _processStageDecision(approve: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Approve (အတည်ပြုသည်)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ] else if (isApproved) ...[
          ElevatedButton(
            onPressed: _isSaving ? null : _fulfillRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: HOColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Fulfill & Forward (ထုတ်ပေးပြီး)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}
