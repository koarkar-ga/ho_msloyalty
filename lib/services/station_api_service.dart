import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ms_dashboard/config.dart';
import 'package:intl/intl.dart';

/// Service for communicating with the Station App REST API
/// Base URL: http://ho.moonsungroup.com:5000/api
///
/// The API routes calls to a per-station MSSQL database using the
/// [stationId] query parameter (e.g. ?stationId=M001).
/// When stationId is null/empty, the default database from config.ini is used.
class StationApiService {
  static const String _baseUrl = Config.stationApiBaseUrl;

  // Date format expected by the API: "yyyy-MM-dd HH:mm:ss"
  static final DateFormat _apiFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  // ─── HTTP helpers ──────────────────────────────────────────────────────────

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Parses a response body that may be:
  ///  - a JSON array
  ///  - newline-delimited JSON objects (NDJSON)
  static List<Map<String, dynamic>> _parseResponse(String body) {
    final trimmed = body.trim();
    if (trimmed.startsWith('[')) {
      // Normal JSON array
      final decoded = jsonDecode(trimmed) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    // NDJSON (one JSON object per line)
    final List<Map<String, dynamic>> results = [];
    for (final line in trimmed.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      try {
        results.add(Map<String, dynamic>.from(jsonDecode(l) as Map));
      } catch (_) {
        // skip malformed lines
      }
    }
    return results;
  }

  static Uri _buildUri(String path, Map<String, String?> params) {
    final cleaned = Map<String, String>.fromEntries(
      params.entries
          .where((e) => e.value != null && e.value!.isNotEmpty)
          .map((e) => MapEntry(e.key, e.value!)),
    );
    return Uri.parse('$_baseUrl$path').replace(queryParameters: cleaned);
  }

  // ─── Health check ──────────────────────────────────────────────────────────

  /// Returns true if the station's database is reachable.
  Future<Map<String, dynamic>> healthCheck({String? stationId}) async {
    try {
      final uri = _buildUri('/health', {'stationId': stationId});
      final response =
          await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
      return {'status': 'offline', 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'status': 'offline', 'error': e.toString()};
    }
  }

  // ─── Fuel Types ────────────────────────────────────────────────────────────

  /// GET /api/fueltypes?stationId=
  /// Returns: [{ FuelTypeCode, FuelTypeName, BuyPrice, SalePrice, maincode }]
  Future<List<Map<String, dynamic>>> getFuelTypes({String? stationId}) async {
    final uri = _buildUri('/fueltypes', {'stationId': stationId});
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }
    throw Exception('getFuelTypes failed: HTTP ${response.statusCode} — ${response.body}');
  }

  // ─── Sale Types ────────────────────────────────────────────────────────────

  /// GET /api/saletypes?stationId=
  /// Returns: [{ Sale_Type_ID, Sale_Type_name }]
  Future<List<Map<String, dynamic>>> getSaleTypes({String? stationId}) async {
    final uri = _buildUri('/saletypes', {'stationId': stationId});
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }
    throw Exception('getSaleTypes failed: HTTP ${response.statusCode}');
  }

  // ─── Summary Data (Today) ──────────────────────────────────────────────────

  /// GET /api/summary/data?stationId=
  /// Returns: { totalAmount, totalLiter, totalTransactions }
  Future<Map<String, dynamic>> getSummaryData({String? stationId}) async {
    final uri = _buildUri('/summary/data', {'stationId': stationId});
    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw Exception('getSummaryData failed: HTTP ${response.statusCode}');
  }

  // ─── Sales Search ──────────────────────────────────────────────────────────

  /// GET /api/sales/search?startDate=&endDate=&stationId=
  ///
  /// [startDate] / [endDate] — DateTime values (sent as "yyyy-MM-dd HH:mm:ss")
  /// [stationId] — MSSQL database name for this station (e.g. "M001")
  ///
  /// Returns: [{ VocNo, S_Date, Vehical_No, Category, SALELITER, TotalPrice,
  ///             FuelTypeName, Sale_Type_name, TodayPrice, Nozzle, Pump,
  ///             PumpName, MeterVolume, MeterValue, CashierName, SaleCounter,
  ///             SaleGallon, discount, AfterTax, ePayment }]
  Future<List<Map<String, dynamic>>> searchSales({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    final uri = _buildUri('/sales/search', {
      'startDate': _apiFmt.format(startDate),
      'endDate': _apiFmt.format(endDate),
      'stationId': stationId,
    });

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }
    throw Exception('searchSales failed: HTTP ${response.statusCode} — ${response.body}');
  }

  // ─── Sales Detail Search ──────────────────────────────────────────────────

  /// GET /api/salesdetail/search?startDate=&endDate=&stationId=
  /// Same field set as searchSales but includes price from LatestPrices.
  Future<List<Map<String, dynamic>>> searchSalesDetail({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    final uri = _buildUri('/salesdetail/search', {
      'startDate': _apiFmt.format(startDate),
      'endDate': _apiFmt.format(endDate),
      'stationId': stationId,
    });

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }
    throw Exception('searchSalesDetail failed: HTTP ${response.statusCode}');
  }

  // ─── Comparison Report ─────────────────────────────────────────────────────

  /// GET /api/reports/comparison?year=&month=&stationId=
  /// Returns: { year, month, prevYear, prevMonth, yoy[], selectedMonthDaily[], prevMonthDaily[] }
  Future<Map<String, dynamic>> getComparisonReport({
    required int year,
    required int month,
    String? stationId,
  }) async {
    final uri = _buildUri('/reports/comparison', {
      'year': year.toString(),
      'month': month.toString(),
      'stationId': stationId,
    });

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }
    throw Exception('getComparisonReport failed: HTTP ${response.statusCode}');
  }

  // ─── Stock Ledger ──────────────────────────────────────────────────────────

  /// GET /api/reports/stock-ledger?startDate=&endDate=&stationId=
  Future<List<Map<String, dynamic>>> getStockLedger({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    final uri = _buildUri('/reports/stock-ledger', {
      'startDate': _apiFmt.format(startDate),
      'endDate': _apiFmt.format(endDate),
      'stationId': stationId,
    });

    final response =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }
    throw Exception('getStockLedger failed: HTTP ${response.statusCode}');
  }
}
