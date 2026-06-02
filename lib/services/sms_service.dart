import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ms_dashboard/config.dart';
import 'package:flutter/foundation.dart';

class SMSService {
  static const String _baseUrl = 'https://v3.smspoh.com/api/rest/send';

  /// Sends an SMS to a single recipient using SMSPoh.
  /// [to] should be in international format (e.g., 959...)
  Future<Map<String, dynamic>> sendSMS({
    required String to,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer ${Config.smsPohToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': to,
          'message': message,
          'from': Config.smsPohSenderName,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == true) {
        return {'status': 'success', 'data': result};
      } else {
        return {
          'status': 'error',
          'message': result['message'] ?? 'Failed to send SMS',
        };
      }
    } catch (e) {
      debugPrint("SMS Error: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Sends bulk SMS to multiple recipients.
  /// Note: Depending on volumes, this might need batching logic.
  Future<List<Map<String, dynamic>>> sendBulkSMS({
    required List<String> recipients,
    required String message,
  }) async {
    List<Map<String, dynamic>> results = [];
    for (String phone in recipients) {
      final res = await sendSMS(to: phone, message: message);
      results.add({'phone': phone, ...res});
    }
    return results;
  }
}
