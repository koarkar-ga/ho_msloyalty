import 'package:flutter/material.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ActivityFeedPage extends StatefulWidget {
  const ActivityFeedPage({super.key});

  @override
  State<ActivityFeedPage> createState() => _ActivityFeedPageState();
}

class _ActivityFeedPageState extends State<ActivityFeedPage> {
  final HODataService _dataService = HODataService();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadActivity();
    _setupRealtime();
  }

  void _setupRealtime() {
    _subscription = _dataService.subscribeToActivities((event, record) {
      if (event == PostgresChangeEvent.insert) {
        if (mounted) {
          setState(() {
            _activities.insert(0, record);
            if (_activities.length > 100) _activities.removeLast();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    try {
      final activities = await _dataService.getRecentActivity();
      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Activity Feed',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Live Updates',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _activities.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        final type = activity['action_type'] ?? 'unknown';
                        final userName = activity['user_name'] ?? 'System';
                        final description = activity['description'] ?? '';
                        final time = activity['created_at'] != null
                            ? DateTime.parse(activity['created_at']).toLocal()
                            : DateTime.now();

                        IconData icon;
                        Color color;
                        switch (type) {
                          case 'login':
                            icon = Icons.login;
                            color = Colors.blue;
                            break;
                          case 'logout':
                            icon = Icons.logout;
                            color = Colors.orange;
                            break;
                          case 'collect_point':
                            icon = Icons.add_circle;
                            color = Colors.green;
                            break;
                          case 'redeem_reward':
                            icon = Icons.card_giftcard;
                            color = Colors.purple;
                            break;
                          default:
                            icon = Icons.notifications;
                            color = Colors.amber;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '$userName ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text: description,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy, hh:mm a',
                                      ).format(time),
                                      style: const TextStyle(
                                        color: Colors.white24,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.white10,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
