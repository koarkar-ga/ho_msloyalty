import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class TracksolidService {
  static const String baseApiUrl = 'https://hk-open.tracksolidpro.com/route/rest';
  static const String appKey = '8FB345B8693CCD00057674794E1FCBD2339A22A4105B6558';
  static const String appSecret = '246c825bbb49486cbdcb0d5c88218135';
  static const String userId = 'moonsun2024';
  static const String userPwdMd5 = 'f39d4e523b3b01ad7b29969c075501ad';

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  // Sign helper function
  String _generateSignature(Map<String, String> params) {
    // Sort keys alphabetically
    final sortedKeys = params.keys.toList()..sort();
    
    // Concatenate key-value pairs without '=' or ','
    final buffer = StringBuffer();
    for (var key in sortedKeys) {
      buffer.write(key);
      buffer.write(params[key]);
    }
    
    // sign = MD5(appSecret + paramString + appSecret)
    final signString = '$appSecret${buffer.toString()}$appSecret';
    final signHash = md5.convert(utf8.encode(signString)).toString().toUpperCase();
    return signHash;
  }

  // Get current timestamp in yyyy-MM-dd HH:mm:ss in UTC
  String _getTimestamp() {
    final now = DateTime.now().toUtc();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  Future<String?> getAccessToken() async {
    // 1. Return cached static token if valid
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    // 2. On Web, check sessionStorage to survive page reloads
    if (kIsWeb) {
      try {
        final cachedToken = html.window.sessionStorage['tracksolid_access_token'];
        final cachedExpiryStr = html.window.sessionStorage['tracksolid_token_expiry'];
        if (cachedToken != null && cachedExpiryStr != null) {
          final cachedExpiry = DateTime.parse(cachedExpiryStr);
          if (DateTime.now().isBefore(cachedExpiry)) {
            _accessToken = cachedToken;
            _tokenExpiry = cachedExpiry;
            return _accessToken;
          }
        }
      } catch (_) {}
    }

    final timestamp = _getTimestamp();
    final Map<String, String> params = {
      'method': 'jimi.oauth.token.get',
      'timestamp': timestamp,
      'app_key': appKey,
      'sign_method': 'md5',
      'v': '1.0',
      'format': 'json',
      'user_id': userId,
      'user_pwd_md5': userPwdMd5,
      'expires_in': '7200',
    };

    params['sign'] = _generateSignature(params);

    try {
      final response = await http.post(
        Uri.parse(baseApiUrl).replace(queryParameters: params),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['result'] != null) {
          final result = data['result'];
          _accessToken = result['accessToken'] ?? result['access_token'];
          final expiresIn = result['expiresIn'] ?? result['expires_in'] ?? 7200;
          _tokenExpiry = DateTime.now().add(Duration(seconds: (expiresIn as int) - 60)); // Buffer of 60s
          
          // Save to sessionStorage on Web
          if (kIsWeb && _accessToken != null) {
            try {
              html.window.sessionStorage['tracksolid_access_token'] = _accessToken!;
              html.window.sessionStorage['tracksolid_token_expiry'] = _tokenExpiry!.toIso8601String();
            } catch (_) {}
          }
          
          return _accessToken;
        } else {
          print('Tracksolid Token Error: ${data['message']} (Code: ${data['code']})');
        }
      } else {
        print('Tracksolid API Request Failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Tracksolid API Connection Error: $e');
    }
    return null;
  }

  // Get locations for multiple IMEIs
  Future<List<Map<String, dynamic>>> getLocations(List<String> imeis) async {
    if (imeis.isEmpty) return [];

    final token = await getAccessToken();
    if (token == null) {
      print('Tracksolid Error: Cannot obtain access token.');
      return [];
    }

    // Split IMEIs into chunks of 100 as recommended
    List<Map<String, dynamic>> allLocations = [];
    final chunkSize = 100;
    
    for (var i = 0; i < imeis.length; i += chunkSize) {
      final end = (i + chunkSize < imeis.length) ? i + chunkSize : imeis.length;
      final chunk = imeis.sublist(i, end);
      final imeiString = chunk.join(',');

      final timestamp = _getTimestamp();
      final Map<String, String> params = {
        'method': 'jimi.device.location.get',
        'timestamp': timestamp,
        'app_key': appKey,
        'sign_method': 'md5',
        'v': '1.0',
        'format': 'json',
        'access_token': token,
        'imeis': imeiString,
      };

      params['sign'] = _generateSignature(params);

      try {
        final response = await http.post(
          Uri.parse(baseApiUrl).replace(queryParameters: params),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['code'] == 0 && data['result'] != null) {
            final List<dynamic> resultList = data['result'];
            for (var item in resultList) {
              if (item is Map) {
                allLocations.add(Map<String, dynamic>.from(item));
              }
            }
          } else {
            print('Tracksolid Location Error: ${data['message']} (Code: ${data['code']})');
          }
        }
      } catch (e) {
        print('Tracksolid Location API Connection Error: $e');
      }
    }

    return allLocations;
  }

  // Get all devices under the account and all sub-accounts recursively
  Future<List<Map<String, dynamic>>> getDeviceList() async {
    final token = await getAccessToken();
    if (token == null) {
      print('Tracksolid Error: Cannot obtain access token.');
      return [];
    }

    // 1. Get all child accounts
    final timestamp = _getTimestamp();
    final Map<String, String> childParams = {
      'method': 'jimi.user.child.list',
      'timestamp': timestamp,
      'app_key': appKey,
      'sign_method': 'md5',
      'v': '1.0',
      'format': 'json',
      'access_token': token,
      'target': userId,
    };
    childParams['sign'] = _generateSignature(childParams);

    Map<String, String> accountNames = {
      userId: 'Root Account',
    };

    try {
      final response = await http.post(
        Uri.parse(baseApiUrl).replace(queryParameters: childParams),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['result'] != null) {
          final List<dynamic> resultList = data['result'];
          for (var item in resultList) {
            if (item is Map && item['account'] != null) {
              final acc = item['account'].toString();
              final name = item['name']?.toString() ?? acc;
              accountNames[acc] = name;
            }
          }
        } else {
          print('Tracksolid Child Accounts Error: ${data['message']} (Code: ${data['code']})');
        }
      }
    } catch (e) {
      print('Tracksolid Child Accounts API Connection Error: $e');
    }

    // 2. Fetch devices for each account in parallel
    List<Map<String, dynamic>> allDevices = [];
    final List<Future<List<Map<String, dynamic>>>> futures = [];

    for (var acc in accountNames.keys) {
      futures.add(_getDevicesForSingleAccount(token, acc, accountNames[acc]!));
    }

    try {
      final results = await Future.wait(futures);
      for (var deviceList in results) {
        allDevices.addAll(deviceList);
      }
    } catch (e) {
      print('Tracksolid Parallel Device Fetch Error: $e');
    }

    return allDevices;
  }

  Future<List<Map<String, dynamic>>> _getDevicesForSingleAccount(String token, String account, String displayName) async {
    final timestamp = _getTimestamp();
    final Map<String, String> params = {
      'method': 'jimi.user.device.list',
      'timestamp': timestamp,
      'app_key': appKey,
      'sign_method': 'md5',
      'v': '1.0',
      'format': 'json',
      'access_token': token,
      'target': account,
    };

    params['sign'] = _generateSignature(params);

    try {
      final response = await http.post(
        Uri.parse(baseApiUrl).replace(queryParameters: params),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 0 && data['result'] != null) {
          final List<dynamic> resultList = data['result'];
          return resultList.map((item) {
            final map = Map<String, dynamic>.from(item);
            map['subAccount'] = account;
            map['subAccountName'] = displayName;
            return map;
          }).toList();
        }
      }
    } catch (e) {
      print('Tracksolid Error fetching devices for account $account: $e');
    }
    return [];
  }
}
