import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/xtream_data.dart';
import '../services/xtream_service.dart';

class AppProvider extends ChangeNotifier {
  final XtreamService _service = XtreamService();
  XtreamService get service => _service;

  // Separate loading states per section
  bool _isLoadingLive = false;
  bool _isLoadingVod = false;
  bool _isLoadingSeries = false;
  bool get isLoading => _isLoadingLive || _isLoadingVod || _isLoadingSeries;
  bool get isLoadingLive => _isLoadingLive;
  bool get isLoadingVod => _isLoadingVod;
  bool get isLoadingSeries => _isLoadingSeries;

  String? _error;
  String? _liveError;
  String? _vodError;
  String? _seriesError;
  String? get error => _error;
  String? get liveError => _liveError;
  String? get vodError => _vodError;
  String? get seriesError => _seriesError;

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

  // Favorites
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

  // Resume positions
  final Map<int, Duration> _resumePositions = {};
  Duration? getResumePosition(int streamId) => _resumePositions[streamId];

  void saveResumePosition(int streamId, Duration position) {
    _resumePositions[streamId] = position;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('resume_$streamId', position.inMilliseconds);
    });
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

  // ---- Auth ----

  Future<bool> login(String server, String username, String password) async {
    _isLoadingLive = true;
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
        _isLoadingLive = false;
        notifyListeners();
        _autoLoadCategories();
      } else {
        _error = 'Authentication failed. Check your credentials.';
        _isLoadingLive = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Connection error: $e';
      _isLoadingLive = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _autoLoadCategories() async {
    // Load each category type independently - don't use Future.wait
    // which would fail ALL if one fails
    try {
      _liveCategories = await _service.getLiveCategories();
      notifyListeners();
      if (_liveCategories.isNotEmpty) {
        loadLiveStreams(_liveCategories.first.categoryId);
      }
    } catch (e) {
      debugPrint('Failed to load live categories: $e');
    }

    try {
      _vodCategories = await _service.getVodCategories();
      notifyListeners();
      if (_vodCategories.isNotEmpty) {
        loadVodStreams(_vodCategories.first.categoryId);
      }
    } catch (e) {
      debugPrint('Failed to load VOD categories: $e');
    }

    try {
      if (_seriesCategories.isEmpty) {
        _seriesCategories = await _service.getSeriesCategories();
        notifyListeners();
      }
      if (_seriesCategories.isNotEmpty && _currentSeries.isEmpty && !_isLoadingSeries) {
        loadSeries(_seriesCategories.first.categoryId);
      }
    } catch (e) {
      debugPrint('Failed to load series categories: $e');
    }

    // Pre-load all streams in background for fast favorites access
    _preloadAllStreams();
  }

  Future<void> _preloadAllStreams() async {
    try {
      if (_allLiveStreams.isEmpty) {
        _allLiveStreams = await _service.getLiveStreams();
      }
    } catch (e) {
      debugPrint('Background preload live: $e');
    }
    try {
      if (_allVodStreams.isEmpty) {
        _allVodStreams = await _service.getVodStreams();
      }
    } catch (e) {
      debugPrint('Background preload vod: $e');
    }
    try {
      if (_allSeries.isEmpty) {
        _allSeries = await _service.getSeries();
      }
    } catch (e) {
      debugPrint('Background preload series: $e');
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
    _allLiveStreams = [];
    _allVodStreams = [];
    _allSeries = [];
    notifyListeners();
  }

  // ---- Live ----

  Future<void> loadLiveCategories() async {
    try {
      _liveCategories = await _service.getLiveCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load categories';
    }
  }

  List<LiveStream> _allLiveStreams = [];
  List<LiveStream> get allLiveStreams => _allLiveStreams;

  Future<void> loadLiveStreams(String? categoryId) async {
    // Skip if already loading the same category
    if (_selectedLiveCategoryId == categoryId && _isLoadingLive) return;
    _selectedLiveCategoryId = categoryId;
    _isLoadingLive = true;
    _liveError = null;
    notifyListeners();
    try {
      if (categoryId == '__favorites__') {
        if (_allLiveStreams.isEmpty) {
          _allLiveStreams = await _service.getLiveStreams();
        }
        if (_selectedLiveCategoryId != categoryId) return;
        _currentStreams = _allLiveStreams.where((s) => _favoriteStreamIds.contains(s.streamId)).toList();
      } else {
        final results = await _service.getLiveStreams(categoryId: categoryId);
        if (_selectedLiveCategoryId != categoryId) return;
        _currentStreams = results;
        if (categoryId == null) {
          _allLiveStreams = results;
        }
      }
      _isLoadingLive = false;
      notifyListeners();
    } catch (e) {
      if (_selectedLiveCategoryId != categoryId) return;
      _isLoadingLive = false;
      _liveError = 'Failed to load streams: $e';
      notifyListeners();
    }
  }

  // ---- VOD / Movies ----

  Future<void> loadVodCategories() async {
    try {
      _vodCategories = await _service.getVodCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load VOD categories';
    }
  }

  List<VodStream> _allVodStreams = [];
  List<VodStream> get allVodStreams => _allVodStreams;

  Future<void> loadVodStreams(String? categoryId) async {
    if (_selectedVodCategoryId == categoryId && _isLoadingVod) return;
    _selectedVodCategoryId = categoryId;
    _isLoadingVod = true;
    _vodError = null;
    notifyListeners();
    try {
      final results = await _service.getVodStreams(categoryId: categoryId);
      if (_selectedVodCategoryId != categoryId) return;
      _currentVodStreams = results;
      if (categoryId == null) {
        _allVodStreams = results;
      }
      _isLoadingVod = false;
      notifyListeners();
    } catch (e) {
      if (_selectedVodCategoryId != categoryId) return;
      _isLoadingVod = false;
      _vodError = 'Failed to load movies: $e';
      notifyListeners();
    }
  }

  bool _loadingAllVod = false;

  Future<List<VodStream>> searchVodStreams(String query) async {
    final q = query.toLowerCase();
    final localResults = _currentVodStreams.where((m) => m.name.toLowerCase().contains(q)).toList();

    if (_allVodStreams.isNotEmpty) {
      return _allVodStreams.where((m) => m.name.toLowerCase().contains(q)).toList();
    }

    if (!_loadingAllVod) {
      _loadingAllVod = true;
      try {
        _allVodStreams = await _service.getVodStreams();
        _loadingAllVod = false;
        notifyListeners();
      } catch (e) {
        _loadingAllVod = false;
      }
    }

    return localResults;
  }

  // ---- Series ----

  Future<void> loadSeriesCategories() async {
    try {
      _seriesCategories = await _service.getSeriesCategories();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load series categories';
    }
  }

  List<SeriesItem> _allSeries = [];
  List<SeriesItem> get allSeries => _allSeries;

  Future<void> loadSeries(String? categoryId) async {
    if (_selectedSeriesCategoryId == categoryId && _isLoadingSeries) return;
    _selectedSeriesCategoryId = categoryId;
    _isLoadingSeries = true;
    _seriesError = null;
    _currentSeries = [];
    notifyListeners();
    try {
      final results = await _service.getSeries(categoryId: categoryId);
      if (_selectedSeriesCategoryId != categoryId) return;
      _currentSeries = results;
      if (categoryId == null) {
        _allSeries = results;
      }
      _isLoadingSeries = false;
      _seriesError = null;
      notifyListeners();
    } catch (e) {
      if (_selectedSeriesCategoryId != categoryId) return;
      _isLoadingSeries = false;
      _seriesError = 'Failed to load series: $e';
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

  // ---- Util ----

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
