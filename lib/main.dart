import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ms_dashboard/theme.dart';
import 'package:ms_dashboard/pages/overview_page.dart';
import 'package:ms_dashboard/pages/station_list_page.dart';
import 'package:ms_dashboard/pages/activity_feed_page.dart';
import 'package:ms_dashboard/pages/reports_page.dart';
import 'package:ms_dashboard/pages/user_list_page.dart';
import 'package:ms_dashboard/pages/gift_card_management_page.dart';
import 'package:ms_dashboard/pages/banner_management_page.dart';
import 'package:ms_dashboard/pages/system_user_page.dart';
import 'package:ms_dashboard/pages/settings_page.dart';
import 'package:ms_dashboard/pages/fuel_prices_page.dart';
import 'package:ms_dashboard/pages/app_content_page.dart';
import 'package:ms_dashboard/pages/app_version_management_page.dart';
import 'package:ms_dashboard/pages/sms_broadcast_page.dart';
import 'package:ms_dashboard/pages/noti_manager_page.dart';
import 'package:ms_dashboard/pages/points_settings_page.dart';
import 'package:ms_dashboard/pages/ad_management_page.dart';
import 'package:ms_dashboard/pages/customer_feedback_page.dart';
import 'package:ms_dashboard/pages/gps_bowser_page.dart';
import 'package:ms_dashboard/pages/it_assets_page.dart';
import 'package:ms_dashboard/pages/it_ticket_support_page.dart';
import 'package:ms_dashboard/pages/asset_transfer_page.dart';
import 'package:ms_dashboard/pages/asset_maintenance_page.dart';
import 'package:ms_dashboard/pages/asset_request_page.dart';
import 'package:ms_dashboard/pages/fleet_management_page.dart';
import 'package:ms_dashboard/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:ms_dashboard/services/data_service.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:ms_dashboard/services/session_manager.dart';

import 'package:ms_dashboard/pages/login_page.dart';
import 'package:ms_dashboard/providers/notification_provider.dart';

import 'package:ms_dashboard/pages/station_reports_page.dart';
import 'package:ms_dashboard/pages/station_status_page.dart';
import 'package:ms_dashboard/pages/comparison_report_page.dart';
import 'package:ms_dashboard/pages/duplicate_analysis_page.dart';
import 'package:ms_dashboard/pages/financials_page.dart';
import 'package:ms_dashboard/pages/sales_purchases_page.dart';
import 'package:ms_dashboard/pages/inventory_management_page.dart';
import 'package:ms_dashboard/pages/approvals_page.dart';

