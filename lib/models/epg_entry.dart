import 'dart:convert';

class EpgEntry {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  const EpgEntry({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  /// Porcentaje de avance del programa actual (0.0 – 1.0)
  double get progress {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end))    return 1.0;
    final total   = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    return total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
  }

  String get timeRange =>
    '${_hm(start)} – ${_hm(end)}';

  String _hm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// Los títulos en la API de Xtream vienen en base64
  static String _decode(String raw) {
    if (raw.isEmpty) return '';
    try { return utf8.decode(base64.decode(raw)); }
    catch (_) { return raw; }
  }

  factory EpgEntry.fromJson(Map<String, dynamic> j) {
    final startTs = int.tryParse(j['start_timestamp']?.toString() ?? '') ?? 0;
    final stopTs  = int.tryParse(j['stop_timestamp']?.toString()  ?? '') ?? 0;
    return EpgEntry(
      title:       _decode(j['title']?.toString() ?? ''),
      description: _decode(j['description']?.toString() ?? ''),
      start: startTs > 0
        ? DateTime.fromMillisecondsSinceEpoch(startTs * 1000)
        : DateTime.now(),
      end: stopTs > 0
        ? DateTime.fromMillisecondsSinceEpoch(stopTs * 1000)
        : DateTime.now().add(const Duration(hours: 1)),
    );
  }
}
