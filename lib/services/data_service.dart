import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class HODataService {
  final supabase = Supabase.instance.client;

  // ── Server Time ──────────────────────────────────────────────────
  Future<DateTime> getServerTime() async {
    try {
      final response = await supabase.rpc('get_server_time');
      return DateTime.parse(response as String).toLocal();
    } catch (e) {
      return DateTime.now(); // Fallback
    }
  }

  // ── Summary Stats ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSummaryStats() async {
    final today = DateTime.now().toUtc().toIso8601String().split('T')[0];

    // Points issued today
    final pointsRes = await supabase
        .from('fuel_transactions')
        .select('points_earned')
        .gte('created_at', today);

    int totalPoints = 0;
    for (var row in pointsRes) {
      totalPoints += (row['points_earned'] as num).toInt();
    }

    // Redemptions today
    final redemptionsRes = await supabase
        .from('redemption_history')
        .select('id')
        .gte('created_at', today);

    final totalRedemptions = redemptionsRes.length;

    // Active stations
    final stationsRes = await supabase.from('stations').select('id');

    final totalStations = stationsRes.length;

    // Online users (last 5 minutes)
    final fiveMinsAgo = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 5))
        .toIso8601String();
    final onlineRes = await supabase
        .from('profiles')
        .select('id')
        .gte('last_login_at', fiveMinsAgo)
        .eq('is_active', true);

    final onlineUsers = onlineRes.length;

    return {
      'pointsToday': totalPoints,
      'redemptionsToday': totalRedemptions,
      'activeStations': totalStations,
      'onlineUsers': onlineUsers,
    };
  }

  // ── Station Metrics ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStationsWithMetrics() async {
    final stations = await supabase.from('stations').select('*, station_id');
    final txns = await supabase
        .from('fuel_transactions')
        .select('station_id, points_earned');

    List<Map<String, dynamic>> result = [];
    for (var station in stations) {
      final sId = station['station_id'];
      int points = 0;
      int count = 0;

      for (var txn in txns) {
        if (txn['station_id'] == sId) {
          points += (txn['points_earned'] as num).toInt();
          count++;
        }
      }

      result.add({
        ...station,
        'totalPoints': points,
        'txnCount': count,
        'status': 'Online', // Placeholder logic for now
      });
    }

    return result;
  }

  // ── Recent Activity ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    final response = await supabase
        .from('activities')
        .select('*')
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }

  RealtimeChannel subscribeToActivities(
    void Function(PostgresChangeEvent event, Map<String, dynamic> record)
    callback,
  ) {
    print("DEBUG: Subscribing to activities...");
    final channel = supabase.channel('public:activities');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'activities',
          callback: (payload) {
            print("DEBUG: Activities change received: ${payload.eventType}");
            callback(payload.eventType, payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  // ── Activity Logging ──────────────────────────────────────────────
  Future<void> logActivity({
    required String actionType,
    required String description,
    String? stationId,
    String? userId,
    String? userName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await supabase.from('activities').insert({
        'action_type': actionType,
        'description': description,
        'station_id': ?stationId,
        'user_id': ?userId,
        'user_name': ?userName,
        'metadata': ?metadata,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print("Failed to log activity: $e");
    }
  }

  // ── Update/Create Station ────────────────────────────────────────────────
  Future<void> updateStation(int id, Map<String, dynamic> data) async {
    await supabase.from('stations').update(data).eq('id', id);
  }

  Future<void> createStation(Map<String, dynamic> data) async {
    await supabase.from('stations').insert(data);
  }

  // ── Upload Image ──────────────────────────────────────────────────
  Future<String?> uploadStationImage(
    String stationId,
    Uint8List bytes,
    String extension,
  ) async {
    final path =
        'stations/$stationId-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension'),
        );

    return supabase.storage.from('moonsun_assets').getPublicUrl(path);
  }

  // ── User Management ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getUsers() async {
    final profiles = await supabase
        .from('profiles')
        .select('*, member_types(name)')
        .order('full_name');

    // Fetch stats to enrich profile data
    // Note: In a production app, this should be done via a View or RPC for efficiency
    try {
      final earnedRes = await supabase
          .from('fuel_transactions')
          .select('user_id, points_earned');
      final usedRes = await supabase
          .from('redemption_history')
          .select('user_id, points_spent');

      Map<String, int> earnedMap = {};
      for (var row in earnedRes) {
        final uid = row['user_id'] as String?;
        if (uid != null) {
          earnedMap[uid] =
              (earnedMap[uid] ?? 0) + (row['points_earned'] as num).toInt();
        }
      }

      Map<String, int> usedMap = {};
      for (var row in usedRes) {
        final uid = row['user_id'] as String?;
        if (uid != null) {
          usedMap[uid] =
              (usedMap[uid] ?? 0) + (row['points_spent'] as num).toInt();
        }
      }

      return profiles.map((p) {
        final uid = p['id'];
        return {
          ...p,
          'earned_points': earnedMap[uid] ?? 0,
          'used_points': usedMap[uid] ?? 0,
        };
      }).toList();
    } catch (e) {
      // Fallback if transaction tables aren't accessible or have different schema
      return List<Map<String, dynamic>>.from(profiles);
    }
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    await supabase
        .from('profiles')
        .update({'is_active': isActive})
        .eq('id', userId);
  }

  // ── Gift Card Management ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGiftCards() async {
    final response = await supabase
        .from('gift_cards')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateGiftCard(int id, Map<String, dynamic> data) async {
    await supabase.from('gift_cards').update(data).eq('id', id);
  }

  Future<void> createGiftCard(Map<String, dynamic> data) async {
    await supabase.from('gift_cards').insert(data);
  }

  Future<void> deleteGiftCard(int id) async {
    await supabase.from('gift_cards').delete().eq('id', id);
  }

  Future<String?> uploadGiftCardImage(Uint8List bytes, String extension) async {
    final fileName =
        'giftcards/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension'),
        );

    return supabase.storage.from('moonsun_assets').getPublicUrl(fileName);
  }

  // ── Banner Management ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBanners() async {
    final response = await supabase
        .from('banners')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createBanner(Map<String, dynamic> data) async {
    await supabase.from('banners').insert(data);
  }

  Future<void> updateBanner(int id, Map<String, dynamic> data) async {
    await supabase.from('banners').update(data).eq('id', id);
  }

  Future<void> deleteBanner(int id) async {
    await supabase.from('banners').delete().eq('id', id);
  }

  Future<String?> uploadBannerImage(Uint8List bytes, String extension) async {
    final fileName =
        'banners/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension'),
        );
    return supabase.storage.from('moonsun_assets').getPublicUrl(fileName);
  }

  // ── System User Management (Station/HO) ───────────────────────────
  Future<List<Map<String, dynamic>>> getStationUsers() async {
    try {
      final response = await supabase
          .from('auth')
          .select('*')
          .order('fullname');

      final users = List<Map<String, dynamic>>.from(response);

      // Fetch stations to get names
      final stationsRes = await supabase
          .from('stations')
          .select('station_id, name');
      final stationsMap = {
        for (var s in stationsRes)
          s['station_id'].toString(): s['name'].toString(),
      };

      return users.map((u) {
        final sCode = u['station_code']?.toString();
        return {
          ...u,
          'station_name': sCode == 'ALL'
              ? 'ALL STATIONS'
              : (stationsMap[sCode] ?? 'Unknown'),
        };
      }).toList();
    } catch (e) {
      print("Error in getStationUsers: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getHOServerConfig() async {
    try {
      final response = await supabase
          .from('auth')
          .select('db_host, db_user, db_pass, db_name, api_url')
          .eq('station_code', 'ALL')
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print("Error in getHOServerConfig: $e");
      return null;
    }
  }

  Future<void> saveHOServerConfig(Map<String, dynamic> data) async {
    await supabase.from('auth').update(data).eq('station_code', 'ALL');

    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Updated HO Server Configuration',
      metadata: data,
    );
  }

  Future<String> getHOConfigPassword() async {
    try {
      final response = await supabase
          .from('system_settings')
          .select('value')
          .eq('key', 'ho_config_password')
          .maybeSingle();
      return response?['value'] ?? 'msloyalty@ho';
    } catch (e) {
      print("Error fetching HO Password: $e");
      return 'msloyalty@ho';
    }
  }

  Future<void> updateHOConfigPassword(String newPassword) async {
    try {
      await supabase
          .from('system_settings')
          .update({'value': newPassword})
          .eq('key', 'ho_config_password');

      await logActivity(
        actionType: 'UPDATE_HO_PASSWORD',
        description: 'Updated HO Configuration Password',
      );
    } catch (e) {
      print("Error updating HO Password: $e");
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getHOUsers() async {
    final response = await supabase
        .from('ho_auth')
        .select('*')
        .order('fullname');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createStationUser(Map<String, dynamic> data) async {
    await supabase.from('auth').insert(data);
  }

  Future<void> createHOUser(Map<String, dynamic> data) async {
    await supabase.from('ho_auth').insert(data);
  }

  Future<void> updateStationUser(int id, Map<String, dynamic> data) async {
    await supabase.from('auth').update(data).eq('id', id);
  }

  Future<void> updateHOUser(int id, Map<String, dynamic> data) async {
    await supabase.from('ho_auth').update(data).eq('id', id);
  }

  Future<void> deleteStationUser(int id) async {
    await supabase.from('auth').delete().eq('id', id);
  }

  Future<void> deleteHOUser(int id) async {
    await supabase.from('ho_auth').delete().eq('id', id);
  }

  // ── HO Login ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> loginHOUser(
    String username,
    String password,
  ) async {
    try {
      final response = await supabase
          .from('ho_auth')
          .select('*')
          .eq('username', username)
          .limit(1);

      if (response.isEmpty) {
        return {'status': 'error', 'message': 'Username not found'};
      }

      final user = response.first;
      if (user['password'] == password) {
        return {'status': 'success', 'user': user};
      } else {
        return {'status': 'error', 'message': 'Incorrect password'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // ── Dashboard Chart Data ──────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardChartData() async {
    // 1. Points Issued by Station
    final stationsRes = await supabase
        .from('stations')
        .select('station_id, name');
    final txnsRes = await supabase
        .from('fuel_transactions')
        .select('station_id, points_earned');

    Map<String, double> stationPoints = {};
    Map<String, String> stationIdToName = {};

    for (var s in stationsRes) {
      final name = s['name'] ?? 'Unknown';
      stationIdToName[s['station_id']] = name;
      stationPoints[name] = 0.0; // Initialize with 0
    }

    for (var txn in txnsRes) {
      final sId = txn['station_id'];
      final name = stationIdToName[sId] ?? sId ?? 'Unknown';
      final points = (txn['points_earned'] as num?)?.toDouble() ?? 0.0;
      stationPoints[name] = (stationPoints[name] ?? 0.0) + points;
    }

    List<Map<String, dynamic>> pointsByStation = stationPoints.entries
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();

    // Sort by points descending
    pointsByStation.sort(
      (a, b) => (b['value'] as double).compareTo(a['value'] as double),
    );

    // 2. Fuel Type Distribution (Count)
    final fuelTypesRes = await supabase
        .from('fuel_transactions')
        .select('fuel_type');
    Map<String, int> fuelCounts = {};
    for (var txn in fuelTypesRes) {
      final type = txn['fuel_type'] ?? 'Other';
      fuelCounts[type] = (fuelCounts[type] ?? 0) + 1;
    }

    List<Map<String, dynamic>> fuelDistribution = fuelCounts.entries
        .map((e) => {'name': e.key, 'value': e.value.toDouble()})
        .toList();

    return {
      'pointsByStation': pointsByStation,
      'fuelDistribution': fuelDistribution,
    };
  }

  // ── HO Reporting Data Fetchers ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStationsForDropdown() async {
    final response = await supabase
        .from('stations')
        .select('id, station_id, name')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  // 1. Sale Transactions Report
  Future<List<Map<String, dynamic>>> getSaleTransactionsReport({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    var query = supabase
        .from('fuel_transactions')
        .select('*')
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lte('created_at', endDate.toUtc().toIso8601String());

    if (stationId != null && stationId.isNotEmpty) {
      query = query.eq('station_id', stationId);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Point Issue Report (Re-uses fuel_transactions but filtered where points > 0)
  Future<List<Map<String, dynamic>>> getPointIssueReport({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    var query = supabase
        .from('fuel_transactions')
        .select('*, profiles(full_name, phone_number)')
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lte('created_at', endDate.toUtc().toIso8601String())
        .gt('points_earned', 0);

    if (stationId != null && stationId.isNotEmpty) {
      query = query.eq('station_id', stationId);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 3. Redemption Report
  Future<List<Map<String, dynamic>>> getRedemptionReport({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    var query = supabase
        .from('redemption_history')
        .select(
          '*, profiles(full_name, phone_number), gift_cards(title, points_required)',
        )
        .gte('created_at', startDate.toUtc().toIso8601String())
        .lte('created_at', endDate.toUtc().toIso8601String());

    if (stationId != null && stationId.isNotEmpty) {
      query = query.eq('station_id', stationId);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Fuel Prices ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getFuelPrices() async {
    final response = await supabase
        .from('fuel_prices')
        .select('*')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> upsertFuelPrice({
    int? id,
    String? region,
    String? stationId,
    required int octane92,
    required int octane95,
    required int diesel,
    required int premiumDiesel,
  }) async {
    final Map<String, dynamic> data = {
      'id': ?id,
      'octane_92': octane92,
      'octane_95': octane95,
      'diesel': diesel,
      'premium_diesel': premiumDiesel,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (region != null) data['region'] = region;
    if (stationId != null) data['station_id'] = stationId;

    // Use upsert with conflict resolution based on the new unique indexes
    await supabase
        .from('fuel_prices')
        .upsert(
          data,
          onConflict: id != null
              ? 'id'
              : (region != null ? 'region' : 'station_id'),
        );

    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Updated fuel prices for ${region ?? "Station $stationId"}',
      metadata: data,
    );
  }

  Future<void> deleteFuelPrice(int id) async {
    await supabase.from('fuel_prices').delete().eq('id', id);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted fuel price override record ID: $id',
    );
  }

  // ── Global App Settings ────────────────────────────────────────────
  Future<Map<String, String>> getAppSettings() async {
    final response = await supabase.from('app_settings').select('key, value');
    Map<String, String> settings = {};
    for (var row in response) {
      settings[row['key']] = row['value']?.toString() ?? '';
    }
    return settings;
  }

  Future<void> updateAppSetting(String key, String value) async {
    // Upsert equivalent since we might insert newly
    final existing = await supabase
        .from('app_settings')
        .select('key')
        .eq('key', key);
    if (existing.isEmpty) {
      await supabase.from('app_settings').insert({'key': key, 'value': value});
    } else {
      await supabase
          .from('app_settings')
          .update({'value': value})
          .eq('key', key);
    }
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Updated system setting: $key',
    );
  }

  // ── Regions ───────────────────────────────────────────────────────
  Future<List<String>> getRegions() async {
    final response = await supabase
        .from('regions')
        .select('name')
        .order('name');
    return (response as List).map((r) => r['name'].toString()).toList();
  }

  Future<void> addRegion(String name) async {
    await supabase.from('regions').insert({'name': name});
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Added new region: $name',
    );
  }

  Future<void> deleteRegion(String name) async {
    await supabase.from('regions').delete().eq('name', name);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted region: $name',
    );
  }

  // ── IT Departments ─────────────────────────────────────────────────
  Future<List<String>> getITDepartments() async {
    final response = await supabase
        .from('it_departments')
        .select('name')
        .order('name');
    return (response as List).map((r) => r['name'].toString()).toList();
  }

  Future<void> addITDepartment(String name) async {
    await supabase.from('it_departments').insert({'name': name});
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Added new IT department: $name',
    );
  }

  Future<void> deleteITDepartment(String name) async {
    await supabase.from('it_departments').delete().eq('name', name);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted IT department: $name',
    );
  }

  // ── IT Companies (Company Types) ───────────────────────────────────
  Future<List<String>> getITCompanies() async {
    final response = await supabase
        .from('it_companies')
        .select('name')
        .order('name');
    return (response as List).map((r) => r['name'].toString()).toList();
  }

  Future<void> addITCompany(String name) async {
    await supabase.from('it_companies').insert({'name': name});
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Added new IT company type: $name',
    );
  }

  Future<void> deleteITCompany(String name) async {
    await supabase.from('it_companies').delete().eq('name', name);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted IT company type: $name',
    );
  }

  // ── App Version Management ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAppVersions({String? appType}) async {
    var query = supabase.from('app_versions').select('*');
    if (appType != null) {
      query = query.eq('app_type', appType);
    }
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createAppVersion(Map<String, dynamic> data) async {
    await supabase.from('app_versions').insert(data);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description:
          'Created new app version: ${data['version_code']} (${data['build_number']})',
      metadata: data,
    );
  }

  Future<void> updateAppVersion(int id, Map<String, dynamic> data) async {
    await supabase.from('app_versions').update(data).eq('id', id);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Updated app version ID: $id',
      metadata: data,
    );
  }

  Future<void> deleteAppVersion(int id) async {
    await supabase.from('app_versions').delete().eq('id', id);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted app version record ID: $id',
    );
  }

  // ── Mobile Notifications (Broadcasting) ───────────────────────────
  Future<void> sendMobileNotification({
    required String title,
    required String body,
    required String targetType,
  }) async {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['fullname'] ?? 'HO Admin';

    await supabase.from('mobile_notifications').insert({
      'title': title,
      'body': body,
      'target_type': targetType,
      'sender_name': userName,
    });

    // Also log this in the general activities table
    await logActivity(
      actionType: 'BROADCAST_NOTI',
      description: 'Sent broadcast notification: $title',
      userId: user?.id,
      userName: userName,
    );
  }

  Future<List<Map<String, dynamic>>> getMobileNotificationLogs() async {
    final response = await supabase
        .from('mobile_notifications')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteMobileNotification(String id) async {
    await supabase.from('mobile_notifications').delete().eq('id', id);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted broadcast notification record ID: $id',
    );
  }

  Future<void> clearMobileNotificationHistory() async {
    await supabase
        .from('mobile_notifications')
        .delete()
        .neq('title', '___DISALLOW_MATCH___'); // Delete all
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Cleared all broadcast notification history',
    );
  }

  // ── System Content Settings (Terms, Policy, Contact) ─────────────
  Future<List<Map<String, dynamic>>> getSystemSettings() async {
    final response = await supabase
        .from('system_settings')
        .select('*')
        .order('key');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateSystemSetting(String key, String value) async {
    await supabase
        .from('system_settings')
        .update({
          'value': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('key', key);

    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Updated system content: $key',
    );
  }

  // ── Points Settings ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getPointsSettings() async {
    final response = await supabase
        .from('points_settings')
        .select('*')
        .limit(1)
        .maybeSingle();

    if (response == null) {
      // Return defaults if somehow missing
      return {'point_expiry_days': 365, 'pipd': 1, 'points_per_liter': 1.0};
    }
    return response;
  }

  Future<void> updatePointsSettings({
    required int pointExpiryDays,
    required int pipd,
    required double pointsPerLiter,
  }) async {
    final settings = await getPointsSettings();
    final id = settings['id'];

    if (id != null) {
      await supabase
          .from('points_settings')
          .update({
            'point_expiry_days': pointExpiryDays,
            'pipd': pipd,
            'points_per_liter': pointsPerLiter,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } else {
      await supabase.from('points_settings').insert({
        'point_expiry_days': pointExpiryDays,
        'pipd': pipd,
        'points_per_liter': pointsPerLiter,
      });
    }

    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description:
          'Updated points settings: Expiry $pointExpiryDays days, PIPD $pipd, Rate $pointsPerLiter points/L',
    );
  }

  // ── Advertisement Management ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAdvertisements() async {
    final response = await supabase
        .from('advertisements')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createAdvertisement(Map<String, dynamic> data) async {
    await supabase.from('advertisements').insert(data);
    await logActivity(
      actionType: 'AD_MANAGEMENT',
      description: 'Created new advertisement',
      metadata: data,
    );
  }

  Future<void> updateAdvertisement(String id, Map<String, dynamic> data) async {
    await supabase.from('advertisements').update(data).eq('id', id);
    await logActivity(
      actionType: 'AD_MANAGEMENT',
      description: 'Updated advertisement ID: $id',
      metadata: data,
    );
  }

  Future<void> deleteAdvertisement(String id) async {
    await supabase.from('advertisements').delete().eq('id', id);
    await logActivity(
      actionType: 'AD_MANAGEMENT',
      description: 'Deleted advertisement record ID: $id',
    );
  }

  Future<String?> uploadAdImage(Uint8List bytes, String extension) async {
    final fileName = 'ads/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension'),
        );
    return supabase.storage.from('moonsun_assets').getPublicUrl(fileName);
  }

  // ── Intro Video Management ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getIntroVideos() async {
    final response = await supabase
        .from('intro_videos')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createIntroVideo(Map<String, dynamic> data) async {
    await supabase.from('intro_videos').insert(data);
    await logActivity(
      actionType: 'INTRO_VIDEO_MANAGEMENT',
      description: 'Created new intro video',
      metadata: data,
    );
  }

  Future<void> updateIntroVideo(String id, Map<String, dynamic> data) async {
    await supabase.from('intro_videos').update(data).eq('id', id);
    await logActivity(
      actionType: 'INTRO_VIDEO_MANAGEMENT',
      description: 'Updated intro video ID: $id',
      metadata: data,
    );
  }

  Future<void> deleteIntroVideo(String id) async {
    await supabase.from('intro_videos').delete().eq('id', id);
    await logActivity(
      actionType: 'INTRO_VIDEO_MANAGEMENT',
      description: 'Deleted intro video record ID: $id',
    );
  }

  Future<String?> uploadIntroVideo(Uint8List bytes, String extension) async {
    final fileName =
        'intro/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'video/$extension'),
        );
    return supabase.storage.from('moonsun_assets').getPublicUrl(fileName);
  }

  Future<String?> uploadIntroThumbnail(
    Uint8List bytes,
    String extension,
  ) async {
    final fileName =
        'intro/thumbs/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await supabase.storage
        .from('moonsun_assets')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension'),
        );
    return supabase.storage.from('moonsun_assets').getPublicUrl(fileName);
  }

  // ── Customer Feedback Monitoring ─────────────────────────────────
  Future<List<Map<String, dynamic>>> getCustomerFeedback({
    int limit = 100,
    String? stationId,
    DateTime? startDate,
    DateTime? endDate,
    String? invoiceNo,
    String? memberName,
  }) async {
    var query = supabase
        .from('fuel_transactions')
        .select('*, profiles(full_name, phone_number)')
        .not('customer_rating', 'is', null);

    if (stationId != null && stationId.isNotEmpty && stationId != 'ALL') {
      query = query.eq('station_id', stationId);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toUtc().toIso8601String());
    }

    if (endDate != null) {
      // Set to end of day
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      query = query.lte('created_at', end.toUtc().toIso8601String());
    }

    if (invoiceNo != null && invoiceNo.isNotEmpty) {
      query = query.ilike('voc_no', '%$invoiceNo%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    var data = List<Map<String, dynamic>>.from(response);

    // Member search (fuzzy search on name/phone in memory if needed,
    // or we could try filtering on joined column if Supabase version supports it easily)
    if (memberName != null && memberName.isNotEmpty) {
      data = data.where((item) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        final name = (profile?['full_name'] as String?)?.toLowerCase() ?? '';
        final phone =
            (profile?['phone_number'] as String?)?.toLowerCase() ?? '';
        final search = memberName.toLowerCase();
        return name.contains(search) || phone.contains(search);
      }).toList();
    }

    return data;
  }

  RealtimeChannel subscribeToFeedback(
    void Function(PostgresChangeEvent event, Map<String, dynamic> record)
    callback,
  ) {
    final channel = supabase.channel('public:fuel_transactions_feedback');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'fuel_transactions',
          callback: (payload) {
            // Only trigger if rating or remark was updated
            if (payload.newRecord['customer_rating'] != null) {
              callback(payload.eventType, payload.newRecord);
            }
          },
        )
        .subscribe();

    return channel;
  }

  // ── GPS Bowser Management ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBowserGpsList() async {
    final response = await supabase
        .from('ms_bowser_gps')
        .select('*')
        .order('id', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createBowserGps(Map<String, dynamic> data) async {
    await supabase.from('ms_bowser_gps').insert(data);
    await logActivity(
      actionType: 'GPS_BOWSER_CREATE',
      description: 'Created new GPS Bowser: ${data['device_name']}',
      metadata: data,
    );
  }

  Future<void> updateBowserGps(int id, Map<String, dynamic> data) async {
    await supabase.from('ms_bowser_gps').update(data).eq('id', id);
    await logActivity(
      actionType: 'GPS_BOWSER_UPDATE',
      description: 'Updated GPS Bowser ID: $id',
      metadata: data,
    );
  }

  Future<void> deleteBowserGps(int id) async {
    await supabase.from('ms_bowser_gps').delete().eq('id', id);
    await logActivity(
      actionType: 'GPS_BOWSER_DELETE',
      description: 'Deleted GPS Bowser ID: $id',
    );
  }

  // ── IT Assets Management ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getITAssets() async {
    final response = await supabase
        .from('it_assets')
        .select('*')
        .order('asset_code', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> upsertITAsset(Map<String, dynamic> data) async {
    await supabase.from('it_assets').upsert(data);
    await logActivity(
      actionType: 'IT_ASSET_UPSERT',
      description: 'Upserted IT Asset: ${data['asset_code']} - ${data['name']}',
      metadata: data,
    );
  }

  Future<void> upsertITAssets(List<Map<String, dynamic>> dataList) async {
    await supabase.from('it_assets').upsert(dataList, onConflict: 'asset_code');
    await logActivity(
      actionType: 'IT_ASSETS_IMPORT',
      description: 'Imported ${dataList.length} IT Assets via Excel/CSV',
    );
  }

  Future<Map<String, dynamic>> createITAsset(Map<String, dynamic> data) async {
    final response = await supabase.from('it_assets').insert(data).select().single();
    await logActivity(
      actionType: 'IT_ASSET_CREATE',
      description: 'Created IT Asset: ${data['asset_code']} - ${data['name']}',
      metadata: data,
    );
    return response;
  }

  Future<void> deleteITAsset(String id) async {
    await supabase.from('it_assets').delete().eq('id', id);
    await logActivity(
      actionType: 'IT_ASSET_DELETE',
      description: 'Deleted IT Asset ID: $id',
    );
  }

  // ── IT Asset Components Management ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getAssetComponents(String assetId) async {
    final response = await supabase
        .from('asset_components')
        .select('*')
        .eq('asset_id', assetId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> upsertAssetComponent(Map<String, dynamic> data) async {
    await supabase.from('asset_components').upsert(data);
    await logActivity(
      actionType: 'IT_ASSET_COMPONENT_UPSERT',
      description: 'Upserted component: ${data['component_type']} - ${data['model']}',
      metadata: data,
    );
  }

  Future<void> upsertAssetComponents(List<Map<String, dynamic>> dataList) async {
    await supabase.from('asset_components').upsert(dataList);
    await logActivity(
      actionType: 'IT_ASSET_COMPONENTS_BULK_UPSERT',
      description: 'Bulk upserted ${dataList.length} components for IT Asset ID: ${dataList.isNotEmpty ? dataList[0]['asset_id'] : ''}',
    );
  }

  Future<void> swapAssetComponent(String oldComponentId, Map<String, dynamic> newComponentData) async {
    await supabase.from('asset_components').update({
      'status': 'Replaced',
      'replaced_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', oldComponentId);

    await supabase.from('asset_components').insert(newComponentData);

    await logActivity(
      actionType: 'IT_ASSET_COMPONENT_SWAP',
      description: 'Swapped component: Replaced ID $oldComponentId with new ${newComponentData['component_type']} - ${newComponentData['model']}',
      metadata: {'old_id': oldComponentId, 'new': newComponentData},
    );
  }

  Future<void> deleteAssetComponent(String id) async {
    await supabase.from('asset_components').delete().eq('id', id);
    await logActivity(
      actionType: 'IT_ASSET_COMPONENT_DELETE',
      description: 'Deleted Asset Component ID: $id',
    );
  }

  // ── IT Ticket Support ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getITTickets() async {
    final response = await supabase
        .from('it_complaints')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateITTicketStatus(String id, String status, String? remarks) async {
    final Map<String, dynamic> data = {
      'status': status,
      'remarks': remarks,
    };
    if (status == 'Resolved') {
      data['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await supabase.from('it_complaints').update(data).eq('id', id);
    await logActivity(
      actionType: 'IT_TICKET_UPDATE',
      description: 'Updated IT Ticket ID: $id to $status',
      metadata: data,
    );
  }

  // ── Assets Transfer ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAssetTransfers() async {
    final response = await supabase
        .from('asset_transfers')
        .select('*, it_assets(name, asset_code)')
        .order('transfer_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createAssetTransfer(Map<String, dynamic> data) async {
    await supabase.from('asset_transfers').insert(data);
    
    // Also update asset's current status and assigned location/user details
    final assetId = data['asset_id'];
    await supabase.from('it_assets').update({
      'assigned_user': data['to_user'],
      'assigned_station': data['to_location'],
      'status': 'Transferred',
    }).eq('id', assetId);

    await logActivity(
      actionType: 'ASSET_TRANSFER_CREATE',
      description: 'Created Asset Transfer for asset ID: $assetId',
      metadata: data,
    );
  }

  Future<void> deleteAssetTransfer(String id) async {
    await supabase.from('asset_transfers').delete().eq('id', id);
    await logActivity(
      actionType: 'ASSET_TRANSFER_DELETE',
      description: 'Deleted Asset Transfer ID: $id',
    );
  }

  // ── Assets Maintenance ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAssetMaintenances() async {
    final response = await supabase
        .from('asset_maintenances')
        .select('*, it_assets(name, asset_code)')
        .order('maintenance_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createAssetMaintenance(Map<String, dynamic> data) async {
    await supabase.from('asset_maintenances').insert(data);
    
    // Update asset status depending on maintenance status
    final assetId = data['asset_id'];
    final status = data['status'];
    if (status == 'In Progress') {
      await supabase.from('it_assets').update({'status': 'Under Repair'}).eq('id', assetId);
    } else if (status == 'Completed') {
      await supabase.from('it_assets').update({'status': 'Active'}).eq('id', assetId);
    }

    await logActivity(
      actionType: 'ASSET_MAINTENANCE_CREATE',
      description: 'Logged Maintenance for asset ID: $assetId',
      metadata: data,
    );
  }

  Future<void> deleteAssetMaintenance(String id) async {
    await supabase.from('asset_maintenances').delete().eq('id', id);
    await logActivity(
      actionType: 'ASSET_MAINTENANCE_DELETE',
      description: 'Deleted Asset Maintenance ID: $id',
    );
  }

  // ── Assets Request ────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAssetRequests() async {
    final response = await supabase
        .from('asset_requests')
        .select('*, it_assets(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createAssetRequest(Map<String, dynamic> data) async {
    await supabase.from('asset_requests').insert(data);
    await logActivity(
      actionType: 'ASSET_REQUEST_CREATE',
      description: 'Created Asset Request: ${data['request_no']}',
      metadata: data,
    );
  }

  Future<void> updateAssetRequestStatus(
    String id,
    String status,
    String? remarks, {
    String? assetId,
    List<dynamic>? approvalHistory,
  }) async {
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['fullname'] ?? 'HO Admin';
    final Map<String, dynamic> data = {
      'status': status,
      'remarks': remarks,
      'approved_by': userName,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
      if (assetId != null) 'asset_id': assetId,
      if (approvalHistory != null) 'approval_history': approvalHistory,
    };
    await supabase.from('asset_requests').update(data).eq('id', id);
    await logActivity(
      actionType: 'ASSET_REQUEST_UPDATE',
      description: 'Updated Asset Request ID: $id to $status',
      metadata: data,
    );
  }

  // ── IT Asset Categories ─────────────────────────────────────────────
  Future<List<String>> getITAssetCategories() async {
    final response = await supabase
        .from('it_asset_categories')
        .select('name')
        .order('name');
    return (response as List).map((r) => r['name'].toString()).toList();
  }

  Future<void> addITAssetCategory(String name) async {
    await supabase.from('it_asset_categories').insert({'name': name});
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Added new IT asset category: $name',
    );
  }

  Future<void> deleteITAssetCategory(String name) async {
    await supabase.from('it_asset_categories').delete().eq('name', name);
    await logActivity(
      actionType: 'SYSTEM_CONFIG',
      description: 'Deleted IT asset category: $name',
    );
  }

  // ── Comparison Report Data Fetching & Aggregation ───────────────────
  Future<Map<String, dynamic>> getComparisonReport({
    required int year,
    required int month,
    String? stationId,
  }) async {
    // 1. Calculate dates
    final selectedStart = DateTime(year, month, 1);
    final selectedEnd = (month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1)).subtract(const Duration(seconds: 1));

    final prevYear = month == 1 ? year - 1 : year;
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevStart = DateTime(prevYear, prevMonth, 1);
    final prevEnd = DateTime(prevYear, prevMonth + 1, 1).subtract(const Duration(seconds: 1));

    final yoyStart = DateTime(year - 2, 1, 1);
    final yoyEnd = DateTime(year, 12, 31, 23, 59, 59);

    // 2. Fetch Selected Month Daily
    var qSelected = supabase.from('fuel_transactions')
        .select('created_at, liters, sale_liter, amount_mmk')
        .gte('created_at', selectedStart.toUtc().toIso8601String())
        .lte('created_at', selectedEnd.toUtc().toIso8601String());
    if (stationId != null && stationId.isNotEmpty && stationId != 'ALL') {
      qSelected = qSelected.eq('station_id', stationId);
    }
    final selectedRes = await qSelected;

    // 3. Fetch Prev Month Daily
    var qPrev = supabase.from('fuel_transactions')
        .select('created_at, liters, sale_liter, amount_mmk')
        .gte('created_at', prevStart.toUtc().toIso8601String())
        .lte('created_at', prevEnd.toUtc().toIso8601String());
    if (stationId != null && stationId.isNotEmpty && stationId != 'ALL') {
      qPrev = qPrev.eq('station_id', stationId);
    }
    final prevRes = await qPrev;

    // 4. Fetch YoY Monthly
    var qYoy = supabase.from('fuel_transactions')
        .select('created_at, liters, sale_liter, amount_mmk')
        .gte('created_at', yoyStart.toUtc().toIso8601String())
        .lte('created_at', yoyEnd.toUtc().toIso8601String());
    if (stationId != null && stationId.isNotEmpty && stationId != 'ALL') {
      qYoy = qYoy.eq('station_id', stationId);
    }
    final yoyRes = await qYoy;

    // 5. Aggregate Selected Month Daily
    final Map<int, Map<String, double>> selectedDailyMap = {};
    for (var row in selectedRes) {
      final dt = DateTime.parse(row['created_at']).toLocal();
      final day = dt.day;
      final liters = (row['liters'] ?? row['sale_liter'] ?? 0.0) as num;
      final amount = (row['amount_mmk'] ?? 0.0) as num;

      selectedDailyMap[day] ??= {'TotalLiter': 0.0, 'TotalAmount': 0.0};
      selectedDailyMap[day]!['TotalLiter'] = selectedDailyMap[day]!['TotalLiter']! + liters.toDouble();
      selectedDailyMap[day]!['TotalAmount'] = selectedDailyMap[day]!['TotalAmount']! + amount.toDouble();
    }

    // 6. Aggregate Prev Month Daily
    final Map<int, Map<String, double>> prevDailyMap = {};
    for (var row in prevRes) {
      final dt = DateTime.parse(row['created_at']).toLocal();
      final day = dt.day;
      final liters = (row['liters'] ?? row['sale_liter'] ?? 0.0) as num;
      final amount = (row['amount_mmk'] ?? 0.0) as num;

      prevDailyMap[day] ??= {'TotalLiter': 0.0, 'TotalAmount': 0.0};
      prevDailyMap[day]!['TotalLiter'] = prevDailyMap[day]!['TotalLiter']! + liters.toDouble();
      prevDailyMap[day]!['TotalAmount'] = prevDailyMap[day]!['TotalAmount']! + amount.toDouble();
    }

    // 7. Aggregate YoY Monthly
    final Map<String, Map<String, double>> yoyMonthlyMap = {};
    for (var row in yoyRes) {
      final dt = DateTime.parse(row['created_at']).toLocal();
      final key = '${dt.year}-${dt.month}';
      final liters = (row['liters'] ?? row['sale_liter'] ?? 0.0) as num;
      final amount = (row['amount_mmk'] ?? 0.0) as num;

      yoyMonthlyMap[key] ??= {'TotalLiter': 0.0, 'TotalAmount': 0.0};
      yoyMonthlyMap[key]!['TotalLiter'] = yoyMonthlyMap[key]!['TotalLiter']! + liters.toDouble();
      yoyMonthlyMap[key]!['TotalAmount'] = yoyMonthlyMap[key]!['TotalAmount']! + amount.toDouble();
    }

    final List<Map<String, dynamic>> selectedMonthDailyList = [];
    selectedDailyMap.forEach((day, vals) {
      selectedMonthDailyList.add({
        'SaleDay': day,
        'TotalLiter': vals['TotalLiter'],
        'TotalAmount': vals['TotalAmount'],
      });
    });

    final List<Map<String, dynamic>> prevMonthDailyList = [];
    prevDailyMap.forEach((day, vals) {
      prevMonthDailyList.add({
        'SaleDay': day,
        'TotalLiter': vals['TotalLiter'],
        'TotalAmount': vals['TotalAmount'],
      });
    });

    final List<Map<String, dynamic>> yoyList = [];
    yoyMonthlyMap.forEach((key, vals) {
      final parts = key.split('-');
      yoyList.add({
        'SaleYear': int.parse(parts[0]),
        'SaleMonth': int.parse(parts[1]),
        'TotalLiter': vals['TotalLiter'],
        'TotalAmount': vals['TotalAmount'],
      });
    });

    return {
      'yoy': yoyList,
      'selectedMonthDaily': selectedMonthDailyList,
      'prevMonthDaily': prevMonthDailyList,
    };
  }
}
