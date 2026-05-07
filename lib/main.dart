import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:ho_msloyalty/theme.dart';
import 'package:ho_msloyalty/pages/overview_page.dart';
import 'package:ho_msloyalty/pages/station_list_page.dart';
import 'package:ho_msloyalty/pages/activity_feed_page.dart';
import 'package:ho_msloyalty/pages/reports_page.dart';
import 'package:ho_msloyalty/pages/user_list_page.dart';
import 'package:ho_msloyalty/pages/gift_card_management_page.dart';
import 'package:ho_msloyalty/pages/banner_management_page.dart';
import 'package:ho_msloyalty/pages/system_user_page.dart';
import 'package:ho_msloyalty/pages/settings_page.dart';
import 'package:ho_msloyalty/pages/fuel_prices_page.dart';
import 'package:ho_msloyalty/pages/app_content_page.dart';
import 'package:ho_msloyalty/pages/app_version_management_page.dart';
import 'package:ho_msloyalty/pages/sms_broadcast_page.dart';
import 'package:ho_msloyalty/pages/noti_manager_page.dart';
import 'package:ho_msloyalty/pages/points_settings_page.dart';
import 'package:ho_msloyalty/pages/ad_management_page.dart';
import 'package:ho_msloyalty/pages/customer_feedback_page.dart';
import 'package:ho_msloyalty/pages/gps_bowser_page.dart';
import 'package:ho_msloyalty/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:ho_msloyalty/services/data_service.dart';
import 'package:local_notifier/local_notifier.dart';

import 'package:ho_msloyalty/pages/login_page.dart';
import 'package:ho_msloyalty/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.anonKey);
  await localNotifier.setup(appName: 'Moon Sun HO Dashboard');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HONotificationProvider()),
      ],
      child: const HOMainApp(),
    ),
  );
}

class HOMainApp extends StatelessWidget {
  const HOMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moon Sun HO Dashboard',
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      theme: HOTheme.darkTheme,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HODashboardBase extends StatefulWidget {
  const HODashboardBase({super.key});

  @override
  State<HODashboardBase> createState() => _HODashboardBaseState();
}

class _HODashboardBaseState extends State<HODashboardBase> {
  int _selectedIndex = 0;
  bool _isNavLoading = false;
  final Map<int, Key> _pageKeys = {};
  final HODataService _dataService = HODataService();
  RealtimeChannel? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _setupGlobalNotifications();
  }

  void _setupGlobalNotifications() {
    _activitySubscription = _dataService.subscribeToActivities((event, record) {
      if (event == PostgresChangeEvent.insert) {
        _showNotification(record);
        if (mounted) {
          context.read<HONotificationProvider>().addNotification(record);
        }
      }
    });
  }

  void _showNotification(Map<String, dynamic> activity) {
    final type = activity['action_type'] ?? 'unknown';
    final userName = activity['user_name'] ?? 'User';
    final description = activity['description'] ?? '';

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
      case 'SYSTEM_CONFIG':
        icon = Icons.settings;
        color = Colors.redAccent;
        break;
      case 'customer_feedback':
        icon = Icons.rate_review_rounded;
        color = Colors.lightBlueAccent;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.amber;
    }

    try {
      final notification = LocalNotification(
        title: userName,
        body: description,
      );
      notification.show();
    } catch (e) {
      debugPrint('Local notification error: $e');
    }

