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

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getCustomerFeedback();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.feedback_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No feedback found',
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
        final date = DateTime.parse(item['created_at']);
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
                    (profile?['full_name'] ?? 'U')[0].toUpperCase(),
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
