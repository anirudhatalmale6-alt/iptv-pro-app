import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/xtream_data.dart';
import '../services/xtream_service.dart';

class AppProvider extends ChangeNotifier {
  final XtreamService _service = XtreamService();
  XtreamService get service => _service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  bool get isLoggedIn => _service.isLoggedIn;
  UserInfo? get userInfo => _service.userInfo;

  // Data caches
  List<Category> _liveCategories = [];
  List<Category> _vodCategories = [];
  List<Category> _seriesCategories = [];
  List<LiveStream> _currentStreams = [];
  List<VodStream> _currentVodStreams = [];
  List<SeriesItem> _currentSeries = [];
  String? _selectedLiveCategoryId;
  String? _selectedVodCategoryId;
  String? _selectedSeriesCategoryId;

  List<Category> get liveCategories => _liveCategories;
  List<Category> get vodCategories => _vodCategories;
  List<Category> get seriesCategories => _seriesCategories;
  List<LiveStream> get currentStreams => _currentStreams;
  List<VodStream> get currentVodStreams => _currentVodStreams;
  List<SeriesItem> get currentSeries => _currentSeries;
  String? get selectedLiveCategoryId => _selectedLiveCategoryId;
  String? get selectedVodCategoryId => _selectedVodCategoryId;
  String? get selectedSeriesCategoryId => _selectedSeriesCategoryId;

  // Favorites for channels, movies, series
  Set<int> _favoriteStreamIds = {};
  Set<int> _favoriteMovieIds = {};
  Set<int> _favoriteSeriesIds = {};
  Set<int> get favoriteStreamIds => _favoriteStreamIds;
  Set<int> get favoriteMovieIds => _favoriteMovieIds;
  Set<int> get favoriteSeriesIds => _favoriteSeriesIds;

  bool isFavorite(int streamId) => _favoriteStreamIds.contains(streamId);
  bool isMovieFavorite(int streamId) => _favoriteMovieIds.contains(streamId);
  bool isSeriesFavorite(int seriesId) => _favoriteSeriesIds.contains(seriesId);

  void toggleFavorite(int streamId) {
    if (_favoriteStreamIds.contains(streamId)) {
      _favoriteStreamIds.remove(streamId);
    } else {
      _favoriteStreamIds.add(streamId);
    }
    _saveFavorites();
    notifyListeners();
  }

  void toggleMovieFavorite(int streamId) {
    if (_favoriteMovieIds.contains(streamId)) {
      _favoriteMovieIds.remove(streamId);
    } else {
      _favoriteMovieIds.add(streamId);
    }
    _saveFavorites();
    notifyListeners();
  }

  void toggleSeriesFavorite(int seriesId) {
    if (_favoriteSeriesIds.contains(seriesId)) {
      _favoriteSeriesIds.remove(seriesId);
    } else {
      _favoriteSeriesIds.add(seriesId);
    }
    _saveFavorites();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('favorites', _favoriteStreamIds.map((e) => e.toString()).toList());
    prefs.setStringList('movie_favorites', _favoriteMovieIds.map((e) => e.toString()).toList());
    prefs.setStringList('series_favorites', _favoriteSeriesIds.map((e) => e.toString()).toList());
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteStreamIds = (prefs.getStringList('favorites') ?? []).map((e) => int.parse(e)).toSet();
    _favoriteMovieIds = (prefs.getStringList('movie_favorites') ?? []).map((e) => int.parse(e)).toSet();
    _favoriteSeriesIds = (prefs.getStringList('series_favorites') ?? []).map((e) => int.parse(e)).toSet();
  }

  // Resume positions for VOD
  final Map<int, Duration> _resumePositions = {};
  Duration? getResumePosition(int streamId) => _resumePositions[streamId];

