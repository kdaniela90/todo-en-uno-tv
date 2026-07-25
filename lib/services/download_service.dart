import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Modelo ───────────────────────────────────────────────────────────────────
class DownloadedItem {
  final String id;         // 'movie_{id}' o 'ep_{id}'
  final String name;
  final String type;       // 'movie' | 'series'
  final String? poster;
  final String filePath;
  final int fileSizeBytes;
  final String ext;
  final DateTime downloadedAt;

  const DownloadedItem({
    required this.id,
    required this.name,
    required this.type,
    this.poster,
    required this.filePath,
    required this.fileSizeBytes,
    required this.ext,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'type': type, 'poster': poster,
    'filePath': filePath, 'fileSizeBytes': fileSizeBytes,
    'ext': ext, 'downloadedAt': downloadedAt.toIso8601String(),
  };

  factory DownloadedItem.fromJson(Map<String, dynamic> j) => DownloadedItem(
    id: j['id'] as String,
    name: j['name'] as String,
    type: j['type'] as String? ?? 'movie',
    poster: j['poster'] as String?,
    filePath: j['filePath'] as String,
    fileSizeBytes: (j['fileSizeBytes'] as num?)?.toInt() ?? 0,
    ext: j['ext'] as String? ?? 'mp4',
    downloadedAt: DateTime.tryParse(j['downloadedAt'] as String? ?? '') ?? DateTime.now(),
  );

  String get sizeLabel {
    if (fileSizeBytes <= 0) return '';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

// ─── Servicio ─────────────────────────────────────────────────────────────────
class DownloadService {
  static const _prefKey = 'downloaded_items_v1';

  // Progreso de descargas activas: id → 0.0..1.0
  static final Map<String, double> _progress = {};
  static final Map<String, bool> _cancels = {};

  // ── Directorio de almacenamiento ──────────────────────────────────────────
  static Future<Directory> get _dir async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/teutv_downloads');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ── Leer / escribir metadata ──────────────────────────────────────────────
  static Future<List<DownloadedItem>> getDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      final items = list
        .map((e) => DownloadedItem.fromJson(e as Map<String, dynamic>))
        .toList();
      items.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      return items;
    } catch (_) { return []; }
  }

  static Future<DownloadedItem?> getDownload(String id) async {
    final list = await getDownloads();
    try { return list.firstWhere((e) => e.id == id); } catch (_) { return null; }
  }

  static Future<bool> isDownloaded(String id) async =>
    await getDownload(id) != null;

  static bool isActivelyDownloading(String id) => _progress.containsKey(id);
  static double getActiveProgress(String id) => _progress[id] ?? 0.0;

  static Future<void> _saveAll(List<DownloadedItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey,
      jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ── Eliminar descarga ─────────────────────────────────────────────────────
  static Future<void> deleteDownload(String id) async {
    final item = await getDownload(id);
    if (item != null) {
      try {
        final f = File(item.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final list = await getDownloads();
    list.removeWhere((e) => e.id == id);
    await _saveAll(list);
  }

  // ── Cancelar descarga activa ──────────────────────────────────────────────
  static void cancelDownload(String id) {
    _cancels[id] = true;
  }

  // ── Iniciar descarga ──────────────────────────────────────────────────────
  /// Devuelve el item descargado, o null si hubo error.
  /// [onProgress] recibe valores de 0.0 a 1.0 durante la descarga.
  static Future<DownloadedItem?> startDownload({
    required String id,
    required String name,
    required String type,      // 'movie' | 'series'
    required String downloadUrl,
    required String ext,
    String? poster,
    void Function(double progress)? onProgress,
    void Function(String error)? onError,
  }) async {
    if (_progress.containsKey(id)) return null; // ya descargando

    _progress[id] = 0.0;
    _cancels.remove(id);
    onProgress?.call(0.0);

    final client = http.Client();
    try {
      final dir = await _dir;
      final filePath = '${dir.path}/$id.$ext';

      final request = http.Request('GET', Uri.parse(downloadUrl))
        ..headers['User-Agent'] = 'Mozilla/5.0';

      final response = await client.send(request);

      if (response.statusCode != 200) {
        _progress.remove(id);
        onError?.call('Error del servidor (${response.statusCode})');
        return null;
      }

      final total = response.contentLength ?? 0;
      int received = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          if (_cancels[id] == true) {
            // Usuario canceló
            await sink.close();
            try { await file.delete(); } catch (_) {}
            _progress.remove(id);
            _cancels.remove(id);
            return null;
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final p = (received / total).clamp(0.0, 1.0);
            _progress[id] = p;
            onProgress?.call(p);
          }
        }
        await sink.close();
      } catch (e) {
        await sink.close();
        try { await file.delete(); } catch (_) {}
        _progress.remove(id);
        onError?.call('Error durante la descarga');
        return null;
      }

      final fileSize = await file.length();
      final item = DownloadedItem(
        id: id, name: name, type: type, poster: poster,
        filePath: filePath, fileSizeBytes: fileSize,
        ext: ext, downloadedAt: DateTime.now(),
      );

      // Guardar metadata
      final list = await getDownloads();
      list.removeWhere((e) => e.id == id);
      list.add(item);
      await _saveAll(list);

      _progress.remove(id);
      onProgress?.call(1.0);
      return item;

    } catch (e) {
      _progress.remove(id);
      onError?.call('Error inesperado: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // ── Total de espacio usado ────────────────────────────────────────────────
  static Future<String> totalSizeLabel() async {
    final items = await getDownloads();
    final total = items.fold<int>(0, (sum, e) => sum + e.fileSizeBytes);
    if (total == 0) return '0 MB';
    if (total < 1024 * 1024) return '${(total / 1024).toStringAsFixed(0)} KB';
    if (total < 1024 * 1024 * 1024) return '${(total / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
