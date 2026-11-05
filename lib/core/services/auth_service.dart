import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyAccessCode = 'access_code';
  static const String _keyUserId = 'user_id';
  static const String _keyAuthToken = 'auth_token';

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyAccessCode);
    return code != null && code.isNotEmpty;
  }

  Future<String?> getAccessCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessCode);
  }

  Future<void> saveAccessCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessCode, code);
  }

  Future<void> saveAuthData({
    required String userId,
    required String authToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyAuthToken, authToken);
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessCode);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyAuthToken);
  }
}
