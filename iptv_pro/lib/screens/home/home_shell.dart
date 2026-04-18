import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../config/theme.dart';
import '../../providers/mini_player_provider.dart';
import '../../providers/app_provider.dart';
import '../../services/tv_dpad_service.dart';
import '../../widgets/tv_focusable.dart';
import '../home/home_screen.dart';
import '../tv_guide/tv_guide_screen.dart';
import '../movies/movies_screen.dart';
import '../series/series_screen.dart';
import '../settings/settings_screen.dart';
import '../player/player_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final List<FocusNode> _tabFocusNodes = List.generate(5, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _tabFocusNodes[0].requestFocus();
      });
    });
  }

  @override
  void dispose() {
    for (final node in _tabFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Check if current focus is on a tab button in the top bar
  bool _isFocusOnTab() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    for (final tabNode in _tabFocusNodes) {
      if (focus == tabNode) return true;
      // Check if focus is a descendant of a tab node
      FocusNode? parent = focus.parent;
      while (parent != null) {
        if (parent == tabNode) return true;
        parent = parent.parent;
      }
    }
    return false;
  }

  /// Get which tab index is currently focused
  int _focusedTabIndex() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return _currentIndex;
    for (int i = 0; i < _tabFocusNodes.length; i++) {
      if (focus == _tabFocusNodes[i]) return i;
      FocusNode? parent = focus.parent;
      while (parent != null) {
        if (parent == _tabFocusNodes[i]) return i;
        parent = parent.parent;
      }
    }
    return _currentIndex;
  }

  /// Root D-pad handler with zone-aware navigation.
  /// Tab bar zone: LEFT/RIGHT switch tabs, DOWN enters content.
  /// Content zone: spatial navigation, UP at top returns to tab bar.
  KeyEventResult _handleDpadKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final primaryFocus = FocusManager.instance.primaryFocus;
    final onTab = _isFocusOnTab();

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (onTab) {
        final idx = _focusedTabIndex();
        if (idx > 0) _tabFocusNodes[idx - 1].requestFocus();
        return KeyEventResult.handled;
      }
      _moveFocusInDirection(primaryFocus, TraversalDirection.left);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (onTab) {
        final idx = _focusedTabIndex();
        if (idx < _tabFocusNodes.length - 1) _tabFocusNodes[idx + 1].requestFocus();
        return KeyEventResult.handled;
      }
      _moveFocusInDirection(primaryFocus, TraversalDirection.right);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (onTab) {
        // Select the focused tab, then move focus to content via spatial nav
        final idx = _focusedTabIndex();
        if (idx != _currentIndex) {
          setState(() => _currentIndex = idx);
          // Wait for rebuild so new tab content is focusable
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tabFocusNodes[idx].focusInDirection(TraversalDirection.down);
            }
          });
        } else {
          // Same tab — use spatial navigation to find content below
          primaryFocus?.focusInDirection(TraversalDirection.down);
        }
        return KeyEventResult.handled;
      }
      _moveFocusInDirection(primaryFocus, TraversalDirection.down);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (onTab) {
        return KeyEventResult.handled; // Already on tab bar, nowhere to go
      }
      // Try spatial up first
      final moved = primaryFocus?.focusInDirection(TraversalDirection.up) ?? false;
      if (!moved) {
        // At top of content — return to tab bar
        _tabFocusNodes[_currentIndex].requestFocus();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.select ||
               key == LogicalKeyboardKey.enter ||
               key == LogicalKeyboardKey.gameButtonA) {
      if (onTab) {
        // Select the focused tab
        final idx = _focusedTabIndex();
        if (idx != _currentIndex) {
          setState(() => _currentIndex = idx);
        }
        return KeyEventResult.handled;
      }
      if (TvDpadService.onSelect != null) {
        TvDpadService.onSelect!();
        return KeyEventResult.handled;
      }
      // No TvFocusable focused (e.g. text field) — let Flutter handle normally
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  void _moveFocusInDirection(FocusNode? current, TraversalDirection direction) {
    if (current == null || current.context == null) {
      _tabFocusNodes[_currentIndex].requestFocus();
      return;
    }
    // Pure spatial navigation — no nextFocus/previousFocus fallback
    // which would jump to wrong widgets across tab boundaries
    current.focusInDirection(direction);
  }

  final _screens = const [
    HomeScreen(),
    TvGuideScreen(),
    MoviesScreen(),
    SeriesScreen(),
    SettingsScreen(),
  ];

  final _tabs = const [
    _TabItem(icon: Icons.home_rounded, label: 'HOME'),
    _TabItem(icon: Icons.grid_view_rounded, label: 'TV GUIDE'),
    _TabItem(icon: Icons.movie_outlined, label: 'MOVIES'),
    _TabItem(icon: Icons.tv_rounded, label: 'SERIES'),
    _TabItem(icon: Icons.settings_rounded, label: 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Focus(
        onKeyEvent: _handleDpadKeyEvent,
        child: Stack(
          children: [
            Column(
              children: [
                if (isWide) _buildTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      for (int i = 0; i < _screens.length; i++)
                        Focus(
                          // Wrapper is NOT focusable itself — only gates descendants
                          canRequestFocus: false,
                          descendantsAreFocusable: i == _currentIndex,
                          descendantsAreTraversable: i == _currentIndex,
                          child: _screens[i],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Mini player overlay (hidden on HOME tab - split-screen handles it there)
            if (_currentIndex != 0) _MiniPlayerOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.98),
        border: Border(bottom: BorderSide(color: AppColors.red.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/veltrix_header.png',
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              'VELTRIX TV',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
          ),
          const SizedBox(width: 40),

          // Tabs
          ..._tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final tab = entry.value;
            final isActive = i == _currentIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TvFocusable(
                autofocus: i == 0,
                focusNode: _tabFocusNodes[i],
                borderRadius: BorderRadius.circular(8),
                focusColor: AppColors.red,
                onTap: () => setState(() => _currentIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.red.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tab.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      color: isActive ? AppColors.white : AppColors.whiteMuted,
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Stats badges
          _StatBadge(value: '50K+', label: 'Live'),
          const SizedBox(width: 10),
          _StatBadge(value: '160K+', label: 'Movies'),
          const SizedBox(width: 10),
          _StatBadge(value: '70K+', label: 'Series'),
          const SizedBox(width: 16),

          // Clock
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 30)),
            builder: (context, _) {
              final now = DateTime.now();
              return Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.white,
                  letterSpacing: 1,
                ),
              );
            },
          ),
          const SizedBox(width: 16),

          // User avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.red, AppColors.redSoft],
              ),
              boxShadow: [BoxShadow(color: AppColors.red.withOpacity(0.3), blurRadius: 8)],
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.red.withOpacity(0.15))),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bgSurface,
        selectedItemColor: AppColors.red,
        unselectedItemColor: AppColors.whiteMuted,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: _tabs.map((t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class _MiniPlayerOverlay extends StatefulWidget {
  @override
  State<_MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<_MiniPlayerOverlay> {
  Offset _position = const Offset(16, 100);

  @override
  Widget build(BuildContext context) {
    return Consumer<MiniPlayerProvider>(
      builder: (context, miniPlayer, _) {
        if (!miniPlayer.visible || miniPlayer.videoController == null) return const SizedBox();

        final screenSize = MediaQuery.of(context).size;
        const width = 200.0;
        const height = 120.0;

        return Positioned(
          left: _position.dx.clamp(0.0, screenSize.width - width),
          top: _position.dy.clamp(0.0, screenSize.height - height - 80),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position.dx + details.delta.dx,
                  _position.dy + details.delta.dy,
                );
              });
            },
            onTap: () {
              final result = miniPlayer.takePlayerAndController();
              if (result != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    url: miniPlayer.url ?? '',
                    title: miniPlayer.title ?? '',
                    isLive: miniPlayer.isLive,
                    channelIcon: miniPlayer.channelIcon,
                    streamId: miniPlayer.streamId,
                    channelList: miniPlayer.channelList,
                    currentChannelIndex: miniPlayer.channelIndex,
                    existingPlayer: result.$1,
                    existingVideoController: result.$2,
                  ),
                ));
              }
            },
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(10),
              shadowColor: Colors.black54,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.red.withOpacity(0.5), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Video(
                        controller: miniPlayer.videoController!,
                        controls: NoVideoControls,
                      ),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                            ),
                          ),
                          child: Text(
                            miniPlayer.title ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => miniPlayer.dismiss(),
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                      if (miniPlayer.isLive)
                        Positioned(
                          top: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
                            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  const _StatBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: AppColors.redSoft, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: AppColors.whiteDim, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