import 'package:ms_dashboard/services/accounting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.anonKey);

  if (!kIsWeb) {
    await localNotifier.setup(appName: 'Moon Sun HO Dashboard');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HONotificationProvider()),
        ChangeNotifierProvider(create: (_) => HOAccountingService()),
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
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: true,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isNavLoading = false;
  final Map<int, Key> _pageKeys = {};
  final HODataService _dataService = HODataService();
  RealtimeChannel? _activitySubscription;
  String _username = 'Admin';
  final ScrollController _sidebarScrollController = ScrollController();
  bool _showSidebarScrollIndicator = false;

  @override
  void initState() {
    super.initState();
    _setupGlobalNotifications();
    _loadUsername();
    _sidebarScrollController.addListener(_updateScrollIndicator);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicator();
    });
  }

  void _updateScrollIndicator() {
    if (!_sidebarScrollController.hasClients) return;
    final maxScroll = _sidebarScrollController.position.maxScrollExtent;
    final currentScroll = _sidebarScrollController.position.pixels;
    final show = maxScroll > 0 && (maxScroll - currentScroll) > 10;
    if (show != _showSidebarScrollIndicator) {
      setState(() {
        _showSidebarScrollIndicator = show;
      });
    }
  }

  Future<void> _loadUsername() async {
    final name = await SessionManager.getUsername();
    if (name != null && name.isNotEmpty) {
      if (mounted) {
        setState(() {
          _username = name;
        });
      }
    }
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
      if (kIsWeb) {
        BotToast.showSimpleNotification(
          title: "$userName - $type",
          subTitle: description,
          backgroundColor: HOColors.surface,
          titleStyle: const TextStyle(color: HOColors.accent),
          subTitleStyle: const TextStyle(color: Colors.white70),
        );
        return;
      }

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
    _sidebarScrollController.removeListener(_updateScrollIndicator);
    _sidebarScrollController.dispose();
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
    final bool isMobile = MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? Drawer(child: _buildSidebar(isMobile: true)) : null,
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
          if (!isMobile) _buildSidebar(isMobile: false),

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
                      mainAxisAlignment: isMobile
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.end,
                      children: [
                        if (isMobile)
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildNotificationBell(),
                            const SizedBox(width: 24),
                            const ServerClockWidget(),
                            const SizedBox(width: 24),
                            _buildUserProfileMenu(isMobile),
                          ],
                        ),
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
                            ReportsPage(key: _pageKeys[3], mode: 'sales'),
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
                            ITAssetsPage(key: _pageKeys[18]),
                            ITTicketSupportPage(key: _pageKeys[19]),
                            AssetTransferPage(key: _pageKeys[20]),
                            AssetMaintenancePage(key: _pageKeys[21]),
                            AssetRequestPage(key: _pageKeys[22]),
                            FleetManagementPage(key: _pageKeys[23]),
                            ReportsPage(key: _pageKeys[24], mode: 'loyalty'),
                            StationReportsPage(key: _pageKeys[25]),
                            StationStatusPage(key: _pageKeys[26]),
                            ComparisonReportPage(key: _pageKeys[27]),
                            DuplicateAnalysisPage(key: _pageKeys[28]),
                            FinancialsPage(key: _pageKeys[29]),
                            SalesPurchasesPage(key: _pageKeys[30]),
                            InventoryManagementPage(key: _pageKeys[31]),
                            ApprovalsPage(key: _pageKeys[32]),
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

  Widget _buildSidebar({bool isMobile = false}) {
    return Container(
      width: isMobile ? null : 260,
      color: HOColors.surface,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
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
                  controller: _sidebarScrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _sidebarHeader('GENERAL'),
                      _sidebarItem(
                        0,
                        Icons.speed,
                        'Overview',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        1,
                        Icons.ev_station,
                        'Stations',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        2,
                        Icons.feed,
                        'Activity Feed',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        3,
                        Icons.bar_chart,
                        'Station Sale Report',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('STATION APP REPORTS'),
                      _sidebarItem(
                        25,
                        Icons.analytics_rounded,
                        'Reports Summary',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        26,
                        Icons.wifi_rounded,
                        'Station Status',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        27,
                        Icons.compare_arrows_rounded,
                        'Comparison Report',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        28,
                        Icons.warning_amber_rounded,
                        'Analysis Report',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('LOYALTY & MARKETING'),
                      _sidebarItem(
                        4,
                        Icons.people,
                        'Member Management',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        5,
                        Icons.card_giftcard,
                        'Rewards',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        14,
                        Icons.stars_rounded,
                        'Point Management',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        6,
                        Icons.collections,
                        'Banners',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        11,
                        Icons.campaign_rounded,
                        'SMS Broadcast',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        12,
                        Icons.notifications_active_rounded,
                        'Noti Manager',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        13,
                        Icons.article_rounded,
                        'App Content',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        15,
                        Icons.ads_click,
                        'Splash ADs',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        16,
                        Icons.rate_review_rounded,
                        'Customer Ratings',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        24,
                        Icons.insert_chart_outlined_rounded,
                        'Loyalty Report',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('SYSTEM ADMINISTRATION'),
                      _sidebarItem(
                        7,
                        Icons.admin_panel_settings,
                        'System Users',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        8,
                        Icons.local_gas_station,
                        'Fuel Prices',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        10,
                        Icons.system_update_rounded,
                        'App Updates',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('FLEET MANAGEMENT'),
                      _sidebarItem(
                        17,
                        Icons.gps_fixed,
                        'Bowser GPS',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        23,
                        Icons.monitor_rounded,
                        'Monitoring',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('IT & ASSETS'),
                      _sidebarItem(
                        18,
                        Icons.inventory_2_rounded,
                        'IT Assets',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        19,
                        Icons.support_agent_rounded,
                        'Support Tickets',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        20,
                        Icons.swap_horiz_rounded,
                        'Asset Transfers',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        21,
                        Icons.handyman_rounded,
                        'Maintenances',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        22,
                        Icons.shopping_cart_rounded,
                        'Asset Requests',
                        isMobile: isMobile,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: Colors.white10,
                          indent: 16,
                          endIndent: 16,
                        ),
                      ),
                      _sidebarHeader('ACCOUNTING & FINANCE'),
                      _sidebarItem(
                        29,
                        Icons.account_balance_outlined,
                        'Financials',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        30,
                        Icons.shopping_bag_outlined,
                        'Sales & Purchases',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        31,
                        Icons.inventory_2_outlined,
                        'Inventory Management',
                        isMobile: isMobile,
                      ),
                      _sidebarItem(
                        32,
                        Icons.assignment_turned_in_outlined,
                        'Approvals Process',
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showSidebarScrollIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        HOColors.surface.withOpacity(0.0),
                        HOColors.surface.withOpacity(0.9),
                        HOColors.surface,
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HOColors.primary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: HOColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: HOColors.accent,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'SCROLL FOR MORE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: HOColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _sidebarItem(
    int index,
    IconData icon,
    String title, {
    bool isMobile = false,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () async {
          if (index == -2) {
            if (isMobile) {
              Navigator.pop(context);
            }
            _showLogoutDialog();
          } else if (index >= 0) {
            if (isMobile) {
              Navigator.pop(context);
            }
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

  Widget _buildUserProfileMenu(bool isMobile) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      color: HOColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      onSelected: (value) async {
        if (value == 'profile') {
          _showProfileDialog();
        } else if (value == 'settings') {
          if (_selectedIndex == 9 && !_isNavLoading) return;
          setState(() {
            _isNavLoading = true;
            _selectedIndex = 9;
            _pageKeys[9] = UniqueKey();
          });
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) setState(() => _isNavLoading = false);
        } else if (value == 'logout') {
          _showLogoutDialog();
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: HOColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Profile', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                color: Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Settings', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: HOColors.primary.withOpacity(0.2),
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: HOColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 10),
              Text(
                _username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() async {
    final userId = await SessionManager.getUserId() ?? 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: HOColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [HOColors.primary, HOColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HOColors.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 41,
                    backgroundColor: HOColors.surface,
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: HOColors.primary.withOpacity(0.1),
                      child: Text(
                        _username.isNotEmpty ? _username[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          color: HOColors.accent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _username.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: HOColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Head Office Administrator',
                  style: TextStyle(
                    color: HOColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Divider(color: Colors.white10),
              const SizedBox(height: 15),
              _buildProfileDetailRow(
                Icons.badge_outlined,
                'User ID',
                '#$userId',
              ),
              const SizedBox(height: 16),
              _buildProfileDetailRow(
                Icons.mail_outline_rounded,
                'Email',
                'admin@moonsungroup.com',
              ),
              const SizedBox(height: 16),
              _buildProfileDetailRow(
                Icons.security_outlined,
                'Security Group',
                'Super Admin',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HOColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white54, size: 18),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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
              onPressed: () async {
                // Perform sign out and navigation
                await SessionManager.clearSession();
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
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
