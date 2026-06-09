import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/channel.dart';
import '../models/epg_entry.dart';
import '../models/movie.dart';
import '../models/series.dart';

class XtreamService {
  final String server;
  final String username;
  final String password;

  XtreamService({required this.server, required this.username, required this.password});

  String get _base => '$server/player_api.php?username=$username&password=$password';

  Future<Map<String, dynamic>?> login() async {
    try {
      final response = await http.get(Uri.parse(_base)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return null;
  }

  Future<List<Category>> getLiveCategories() => _fetchCategories('get_live_categories');
  Future<List<Category>> getMovieCategories() => _fetchCategories('get_vod_categories');
  Future<List<Category>> getSeriesCategories() => _fetchCategories('get_series_categories');

  Future<List<Category>> _fetchCategories(String action) async {
    try {
      final response = await http.get(Uri.parse('$_base&action=$action')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Category.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    try {
      String url = '$_base&action=get_live_streams';
      if (categoryId != null) url += '&category_id=$categoryId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Channel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Movie>> getMovies({String? categoryId}) async {
    try {
      String url = '$_base&action=get_vod_streams';
      if (categoryId != null) url += '&category_id=$categoryId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Movie.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Series>> getSeries({String? categoryId}) async {
    try {
      String url = '$_base&action=get_series';
      if (categoryId != null) url += '&category_id=$categoryId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => Series.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Alias so movies_screen can call getVodCategories()
  Future<List<Category>> getVodCategories() => getMovieCategories();

  String liveStreamUrl(String streamId) => '$server/live/$username/$password/$streamId.ts';
  String vodStreamUrl(String streamId, String ext) => '$server/movie/$username/$password/$streamId.$ext';
  String movieStreamUrl(String streamId, String ext) => vodStreamUrl(streamId, ext);

  Future<Map<String, dynamic>?> getVodInfo(String streamId) async {
    try {
      final url = '$_base&action=get_vod_info&vod_id=$streamId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return null;
  }

  // ── EPG ─────────────────────────────────────────────────────────────────────
  // Cache de sesión: evita llamadas repetidas al mismo canal
  static final Map<String, List<EpgEntry>> _epgCache = {};

  Future<List<EpgEntry>> getShortEpg(String streamId) async {
    if (_epgCache.containsKey(streamId)) return _epgCache[streamId]!;
    try {
      final url = '$_base&action=get_short_epg&stream_id=$streamId&limit=2';
      final res = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final raw  = body['epg_listings'];
        if (raw is List && raw.isNotEmpty) {
          final entries = raw
            .map((e) => EpgEntry.fromJson(e as Map<String, dynamic>))
            .toList();
          _epgCache[streamId] = entries;
          return entries;
        }
      }
    } catch (_) {}
    _epgCache[streamId] = [];
    return [];
  }

  /// Limpia el cache EPG (llamar al cambiar de categoría si se quiere datos frescos)
  static void clearEpgCache() => _epgCache.clear();

  Future<Map<String, dynamic>?> getSeriesInfo(String seriesId) async {
    try {
      final url = '$_base&action=get_series_info&series_id=$seriesId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (_) {}
    return null;
  }
}
