import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';
import '../series/series_detail_screen.dart';
import '../login/login_screen.dart';

/// TV-optimized home screen with manual D-pad navigation.
/// Uses index-based focus tracking instead of Flutter's Focus system.
/// Layout: Left sidebar (sections + categories) | Right content grid

enum _Zone { sidebar, content }
enum _Section { live, movies, series, guide, settings }

class TvHome extends StatefulWidget {
  const TvHome({super.key});

  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  // ─── NAVIGATION STATE ───
  _Zone _zone = _Zone.sidebar;
  int _sidebarIndex = 0;
  int _contentIndex = 0;
  _Section _activeSection = _Section.live;

  // ─── FOCUS & SCROLL ───
  final _rootFocus = FocusNode();
  final _sidebarScroll = ScrollController();
  final _contentScroll = ScrollController();

  // ─── SECTION DEFINITIONS ───
  static const _sectionDefs = <(String, IconData)>[
    ('Live TV', Icons.live_tv_rounded),
    ('Movies', Icons.movie_outlined),
    ('Series', Icons.tv_rounded),
    ('TV Guide', Icons.grid_view_rounded),
    ('Settings', Icons.settings_rounded),
  ];

  Timer? _focusGuard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocus.requestFocus();
      _loadSectionData(_Section.live);
    });
    // Periodically ensure focus isn't lost (TV remotes can steal focus)
    _focusGuard = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && !_rootFocus.hasFocus) {
        _rootFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusGuard?.cancel();
    _rootFocus.dispose();
    _sidebarScroll.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  // ─── DATA HELPERS ───

  List<Category> _getCategories(AppProvider p) {
    switch (_activeSection) {
      case _Section.live:
        return p.liveCategories;
      case _Section.movies:
        return p.vodCategories;
      case _Section.series:
        return p.seriesCategories;
      default:
        return [];
    }
  }

  List<dynamic> _getContentItems(AppProvider p) {
    switch (_activeSection) {
      case _Section.live:
        return p.currentStreams;
      case _Section.movies:
        return p.currentVodStreams;
      case _Section.series:
        return p.currentSeries;
      case _Section.guide:
        return p.currentStreams; // reuse live streams for guide
      case _Section.settings:
        return List.generate(5, (i) => i); // 5 settings rows
    }
  }

  bool _getIsLoading(AppProvider p) {
    switch (_activeSection) {
      case _Section.live:
      case _Section.guide:
        return p.isLoadingLive;
      case _Section.movies:
        return p.isLoadingVod;
      case _Section.series:
        return p.isLoadingSeries;
      case _Section.settings:
        return false;
    }
  }

  int get _gridColumns {
    final w = MediaQuery.of(context).size.width - 280; // minus sidebar
    if (_activeSection == _Section.guide || _activeSection == _Section.settings) return 1;
    if (_activeSection == _Section.movies || _activeSection == _Section.series) {
      // Fewer, bigger cards for TV
      if (w > 1400) return 5;
      if (w > 1000) return 4;
      if (w > 700) return 3;
      return 2;
    }
    // Live TV channels - bigger cards
    if (w > 1400) return 5;
    if (w > 1000) return 4;
    if (w > 700) return 3;
    return 2;
  }

  /// Total sidebar items: sections + "Favorites" + categories
  int _totalSidebarItems(AppProvider p) {
    final cats = _getCategories(p);
    final hasCategories = _activeSection == _Section.live ||
        _activeSection == _Section.movies ||
        _activeSection == _Section.series;
    return _sectionDefs.length + (hasCategories ? 1 + cats.length : 0);
  }

  bool _isCategoryActive(AppProvider p, String catId) {
    switch (_activeSection) {
      case _Section.live:
        return p.selectedLiveCategoryId == catId;
      case _Section.movies:
        return p.selectedVodCategoryId == catId;
      case _Section.series:
        return p.selectedSeriesCategoryId == catId;
      default:
        return false;
    }
  }

  // ─── DATA LOADING ───

  void _loadSectionData(_Section section) {
    final p = context.read<AppProvider>();
    switch (section) {
      case _Section.live:
      case _Section.guide:
        if (p.liveCategories.isEmpty) {
          p.loadLiveCategories().then((_) {
            if (p.liveCategories.isNotEmpty && p.currentStreams.isEmpty) {
              p.loadLiveStreams(p.liveCategories.first.categoryId);
            }
          });
        }
        break;
      case _Section.movies:
        if (p.vodCategories.isEmpty) {
          p.loadVodCategories().then((_) {
            if (p.vodCategories.isNotEmpty && p.currentVodStreams.isEmpty) {
              p.loadVodStreams(p.vodCategories.first.categoryId);
            }
          });
        }
        break;
      case _Section.series:
        if (p.seriesCategories.isEmpty) {
          p.loadSeriesCategories().then((_) {
            if (p.seriesCategories.isNotEmpty && p.currentSeries.isEmpty) {
              p.loadSeries(p.seriesCategories.first.categoryId);
            }
          });
        }
        break;
      case _Section.settings:
        break;
    }
  }

  // ─── DEBUG ───
  String _lastKeyDebug = '';

  // ─── KEY HANDLING ───

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Accept both KeyDown and KeyRepeat (some TV remotes use repeat for navigation)
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Debug: show what key the remote is sending
    setState(() {
      _lastKeyDebug = '${event.runtimeType}: ${key.keyLabel} (${key.keyId})';
    });

    // Back button
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      if (_zone == _Zone.content) {
        setState(() => _zone = _Zone.sidebar);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored; // system handles exit
    }

    // Only handle D-pad keys and select - let other keys pass through
    if (!_isDpadKey(key) && !_isSelect(key)) {
      return KeyEventResult.ignored;
    }

    if (_zone == _Zone.sidebar) {
      return _handleSidebarKey(key);
    } else {
      return _handleContentKey(key);
    }
  }

  bool _isDpadKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.arrowUp ||
      k == LogicalKeyboardKey.arrowDown ||
      k == LogicalKeyboardKey.arrowLeft ||
      k == LogicalKeyboardKey.arrowRight;

  bool _isSelect(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.mediaPlayPause;

  KeyEventResult _handleSidebarKey(LogicalKeyboardKey key) {
    final p = context.read<AppProvider>();
    final total = _totalSidebarItems(p);

    // Safety clamp - prevent index from being out of range
    if (_sidebarIndex >= total) _sidebarIndex = total - 1;
    if (_sidebarIndex < 0) _sidebarIndex = 0;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_sidebarIndex > 0) {
        setState(() => _sidebarIndex--);
        _scrollSidebar();
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_sidebarIndex < total - 1) {
        setState(() => _sidebarIndex++);
        _scrollSidebar();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final items = _getContentItems(p);
      if (items.isNotEmpty) {
        setState(() {
          _zone = _Zone.content;
          if (_contentIndex >= items.length) _contentIndex = 0;
        });
      }
    } else if (_isSelect(key)) {
      _onSidebarSelect();
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _handleContentKey(LogicalKeyboardKey key) {
    final p = context.read<AppProvider>();
    final items = _getContentItems(p);
    final total = items.length;
    if (total == 0) {
      setState(() => _zone = _Zone.sidebar);
      return KeyEventResult.handled;
    }
    final cols = _gridColumns;
    final isList = cols == 1;

    // Safety clamp
    if (_contentIndex >= total) _contentIndex = total - 1;
    if (_contentIndex < 0) _contentIndex = 0;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (isList || _contentIndex % cols == 0) {
        setState(() => _zone = _Zone.sidebar);
      } else {
        setState(() => _contentIndex--);
        _scrollContent();
      }
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (!isList && _contentIndex < total - 1 && _contentIndex % cols < cols - 1) {
        setState(() => _contentIndex++);
        _scrollContent();
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (isList) {
        if (_contentIndex > 0) {
          setState(() => _contentIndex--);
          _scrollContent();
        }
      } else if (_contentIndex >= cols) {
        setState(() => _contentIndex -= cols);
        _scrollContent();
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (isList) {
        if (_contentIndex < total - 1) {
          setState(() => _contentIndex++);
          _scrollContent();
        }
      } else if (_contentIndex + cols < total) {
        setState(() => _contentIndex += cols);
        _scrollContent();
      }
    } else if (_isSelect(key)) {
      _onContentSelect();
    }
    return KeyEventResult.handled;
  }

  // ─── SIDEBAR ACTIONS ───

  void _onSidebarSelect() {
    final p = context.read<AppProvider>();

    if (_sidebarIndex < _sectionDefs.length) {
      // Section item selected
      final section = _Section.values[_sidebarIndex];
      if (section == _activeSection) return;
      final prevSidebarIndex = _sidebarIndex;
      setState(() {
        _activeSection = section;
        _contentIndex = 0;
        // Keep sidebar index at the section, don't let it drift
        _sidebarIndex = prevSidebarIndex;
      });
      _loadSectionData(section);
      // After data loads, clamp sidebar index to valid range
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final total = _totalSidebarItems(context.read<AppProvider>());
          if (_sidebarIndex >= total) {
            setState(() => _sidebarIndex = total - 1);
          }
        }
      });
    } else {
      // Category item selected
      final catOffset = _sidebarIndex - _sectionDefs.length;
      setState(() => _contentIndex = 0);

      if (catOffset == 0) {
        // "Favorites"
        switch (_activeSection) {
          case _Section.live:
            p.loadLiveStreams('__favorites__');
            break;
          case _Section.movies:
            p.loadVodStreams('__favorites__');
            break;
          case _Section.series:
            p.loadSeries('__favorites__');
            break;
          default:
            break;
        }
      } else {
        final cats = _getCategories(p);
        if (catOffset - 1 < cats.length) {
          final cat = cats[catOffset - 1];
          switch (_activeSection) {
            case _Section.live:
              p.loadLiveStreams(cat.categoryId);
              break;
            case _Section.movies:
              p.loadVodStreams(cat.categoryId);
              break;
            case _Section.series:
              p.loadSeries(cat.categoryId);
              break;
            default:
              break;
          }
        }
      }
    }
  }

  // ─── CONTENT ACTIONS ───

  void _onContentSelect() {
    final p = context.read<AppProvider>();
    final items = _getContentItems(p);
    if (_contentIndex >= items.length) return;
    final item = items[_contentIndex];

    if (item is LiveStream) {
      _playLive(p, item);
    } else if (item is VodStream) {
      _playVod(p, item);
    } else if (item is SeriesItem) {
      _openSeries(item);
    } else if (_activeSection == _Section.settings && item is int) {
      _onSettingsSelect(item);
    }
  }

  void _playLive(AppProvider p, LiveStream stream) {
    final url = p.buildLiveUrl(stream.streamId);
    final streams = p.currentStreams;
    final idx = streams.indexOf(stream);
    _pushScreen(PlayerScreen(
      url: url,
      title: stream.name,
      isLive: true,
      channelIcon: stream.streamIcon,
      streamId: stream.streamId,
      channelList: streams,
      currentChannelIndex: idx >= 0 ? idx : 0,
    ));
  }

  void _playVod(AppProvider p, VodStream vod) {
    final url = p.buildVodUrl(vod.streamId, vod.containerExtension ?? 'mp4');
    _pushScreen(PlayerScreen(
      url: url,
      title: vod.name,
      isLive: false,
      streamId: vod.streamId,
    ));
  }

  void _openSeries(SeriesItem series) {
    _pushScreen(SeriesDetailScreen(series: series));
  }

  void _onSettingsSelect(int index) {
    if (index == 4) {
      // Logout
      context.read<AppProvider>().logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      // Restore focus when returning from player/detail
      _rootFocus.requestFocus();
    });
  }

  // ─── SCROLL ───

  void _scrollSidebar() {
    if (!_sidebarScroll.hasClients) return;
    const itemH = 56.0;
    final offset = _sidebarIndex * itemH;
    final viewport = _sidebarScroll.position.viewportDimension;
    final current = _sidebarScroll.offset;
    final maxScroll = _sidebarScroll.position.maxScrollExtent;

    if (offset < current + itemH) {
      _sidebarScroll.animateTo(
        (offset - itemH).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (offset + itemH > current + viewport - itemH) {
      _sidebarScroll.animateTo(
        (offset - viewport + itemH * 2.5).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollContent() {
    if (!_contentScroll.hasClients) return;
    final cols = _gridColumns;
    final isList = cols == 1;
    final rowH = isList ? 72.0 : (_activeSection == _Section.live ? 196.0 : 316.0);
    final row = isList ? _contentIndex : _contentIndex ~/ cols;
    final offset = row * rowH;
    final viewport = _contentScroll.position.viewportDimension;
    final current = _contentScroll.offset;
    final maxScroll = _contentScroll.position.maxScrollExtent;

    if (offset < current + rowH) {
      _contentScroll.animateTo(
        (offset - rowH).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (offset + rowH > current + viewport - rowH) {
      _contentScroll.animateTo(
        (offset - viewport + rowH * 2.5).clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) => Stack(
            children: [
              Row(
                children: [
                  _buildSidebar(provider),
                  VerticalDivider(width: 1, color: AppColors.red.withOpacity(0.15)),
                  Expanded(child: _buildContent(provider)),
                ],
              ),
              // Debug: show last key pressed and focus state
              if (_lastKeyDebug.isNotEmpty)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.red.withOpacity(0.5)),
                    ),
                    child: Text(
                      'KEY: $_lastKeyDebug | Zone: ${_zone.name} | Sidebar: $_sidebarIndex | Content: $_contentIndex | Focus: ${_rootFocus.hasFocus}',
                      style: const TextStyle(color: Colors.yellow, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SIDEBAR ───

  Widget _buildSidebar(AppProvider p) {
    final cats = _getCategories(p);
    final hasCategories = _activeSection == _Section.live ||
        _activeSection == _Section.movies ||
        _activeSection == _Section.series;

    return Container(
      width: 280,
      color: AppColors.bgSidebar,
      child: Column(
        children: [
          // Logo
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/veltrix_header.png',
              height: 42,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'VELTRIX TV',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),

          // Scrollable items
          Expanded(
            child: ListView(
              controller: _sidebarScroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Sections
                for (int i = 0; i < _sectionDefs.length; i++)
                  _sidebarTile(
                    index: i,
                    icon: _sectionDefs[i].$2,
                    label: _sectionDefs[i].$1,
                    isActive: _Section.values[i] == _activeSection,
                  ),

                // Categories header + items
                if (hasCategories) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Text(
                      'CATEGORIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.whiteMuted,
                      ),
                    ),
                  ),
                  // Favorites
                  _sidebarTile(
                    index: _sectionDefs.length,
                    icon: Icons.star_rounded,
                    label: 'Favorites',
                    isActive: false,
                    iconColor: AppColors.gold,
                  ),
                  // Dynamic categories
                  for (int i = 0; i < cats.length; i++)
                    _sidebarTile(
                      index: _sectionDefs.length + 1 + i,
                      icon: null,
                      label: _cleanText(cats[i].categoryName),
                      isActive: _isCategoryActive(p, cats[i].categoryId),
                    ),
                ],
              ],
            ),
          ),

          // Clock
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 30)),
              builder: (_, __) {
                final now = DateTime.now();
                return Text(
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.whiteMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTile({
    required int index,
    IconData? icon,
    required String label,
    required bool isActive,
    Color? iconColor,
  }) {
    final isFocused = _zone == _Zone.sidebar && _sidebarIndex == index;
    final isSection = index < _sectionDefs.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isFocused
            ? AppColors.red.withOpacity(0.2)
            : isActive
                ? AppColors.red.withOpacity(0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused ? AppColors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 24,
                color: isFocused
                    ? AppColors.red
                    : iconColor ?? (isActive ? AppColors.white : AppColors.whiteDim),
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 32),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSection ? 17 : 15,
                  fontWeight: isFocused || isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isFocused || isActive ? AppColors.white : AppColors.whiteDim,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive && isSection)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  // ─── CONTENT AREA ───

  Widget _buildContent(AppProvider p) {
    if (_activeSection == _Section.settings) return _buildSettingsContent(p);

    final items = _getContentItems(p);
    final loading = _getIsLoading(p);
    final cols = _gridColumns;
    final isList = cols == 1;

    // Loading
    if (loading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2),
      );
    }

    // Empty
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.whiteMuted),
            const SizedBox(height: 12),
            Text('No content found', style: TextStyle(color: AppColors.whiteMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: Row(
            children: [
              Text(
                _sectionLabel,
                style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              if (_zone == _Zone.content) ...[
                const Spacer(),
                Text(
                  'Use arrows to navigate • OK to select • BACK to return',
                  style: TextStyle(color: AppColors.whiteMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),

        // Content
        Expanded(
          child: isList
              ? _buildListContent(items)
              : _buildGridContent(items, cols),
        ),
      ],
    );
  }

  String get _sectionLabel {
    switch (_activeSection) {
      case _Section.live:
        return 'Live TV';
      case _Section.movies:
        return 'Movies';
      case _Section.series:
        return 'Series';
      case _Section.guide:
        return 'TV Guide';
      case _Section.settings:
        return 'Settings';
    }
  }

  // ─── GRID CONTENT (Live, Movies, Series) ───

  Widget _buildGridContent(List<dynamic> items, int cols) {
    final rows = (items.length / cols).ceil();
    return ListView.builder(
      controller: _contentScroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: rows,
      itemBuilder: (context, rowIdx) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(cols, (colIdx) {
              final idx = rowIdx * cols + colIdx;
              if (idx >= items.length) return const Expanded(child: SizedBox());
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIdx < cols - 1 ? 14 : 0),
                  child: _buildCard(items[idx], idx),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ─── LIST CONTENT (TV Guide) ───

  Widget _buildListContent(List<dynamic> items) {
    return ListView.builder(
      controller: _contentScroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFocused = _zone == _Zone.content && _contentIndex == index;

        if (item is LiveStream) {
          return _buildGuideRow(item, isFocused);
        }
        return const SizedBox();
      },
    );
  }

  // ─── CARDS ───

  Widget _buildCard(dynamic item, int index) {
    final isFocused = _zone == _Zone.content && _contentIndex == index;

    if (item is LiveStream) return _channelCard(item, isFocused);
    if (item is VodStream) return _movieCard(item, isFocused);
    if (item is SeriesItem) return _seriesCard(item, isFocused);
    return const SizedBox();
  }

  Widget _channelCard(LiveStream s, bool focused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: 180,
      decoration: _cardDecoration(focused),
      transform: focused ? _scaleUp : Matrix4.identity(),
      transformAlignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: s.streamIcon != null && s.streamIcon!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: s.streamIcon!,
                    fit: BoxFit.contain,
                    maxWidthDiskCache: 600,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 100),
                    placeholder: (_, __) => _initials(s.name),
                    errorWidget: (_, __, ___) => _initials(s.name),
                  )
                : _initials(s.name),
          ),
          const SizedBox(height: 10),
          Text(
            _cleanText(s.name),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: focused ? Colors.white : AppColors.whiteDim,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _movieCard(VodStream v, bool focused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: 300,
      decoration: _cardDecoration(focused),
      transform: focused ? _scaleUp : Matrix4.identity(),
      transformAlignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          v.streamIcon != null && v.streamIcon!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: v.streamIcon!,
                  fit: BoxFit.cover,
                  maxWidthDiskCache: 800,
                  memCacheWidth: 500,
                  placeholder: (_, __) => Container(color: AppColors.bgCard),
                  errorWidget: (_, __, ___) => _initials(v.name),
                )
              : _initials(v.name),
          _gradientOverlay(v.name),
          if (v.ratingValue > 0) _ratingBadge(v.ratingValue),
        ],
      ),
    );
  }

  Widget _seriesCard(SeriesItem s, bool focused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: 300,
      decoration: _cardDecoration(focused),
      transform: focused ? _scaleUp : Matrix4.identity(),
      transformAlignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          s.cover != null && s.cover!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: s.cover!,
                  fit: BoxFit.cover,
                  maxWidthDiskCache: 800,
                  memCacheWidth: 500,
                  placeholder: (_, __) => Container(color: AppColors.bgCard),
                  errorWidget: (_, __, ___) => _initials(s.name),
                )
              : _initials(s.name),
          _gradientOverlay(s.name),
          if (s.ratingValue > 0) _ratingBadge(s.ratingValue),
        ],
      ),
    );
  }

  Widget _buildGuideRow(LiveStream s, bool focused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: focused ? AppColors.red.withOpacity(0.15) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: focused ? AppColors.red : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: s.streamIcon != null && s.streamIcon!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: s.streamIcon!,
                    fit: BoxFit.contain,
                    maxWidthDiskCache: 200,
                  )
                : _initials(s.name),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              _cleanText(s.name),
              style: TextStyle(
                color: focused ? Colors.white : AppColors.whiteDim,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.play_circle_outline,
            color: focused ? AppColors.red : AppColors.whiteMuted,
            size: 32,
          ),
        ],
      ),
    );
  }

  // ─── SETTINGS ───

  Widget _buildSettingsContent(AppProvider p) {
    final items = <(String, String, IconData)>[
      ('Server', p.userInfo?.message ?? 'Connected', Icons.dns_rounded),
      ('Status', p.userInfo?.status ?? 'N/A', Icons.check_circle_outline),
      ('Max Connections', p.userInfo?.maxConnections?.toString() ?? 'N/A', Icons.people_outline),
      ('Expire Date', p.userInfo?.expDate ?? 'N/A', Icons.calendar_today),
      ('Logout', 'Sign out', Icons.logout_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < items.length; i++) ...[
            _settingsTile(i, items[i].$1, items[i].$2, items[i].$3, isLogout: i == 4),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile(int index, String label, String value, IconData icon, {bool isLogout = false}) {
    final isFocused = _zone == _Zone.content && _contentIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isFocused
            ? (isLogout ? AppColors.red.withOpacity(0.2) : AppColors.red.withOpacity(0.1))
            : AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? (isLogout ? AppColors.red : AppColors.red) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isLogout ? AppColors.red : AppColors.whiteDim),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isLogout ? AppColors.red : AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!isLogout)
            Text(
              value,
              style: TextStyle(color: AppColors.whiteMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ───

  BoxDecoration _cardDecoration(bool focused) {
    return BoxDecoration(
      color: focused ? AppColors.red.withOpacity(0.12) : AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: focused ? AppColors.red : Colors.white.withOpacity(0.04),
        width: focused ? 2.5 : 1,
      ),
      boxShadow: focused
          ? [BoxShadow(color: AppColors.red.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)]
          : [],
    );
  }

  static final _scaleUp = Matrix4.identity()..scale(1.04);

  Widget _gradientOverlay(String title) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.9), Colors.transparent],
          ),
        ),
        child: Text(
          _cleanText(title),
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _ratingBadge(double rating) {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name) {
    final clean = name.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final parts = clean.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].length >= 2
            ? parts[0].substring(0, 2).toUpperCase()
            : 'TV');

    const palette = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFAB47BC),
      Color(0xFFEF5350),
      Color(0xFF42A5F5),
      Color(0xFFFFA726),
      Color(0xFF66BB6A),
    ];
    final color = palette[name.hashCode.abs() % palette.length];

    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{FE00}-\u{FE0F}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u{200D}]', unicode: true), '')
        .trim();
  }
}
