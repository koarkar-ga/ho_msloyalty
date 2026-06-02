import 'package:flutter/material.dart';
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ITTicketSupportPage extends StatefulWidget {
  const ITTicketSupportPage({super.key});

  @override
  State<ITTicketSupportPage> createState() => _ITTicketSupportPageState();
}

class _ITTicketSupportPageState extends State<ITTicketSupportPage> {
  final HODataService _dataService = HODataService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';

  final List<String> _statuses = [
    'ALL',
    'Pending',
    'In Progress',
    'Resolved',
    'Closed',
  ];
  final List<String> _priorities = ['ALL', 'Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ticketsList = await _dataService.getITTickets();
      if (mounted) {
        setState(() {
          _tickets = ticketsList;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tickets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTickets = _tickets.where((ticket) {
        final matchesSearch =
            (ticket['ticket_no']?.toString().toLowerCase().contains(query) ??
                false) ||
            (ticket['name']?.toString().toLowerCase().contains(query) ??
                false) ||
            (ticket['description']?.toString().toLowerCase().contains(query) ??
                false) ||
            (ticket['station_id']?.toString().toLowerCase().contains(query) ??
                false);

        final matchesStatus =
            _selectedStatus == 'ALL' || ticket['status'] == _selectedStatus;
        final matchesPriority =
            _selectedPriority == 'ALL' ||
            ticket['priority'] == _selectedPriority;

        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  void _showResolveDialog(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      builder: (context) => _ResolveTicketDialog(
        ticket: ticket,
        dataService: _dataService,
        onSaved: _loadData,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.redAccent;
      case 'In Progress':
        return Colors.amber;
      case 'Resolved':
        return Colors.green;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.white54;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
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
                  'IT Ticket Support',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track and resolve technical support complaints from fuel stations and head office departments.',
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
                      hintText:
                          'Search by Ticket No, Requester, Station, Description...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
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
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
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
                    items: _priorities
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
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
                  : _filteredTickets.isEmpty
                  ? const Center(
                      child: Text(
                        'No support tickets found matching filters.',
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
                            DataColumn(label: Text('Ticket No')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Requester')),
                            DataColumn(label: Text('Station / Dept')),
                            DataColumn(label: Text('Priority')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _filteredTickets.map((ticket) {
                            final date = ticket['created_at'] != null
                                ? DateFormat('dd MMM yyyy HH:mm').format(
                                    DateTime.parse(
                                      ticket['created_at'],
                                    ).toLocal(),
                                  )
                                : '-';
                            final location = [
                              if (ticket['station_id'] != null &&
                                  ticket['station_id'].toString().isNotEmpty)
                                'Station: ${ticket['station_id']}',
                              if (ticket['department'] != null &&
                                  ticket['department'].toString().isNotEmpty)
                                ticket['department'],
                            ].join(' / ');

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    ticket['ticket_no'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(Text(date)),
                                DataCell(Text(ticket['name'] ?? '')),
                                DataCell(Text(location)),
                                DataCell(
                                  Text(
                                    ticket['priority'] ?? 'Medium',
                                    style: TextStyle(
                                      color: _getPriorityColor(
                                        ticket['priority'] ?? '',
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Tooltip(
                                    message: ticket['description'] ?? '',
                                    child: SizedBox(
                                      width: 200,
                                      child: Text(
                                        ticket['description'] ?? '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        ticket['status'] ?? '',
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          ticket['status'] ?? '',
                                        ).withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      ticket['status'] ?? 'Pending',
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          ticket['status'] ?? '',
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.rate_review,
                                      color: Colors.amber,
                                      size: 20,
                                    ),
                                    tooltip: 'Update Status',
                                    onPressed: () => _showResolveDialog(ticket),
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

class _ResolveTicketDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final HODataService dataService;
  final VoidCallback onSaved;

  const _ResolveTicketDialog({
    required this.ticket,
    required this.dataService,
    required this.onSaved,
  });

  @override
  State<_ResolveTicketDialog> createState() => _ResolveTicketDialogState();
}

class _ResolveTicketDialogState extends State<_ResolveTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _remarksController;
  late String _status;
  bool _isSaving = false;

  final List<String> _statuses = [
    'Pending',
    'In Progress',
    'Resolved',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController(
      text: widget.ticket['remarks'] ?? '',
    );
    _status = widget.ticket['status'] ?? 'Pending';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await widget.dataService.updateITTicketStatus(
        widget.ticket['id'],
        _status,
        _remarksController.text,
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

  Future<void> _openOfficeNote(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.redAccent;
      case 'High':
        return Colors.orangeAccent;
      case 'Medium':
        return Colors.blueAccent;
      case 'Low':
        return Colors.greenAccent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final date = ticket['created_at'] != null
        ? DateFormat(
            'dd MMM yyyy HH:mm',
          ).format(DateTime.parse(ticket['created_at']).toLocal())
        : '-';
    final noteUrl = ticket['office_note_url'] as String?;
    final ocrText = ticket['ocr_text'] as String?;
    final location = [
      if (ticket['station_id'] != null &&
          ticket['station_id'].toString().isNotEmpty)
        'Station: ${ticket['station_id']}',
      if (ticket['department'] != null &&
          ticket['department'].toString().isNotEmpty)
        ticket['department'],
    ].join(' / ');

    return AlertDialog(
      backgroundColor: HOColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Respond to Ticket: ${ticket['ticket_no']}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Requester & Location Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REQUESTER',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'STATION / DEPARTMENT',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),

                // Category, Priority, Date Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATEGORY',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket['category'] ?? 'Maintenance',
                            style: const TextStyle(
                              color: HOColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'PRIORITY',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ticket['priority'] ?? 'Medium',
                            style: TextStyle(
                              color: _getPriorityColor(
                                ticket['priority'] ?? '',
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'SUBMITTED DATE',
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),

                // Description Box
                const Text(
                  'ISSUE DESCRIPTION',
                  style: TextStyle(
                    color: HOColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Text(
                    ticket['description'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Office Note Attachment Row
                if (noteUrl != null && noteUrl.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.attachment_rounded,
                            color: HOColors.accent,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Signed Office Note Attachment',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openOfficeNote(noteUrl),
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'Open Office Note',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HOColors.accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Extracted OCR Text Card
                const Row(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      color: HOColors.accent,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'OFFICE NOTE OCR TEXT (EXTRACTED)',
                      style: TextStyle(
                        color: HOColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HOColors.accent.withOpacity(0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      (ocrText != null && ocrText.trim().isNotEmpty)
                          ? ocrText
                          : 'No text extracted or Office Note not attached.',
                      style: TextStyle(
                        color: (ocrText != null && ocrText.trim().isNotEmpty)
                            ? Colors.white70
                            : Colors.white30,
                        fontSize: 12.5,
                        height: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Update Status Dropdown
                DropdownButtonFormField<String>(
                  value: _status,
                  dropdownColor: HOColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Update Status',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'Pending'),
                ),
                const SizedBox(height: 16),

                // Remarks Text Field
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Remarks / Resolution Action',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
                  'Submit Response',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
