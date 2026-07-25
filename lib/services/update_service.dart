import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// ─── Modelo ───────────────────────────────────────────────────────────────────
class AppUpdate {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String releaseNotes;

  const AppUpdate({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory AppUpdate.fromJson(Map<String, dynamic> j) => AppUpdate(
    versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
    versionName: j['versionName'] as String? ?? '',
    downloadUrl: j['downloadUrl'] as String? ?? '',
    releaseNotes: j['releaseNotes'] as String? ?? '',
  );
}

// ─── Servicio ─────────────────────────────────────────────────────────────────
class UpdateService {
  static const _versionBaseUrl =
      'https://raw.githubusercontent.com/kdaniela90/todo-en-uno-tv/main/version.json';

  static const _channel = MethodChannel('com.todoenuno.tv/update');

  // Progreso de descarga activa (0.0 – 1.0)
  static double _dlProgress = 0.0;
  static double get dlProgress => _dlProgress;

  // URL con cache-busting para evitar que el CDN de GitHub sirva versión antigua
  static String get _versionUrl {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$_versionBaseUrl?t=$ts';
  }

  // ── Versión instalada (via canal nativo) ─────────────────────────────────
  static Future<int> getInstalledVersionCode() async {
    try {
      final v = await _channel.invokeMethod<int>('getVersionCode');
      return v ?? 1;
    } catch (_) {
      return 1;
    }
  }

  // ── Permiso para instalar APKs ────────────────────────────────────────────
  /// Devuelve true si el permiso ya está concedido (o no es necesario en esta versión de Android).
  static Future<bool> canInstallPackages() async {
    try {
      final result = await _channel.invokeMethod<bool>('canInstallPackages');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Abre la pantalla de Ajustes donde el usuario puede conceder el permiso.
  static Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod('requestInstallPermission');
    } catch (_) {}
  }

  // ── Verificar actualización ───────────────────────────────────────────────
  /// Devuelve un [AppUpdate] si hay versión más nueva, o null si ya está al día.
  static Future<AppUpdate?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final update = AppUpdate.fromJson(json);

      final installed = await getInstalledVersionCode();
      if (update.versionCode <= installed) return null;

      return update;
    } catch (_) {
      return null;
    }
  }

  // ── Descargar APK ─────────────────────────────────────────────────────────
  /// Descarga el APK y devuelve la ruta local, o null si hubo error.
  static Future<String?> downloadApk(
    AppUpdate update, {
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    _dlProgress = 0.0;
    onProgress?.call(0.0);

    final client = http.Client();
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/teutv_update.apk';

      final request = http.Request('GET', Uri.parse(update.downloadUrl))
        ..headers['User-Agent'] = 'TodoEnUnoTV-Updater';

      final response = await client.send(request);

      if (response.statusCode != 200) {
        onError?.call('Error del servidor (${response.statusCode})');
        return null;
      }

      final total = response.contentLength ?? 0;
      int received = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _dlProgress = (received / total).clamp(0.0, 1.0);
            onProgress?.call(_dlProgress);
          }
        }
        await sink.close();
      } catch (_) {
        await sink.close();
        try { await file.delete(); } catch (_) {}
        onError?.call('Error durante la descarga');
        return null;
      }

      _dlProgress = 1.0;
      onProgress?.call(1.0);
      return filePath;

    } catch (e) {
      onError?.call('Error inesperado: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // ── Instalar APK ─────────────────────────────────────────────────────────
  /// Lanza el instalador nativo de Android con el APK descargado.
  static Future<void> installApk(String filePath) async {
    await _channel.invokeMethod('installApk', {'path': filePath});
  }
}
