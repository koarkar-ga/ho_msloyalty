import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:intl/intl.dart';

class CustomerFeedbackPage extends StatefulWidget {
  const CustomerFeedbackPage({super.key});

  @override
  State<CustomerFeedbackPage> createState() => _CustomerFeedbackPageState();
}

class _CustomerFeedbackPageState extends State<CustomerFeedbackPage> {
  final HODataService _dataService = HODataService();
  List<Map<String, dynamic>> _feedback = [];
  bool _isLoading = true;

  // Filter states
  String? _selectedStation;
  List<Map<String, dynamic>> _stations = [];
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final stations = await _dataService.getStationsForDropdown();
      if (mounted) {
        setState(() {
          _stations = stations;
        });
      }
      await _loadFeedback();
    } catch (e) {
      if (mounted) _loadFeedback();
    }
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getCustomerFeedback(
        stationId: _selectedStation,
        startDate: _startDate,
        endDate: _endDate,
        invoiceNo: _invoiceController.text,
        memberName: _memberController.text,
      );
      if (mounted) {
        setState(() {
          _feedback = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feedback: $e')),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStation = null;
      _startDate = null;
      _endDate = null;
      _invoiceController.clear();
      _memberController.clear();
    });
    _loadFeedback();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: HOColors.accent,
              onPrimary: HOColors.primary,
              surface: HOColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadFeedback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Feedback',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const Text(
                    'Monitor customer ratings and remarks from point collections',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18, color: Colors.white54),
                    label: const Text('Clear Filters', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loadFeedback,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HOColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilterBar(),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: HOColors.accent))
                : _feedback.isEmpty
                    ? _buildEmptyState()
                    : _buildFeedbackList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HOColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          // Station Filter
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter By Station', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStation,
                  dropdownColor: HOColors.surface,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _filterInputDecoration('All Stations'),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All Stations')),
                    ..._stations.map((s) => DropdownMenuItem(
                          value: s['station_id'].toString(),
                          child: Text(s['name'] ?? 'Unknown'),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedStation = v);
                    _loadFeedback();
                  },
                ),
              ],
            ),
          ),
          // Date Filter
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter By DateTime', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDateRange,
                  child: InputDecorator(
                    decoration: _filterInputDecoration('Select Range'),
                    child: Text(
                      _startDate == null
                          ? 'Select Range'
                          : '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Invoice No Filter
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter By Invoice No', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _invoiceController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _filterInputDecoration('Search Invoice...'),
                  onSubmitted: (_) => _loadFeedback(),
                ),
              ],
            ),
          ),
          // Member Filter
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter By Member', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _memberController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _filterInputDecoration('Name or Phone...'),
                  onSubmitted: (_) => _loadFeedback(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feedback_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No feedback found matching the filters',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList() {
    return ListView.builder(
      itemCount: _feedback.length,
      itemBuilder: (context, index) {
        final item = _feedback[index];
        final profile = item['profiles'] as Map<String, dynamic>?;
        final rating = (item['customer_rating'] as num?)?.toInt() ?? 0;
        final remark = item['customer_remark'] ?? 'No comment';
        final createdAt = item['created_at'];
        final date = createdAt != null ? DateTime.parse(createdAt) : DateTime.now();
        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());

        return Card(
          color: HOColors.surface,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: HOColors.accent.withOpacity(0.1),
                  child: Text(
                    (profile?['full_name']?.toString() ?? 'U').isNotEmpty
                        ? profile!['full_name'].toString()[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: HOColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            profile?['full_name'] ?? 'Unknown User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile?['phone_number'] ?? '-',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 18,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          remark,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Voucher: ${item['voc_no'] ?? '-'} | Station: ${item['station_id'] ?? '-'}',
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
