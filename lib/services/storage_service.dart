import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyUsername = 'username';
  static const _keyPassword = 'password';
  static const _keyServer = 'server';

  static Future<void> saveCredentials({
    required String username,
    required String password,
    required String server,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyPassword, password);
    await prefs.setString(_keyServer, server);
  }

  static Future<Map<String, String>?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    final password = prefs.getString(_keyPassword);
    final server = prefs.getString(_keyServer);
    if (username == null || password == null || server == null) return null;
    return {'username': username, 'password': password, 'server': server};
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyServer);
  }
}
