import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../config/theme.dart';
import '../../providers/mini_player_provider.dart';
import '../../providers/app_provider.dart';
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
      body: Stack(
        children: [
          Column(
            children: [
              if (isWide) _buildTopBar(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          // Mini player overlay (hidden on HOME tab - split-screen handles it there)
          if (_currentIndex != 0) _MiniPlayerOverlay(),
        ],
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.red, AppColors.redDark],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 16)],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'IPTV Pro',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
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
        if (!miniPlayer.visible || miniPlayer.controller == null) return const SizedBox();

        final ctrl = miniPlayer.controller!;
        final screenSize = MediaQuery.of(context).size;
        // Mini player size: 200x120 (16:9-ish)
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
              // Go back to full screen player
              final ctrl = miniPlayer.takeController();
              if (ctrl != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    url: miniPlayer.url ?? '',
                    title: miniPlayer.title ?? '',
                    isLive: miniPlayer.isLive,
                    channelIcon: miniPlayer.channelIcon,
                    streamId: miniPlayer.streamId,
                    channelList: miniPlayer.channelList,
                    currentChannelIndex: miniPlayer.channelIndex,
                    existingController: ctrl,
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
                      if (ctrl.value.isInitialized)
                        VideoPlayer(ctrl)
                      else
                        const Center(child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2)),
                      // Title bar
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
                      // Close button
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
                      // Live badge
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
