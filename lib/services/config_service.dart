import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de configuración remota.
/// La URL del servidor se lee desde:
///   https://raw.githubusercontent.com/kdaniela90/todo-en-uno-tv/main/config.json
///
/// Para cambiar el servidor, edita config.json en GitHub y todos los
/// dispositivos lo recibirán la próxima vez que abran la app.
class ConfigService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/kdaniela90/todo-en-uno-tv/main/config.json';
  static const String _prefKey = 'cached_server_url';
  static const String _defaultServer = 'http://allinonestream.fans:8080';

  static String _serverUrl = _defaultServer;

  /// URL del servidor Xtream activa (actualizada desde config.json).
  static String get serverUrl => _serverUrl;

  /// Llamar una vez en main() antes de runApp().
  static Future<void> load() async {
    // 1. Cargar valor en caché (funciona sin conexión a internet)
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverUrl = prefs.getString(_prefKey) ?? _defaultServer;
    } catch (_) {
      _serverUrl = _defaultServer;
    }

    // 2. Intentar obtener valor actualizado desde GitHub
    try {
      final response = await http
          .get(Uri.parse(_configUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final newUrl = json['server_url'] as String?;
        if (newUrl != null && newUrl.isNotEmpty) {
          _serverUrl = newUrl;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKey, newUrl);
        }
      }
    } catch (_) {
      // Sin internet: se usa el valor en caché
    }
  }
}
