import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyLoginTime = 'login_time';
  static const String _keyUsername = 'login_username';
  static const String _keyUserId = 'login_user_id';

  static Future<void> saveSession({required String username, required int userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyLoginTime, DateTime.now().toIso8601String());
    await prefs.setString(_keyUsername, username);
    await prefs.setInt(_keyUserId, userId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyLoginTime);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyUserId);
  }

  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return false;

    final loginTimeStr = prefs.getString(_keyLoginTime);
    if (loginTimeStr == null) return false;

    try {
      final loginTime = DateTime.parse(loginTimeStr);
      final difference = DateTime.now().difference(loginTime);
      // Valid if less than 24 hours
      if (difference.inHours < 24) {
        return true;
      }
    } catch (_) {}

    // Session expired or invalid
    await clearSession();
    return false;
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }
}