    BotToast.showCustomNotification(
      duration: const Duration(seconds: 5),
      toastBuilder: (cancel) {
        return Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 350,
            margin: const EdgeInsets.only(top: 20, right: 20),
            decoration: BoxDecoration(
              color: HOColors.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 16,
                    ),
                    onPressed: cancel,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _activitySubscription?.unsubscribe();
    super.dispose();
  }

  Widget _buildNotificationBell() {
    return Consumer<HONotificationProvider>(
      builder: (context, provider, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => _showNotificationTray(context, provider),
              icon: Icon(
                Icons.notifications_outlined,
                color: provider.unreadCount > 0
                    ? HOColors.accent
                    : Colors.white70,
                size: 26,
              ),
              tooltip: 'Notifications',
            ),
            if (provider.unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '${provider.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationTray(
    BuildContext context,
    HONotificationProvider provider,
  ) {
    provider.markAsRead();
    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 80, right: 24),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 400,
                height: 500,
                decoration: BoxDecoration(
                  color: HOColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'General Activity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              provider.clearAll();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    Expanded(
                      child: provider.notifications.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    color: Colors.white24,
                                    size: 40,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No recent activity',
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: provider.notifications.length,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.white.withOpacity(0.02),
                                indent: 70,
                              ),
                              itemBuilder: (context, index) {
                                final n = provider.notifications[index];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(n.type),
                                      color: _getNotificationColor(n.type),
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    n.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('HH:mm').format(n.timestamp),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white24,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        provider.removeNotification(n.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'collect_point':
        return Icons.add_circle;
      case 'redeem_reward':
        return Icons.card_giftcard;
      case 'SYSTEM_CONFIG':
        return Icons.settings;
      case 'customer_feedback':
        return Icons.rate_review_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'login':
        return Colors.blue;
      case 'logout':
        return Colors.orange;
      case 'collect_point':
        return Colors.green;
      case 'redeem_reward':
        return Colors.purple;
      case 'SYSTEM_CONFIG':
        return Colors.redAccent;
      case 'customer_feedback':
        return Colors.lightBlueAccent;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
          _buildSidebar(),

          // ── Main Content Area ──────────────────────────────────────────────
          Expanded(
            child: Container(
              color: HOColors.background,
              child: Column(
                children: [
                  // Global Top App Bar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: HOColors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNotificationBell(),
                        const SizedBox(width: 24),
                        const ServerClockWidget(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        IndexedStack(
                          index: _selectedIndex,
                          children: [
                            OverviewPage(key: _pageKeys[0]),
                            StationListPage(key: _pageKeys[1]),
                            ActivityFeedPage(key: _pageKeys[2]),
                            ReportsPage(key: _pageKeys[3]),
                            UserListPage(key: _pageKeys[4]),
                            GiftCardManagementPage(key: _pageKeys[5]),
                            BannerManagementPage(key: _pageKeys[6]),
                            SystemUserPage(key: _pageKeys[7]),
                            FuelPricesPage(key: _pageKeys[8]),
                            SettingsPage(key: _pageKeys[9]),
                            AppVersionManagementPage(key: _pageKeys[10]),
                            SMSBroadcastPage(key: _pageKeys[11]),
                            NotiManagerPage(key: _pageKeys[12]),
                            AppContentPage(key: _pageKeys[13]),
                            PointsSettingsPage(key: _pageKeys[14]),
                            AdManagementPage(key: _pageKeys[15]),
                            CustomerFeedbackPage(key: _pageKeys[16]),
                            GpsBowserPage(key: _pageKeys[17]),
                          ],
                        ),
                        if (_isNavLoading)
                          Container(
                            color: HOColors.background.withOpacity(0.7),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: HOColors.accent,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Refreshing Content...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: HOColors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.dashboard_customize,
                  color: HOColors.accent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'MOON SUN ENERGY',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'HO DASHBOARD',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: HOColors.accent,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _sidebarItem(0, Icons.speed, 'Overview'),
                  _sidebarItem(1, Icons.ev_station, 'Stations'),
                  _sidebarItem(2, Icons.feed, 'Activity Feed'),
                  _sidebarItem(3, Icons.bar_chart, 'Reports'),
                  _sidebarItem(4, Icons.people, 'Member Management'),
                  _sidebarItem(5, Icons.card_giftcard, 'Rewards'),
                  _sidebarItem(6, Icons.collections, 'Banners'),
                  _sidebarItem(7, Icons.admin_panel_settings, 'System Users'),
                  _sidebarItem(8, Icons.local_gas_station, 'Fuel Prices'),
                  _sidebarItem(17, Icons.gps_fixed, 'GPS Bowser'),
                  _sidebarItem(10, Icons.system_update_rounded, 'App Updates'),
                  _sidebarItem(11, Icons.campaign_rounded, 'SMS Broadcast'),
                  _sidebarItem(
                    12,
                    Icons.notifications_active_rounded,
                    'Noti Manager',
                  ),
                  _sidebarItem(13, Icons.article_rounded, 'App Content'),
                  _sidebarItem(14, Icons.stars_rounded, 'Point Management'),
                  _sidebarItem(15, Icons.ads_click, 'Splash ADs'),
                  _sidebarItem(
                    16,
                    Icons.rate_review_rounded,
                    'Customer Ratings',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          _sidebarItem(9, Icons.settings, 'Settings'),
          _sidebarItem(-2, Icons.logout, 'Logout'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () async {
          if (index == -2) {
            _showLogoutDialog();
          } else if (index >= 0) {
            if (_selectedIndex == index && !_isNavLoading) {
              // Force refresh if same items clicked
              setState(() {
                _isNavLoading = true;
                _pageKeys[index] = UniqueKey();
              });
              await Future.delayed(const Duration(milliseconds: 600));
              if (mounted) setState(() => _isNavLoading = false);
            } else if (_selectedIndex != index) {
              setState(() {
                _isNavLoading = true;
                _selectedIndex = index;
                _pageKeys[index] = UniqueKey(); // Reset state
              });
              await Future.delayed(const Duration(milliseconds: 600));
              if (mounted) setState(() => _isNavLoading = false);
            }
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isSelected ? HOColors.primary : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white60,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: HOColors.surface,
          title: const Text(
            'Confirm Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to log out of the HO Dashboard?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close Dialog
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Perform sign out and navigation
                Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ServerClockWidget extends StatefulWidget {
  const ServerClockWidget({super.key});

  @override
  State<ServerClockWidget> createState() => _ServerClockWidgetState();
}

class _ServerClockWidgetState extends State<ServerClockWidget> {
  final HODataService _dataService = HODataService();
  DateTime? _serverTime;
  Duration _difference = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchServerTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_serverTime != null && mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchServerTime() async {
    final serverDt = await _dataService.getServerTime();
    if (mounted) {
      setState(() {
        _difference = serverDt.difference(DateTime.now());
        _serverTime = serverDt;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_serverTime == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: HOColors.accent,
        ),
      );
    }

    final currentTime = DateTime.now().add(_difference);
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(currentTime);
    final timeStr = DateFormat('hh:mm:ss a').format(currentTime);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          dateStr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          timeStr,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
