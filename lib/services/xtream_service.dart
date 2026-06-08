import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/channel.dart';
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
}
