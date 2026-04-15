import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/xtream_data.dart';

class XtreamService {
  String _server = '';
  String _username = '';
  String _password = '';
  UserInfo? _userInfo;
  ServerInfo? _serverInfo;

  String get server => _server;
  String get username => _username;
  String get password => _password;
  UserInfo? get userInfo => _userInfo;
  ServerInfo? get serverInfo => _serverInfo;
  bool get isLoggedIn => _userInfo?.isAuthenticated ?? false;

  String get _baseUrl {
    String s = _server.trim();
    if (!s.startsWith('http')) s = 'http://$s';
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  String get _apiUrl => '$_baseUrl/player_api.php';

  Future<Map<String, dynamic>> _getJson(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}');
  }

  Future<List<dynamic>> _getList(String url, {Duration? timeout}) async {
    final response = await http.get(Uri.parse(url)).timeout(timeout ?? const Duration(seconds: 90));
    if (response.statusCode == 200) {
      final body = response.body.trim();
      // Handle empty, null, false, or non-array responses from Xtream API
      if (body.isEmpty || body == 'null' || body == 'false' || body == '""' || body == '[]') {
        return [];
      }
      final decoded = json.decode(body);
      if (decoded is List) {
        return decoded;
      }
      // Some servers return an object instead of array
      if (decoded is Map) {
        return [];
      }
      return [];
    }
    throw Exception('HTTP ${response.statusCode}');
  }

  Future<bool> authenticate(String server, String username, String password) async {
    _server = server;
    _username = username;
    _password = password;
    try {
      final data = await _getJson('$_apiUrl?username=$_username&password=$_password');
      _userInfo = UserInfo.fromJson(data['user_info'] ?? {});
      _serverInfo = ServerInfo.fromJson(data['server_info'] ?? {});
      return _userInfo?.isAuthenticated ?? false;
    } catch (e) {
      _userInfo = null;
      _serverInfo = null;
      return false;
    }
  }

  Future<List<Category>> getLiveCategories() async {
    final data = await _getList('$_apiUrl?username=$_username&password=$_password&action=get_live_categories');
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LiveStream>> getLiveStreams({String? categoryId}) async {
    String url = '$_apiUrl?username=$_username&password=$_password&action=get_live_streams';
    if (categoryId != null) url += '&category_id=$categoryId';
    final data = await _getList(url, timeout: categoryId == null ? const Duration(seconds: 120) : null);
    return data.map((e) => LiveStream.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Category>> getVodCategories() async {
    final data = await _getList('$_apiUrl?username=$_username&password=$_password&action=get_vod_categories');
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VodStream>> getVodStreams({String? categoryId}) async {
    String url = '$_apiUrl?username=$_username&password=$_password&action=get_vod_streams';
    if (categoryId != null) url += '&category_id=$categoryId';
    final data = await _getList(url, timeout: const Duration(seconds: 120));
    return data.map((e) => VodStream.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Category>> getSeriesCategories() async {
    final data = await _getList('$_apiUrl?username=$_username&password=$_password&action=get_series_categories');
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SeriesItem>> getSeries({String? categoryId}) async {
    String url = '$_apiUrl?username=$_username&password=$_password&action=get_series';
    if (categoryId != null) url += '&category_id=$categoryId';
    final data = await _getList(url, timeout: const Duration(seconds: 120));
    return data.map((e) => SeriesItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SeriesInfo> getSeriesInfo(int seriesId) async {
    final data = await _getJson('$_apiUrl?username=$_username&password=$_password&action=get_series_info&series_id=$seriesId');
    return SeriesInfo.fromJson(data);
  }

  Future<List<EpgEntry>> getShortEpg(int streamId) async {
    try {
      final data = await _getJson('$_apiUrl?username=$_username&password=$_password&action=get_short_epg&stream_id=$streamId&limit=10');
      final listings = data['epg_listings'] as List<dynamic>? ?? [];
      return listings.map((e) => EpgEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get EPG for all channels using the simple table endpoint
  Future<List<EpgEntry>> getSimpleDataTable(int streamId) async {
    try {
      final data = await _getJson('$_apiUrl?username=$_username&password=$_password&action=get_simple_data_table&stream_id=$streamId');
      final listings = data['epg_listings'] as List<dynamic>? ?? [];
      return listings.map((e) => EpgEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  String buildLiveUrl(int streamId, {String format = 'ts'}) {
    return '$_baseUrl/live/$_username/$_password/$streamId.$format';
  }

  String buildVodUrl(int streamId, String extension) {
    return '$_baseUrl/movie/$_username/$_password/$streamId.$extension';
  }

  String buildSeriesUrl(int streamId, String extension) {
    return '$_baseUrl/series/$_username/$_password/$streamId.$extension';
  }
}