  void saveResumePosition(int streamId, Duration position) {
    _resumePositions[streamId] = position;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('resume_$streamId', position.inMilliseconds);
    });
  }

  Future<void> _loadResumePositions() async {
    // Loaded on demand per stream
  }

  Future<Duration?> loadResumePosition(int streamId) async {
    if (_resumePositions.containsKey(streamId)) return _resumePositions[streamId];
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('resume_$streamId');
    if (ms != null) {
      _resumePositions[streamId] = Duration(milliseconds: ms);
      return _resumePositions[streamId];
    }
    return null;
  }

  Future<bool> login(String server, String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _service.authenticate(server, username, password);
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('server', server);
        prefs.setString('username', username);
        prefs.setString('password', password);
        await _loadFavorites();
        // Auto-load all categories on login
        _autoLoadCategories();
      } else {
        _error = 'Authentication failed. Check your credentials.';
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _autoLoadCategories() async {
    // Load all categories in parallel
    try {
      final results = await Future.wait([
        _service.getLiveCategories(),
        _service.getVodCategories(),
        _service.getSeriesCategories(),
      ]);
      _liveCategories = results[0] as List<Category>;
      _vodCategories = results[1] as List<Category>;
      _seriesCategories = results[2] as List<Category>;
      notifyListeners();

      // Auto-load first category for each section
      if (_liveCategories.isNotEmpty) {
        loadLiveStreams(_liveCategories.first.categoryId);
      }
      if (_vodCategories.isNotEmpty) {
        loadVodStreams(_vodCategories.first.categoryId);
      }
      if (_seriesCategories.isNotEmpty) {
        loadSeries(_seriesCategories.first.categoryId);
      }
    } catch (e) {
      // Individual loads as fallback
      loadLiveCategories();
      loadVodCategories();
      loadSeriesCategories();
    }
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('server');
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    if (server != null && username != null && password != null) {
      return await login(server, username, password);
    }
    return false;
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('server');
    prefs.remove('username');
    prefs.remove('password');
    _liveCategories = [];
    _vodCategories = [];
    _seriesCategories = [];
    _currentStreams = [];
    _currentVodStreams = [];
    _currentSeries = [];
    notifyListeners();
  }

  Future<void> loadLiveCategories() async {
    try {
      _liveCategories = await _service.getLiveCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load categories';
    }
  }

  // All live streams cache for favorites/search
  List<LiveStream> _allLiveStreams = [];
  List<LiveStream> get allLiveStreams => _allLiveStreams;

  Future<void> loadLiveStreams(String? categoryId) async {
    _selectedLiveCategoryId = categoryId;
    _isLoading = true;
    notifyListeners();
    try {
      if (categoryId == '__favorites__') {
        // Show only favorite streams from cache
        if (_allLiveStreams.isEmpty) {
          _allLiveStreams = await _service.getLiveStreams();
        }
        _currentStreams = _allLiveStreams.where((s) => _favoriteStreamIds.contains(s.streamId)).toList();
      } else {
        _currentStreams = await _service.getLiveStreams(categoryId: categoryId);
        // Cache all streams when loading without category
        if (categoryId == null) {
          _allLiveStreams = _currentStreams;
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load streams';
      notifyListeners();
    }
  }

  Future<void> loadVodCategories() async {
    try {
      _vodCategories = await _service.getVodCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load VOD categories';
    }
  }

  // All VOD streams cache for search/favorites
  List<VodStream> _allVodStreams = [];
  List<VodStream> get allVodStreams => _allVodStreams;

  Future<void> loadVodStreams(String? categoryId) async {
    _selectedVodCategoryId = categoryId;
    _isLoading = true;
    notifyListeners();
    try {
      _currentVodStreams = await _service.getVodStreams(categoryId: categoryId);
      // Cache all streams when loading without category
      if (categoryId == null) {
        _allVodStreams = _currentVodStreams;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load movies';
      notifyListeners();
    }
  }

  bool _loadingAllVod = false;

  Future<List<VodStream>> searchVodStreams(String query) async {
    final q = query.toLowerCase();
    // First search in current category results
    final localResults = _currentVodStreams.where((m) => m.name.toLowerCase().contains(q)).toList();

    // If we have all VOD cached, search there
    if (_allVodStreams.isNotEmpty) {
      return _allVodStreams.where((m) => m.name.toLowerCase().contains(q)).toList();
    }

    // Start loading all VOD in background if not already loading
    if (!_loadingAllVod) {
      _loadingAllVod = true;
      try {
        _allVodStreams = await _service.getVodStreams();
        _loadingAllVod = false;
        notifyListeners(); // Trigger rebuild with full results
      } catch (e) {
        _loadingAllVod = false;
      }
    }

    // Return local results for now
    return localResults;
  }

  Future<void> loadSeriesCategories() async {
    try {
      _seriesCategories = await _service.getSeriesCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load series categories';
    }
  }

  // All series cache for search/favorites
  List<SeriesItem> _allSeries = [];
  List<SeriesItem> get allSeries => _allSeries;

  Future<void> loadSeries(String? categoryId) async {
    _selectedSeriesCategoryId = categoryId;
    _isLoading = true;
    notifyListeners();
    try {
      _currentSeries = await _service.getSeries(categoryId: categoryId);
      if (categoryId == null) {
        _allSeries = _currentSeries;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load series';
      notifyListeners();
    }
  }

  bool _loadingAllSeries = false;

  Future<List<SeriesItem>> searchSeries(String query) async {
    final q = query.toLowerCase();
    final localResults = _currentSeries.where((s) => s.name.toLowerCase().contains(q)).toList();

    if (_allSeries.isNotEmpty) {
      return _allSeries.where((s) => s.name.toLowerCase().contains(q)).toList();
    }

    if (!_loadingAllSeries) {
      _loadingAllSeries = true;
      try {
        _allSeries = await _service.getSeries();
        _loadingAllSeries = false;
        notifyListeners();
      } catch (e) {
        _loadingAllSeries = false;
      }
    }

    return localResults;
  }

  Future<SeriesInfo> getSeriesInfo(int seriesId) async {
    return await _service.getSeriesInfo(seriesId);
  }

  Future<List<EpgEntry>> getShortEpg(int streamId) async {
    return await _service.getShortEpg(streamId);
  }

  String buildLiveUrl(int streamId) => _service.buildLiveUrl(streamId);
  String buildVodUrl(int streamId, String ext) => _service.buildVodUrl(streamId, ext);
  String buildSeriesUrl(int streamId, String ext) => _service.buildSeriesUrl(streamId, ext);
}
