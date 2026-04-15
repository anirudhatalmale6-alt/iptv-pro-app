import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';
import '../player/multi_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _categoriesLoaded = false;
  final List<LiveStream> _recentChannels = [];
  bool _showSearch = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<LiveStream> _searchResults = [];
  bool _isSearching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoriesLoaded) {
      _categoriesLoaded = true;
      final provider = context.read<AppProvider>();
      provider.loadLiveCategories();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (provider.liveCategories.isNotEmpty) {
          provider.loadLiveStreams(provider.liveCategories.first.categoryId);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    if (query.length >= 2) {
      _performSearch(query);
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final provider = context.read<AppProvider>();
    // Search across all live streams
    if (provider.allLiveStreams.isEmpty) {
      await provider.loadLiveStreams(null); // Load all streams
    }
    final allStreams = provider.allLiveStreams.isNotEmpty ? provider.allLiveStreams : provider.currentStreams;
    final results = allStreams.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
    if (mounted && _searchQuery == query) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (isWide) {
          return Row(
            children: [
              _buildSidebar(provider),
              Expanded(child: _buildMainContent(provider)),
            ],
          );
        }
        return _buildMobileContent(provider);
      },
    );
  }

  Widget _buildSidebar(AppProvider provider) {
    return Container(
      width: 200,
      color: AppColors.bgSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              height: 34,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  hintStyle: TextStyle(color: AppColors.whiteMuted, fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.whiteMuted),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          // Favorites entry
          _SidebarItem(
            icon: Icons.star,
            iconColor: AppColors.gold,
            label: 'Favorites',
            count: provider.favoriteStreamIds.length,
            isSelected: provider.selectedLiveCategoryId == '__favorites__',
            onTap: () => provider.loadLiveStreams('__favorites__'),
          ),
          // Recent
          if (_recentChannels.isNotEmpty)
            _SidebarItem(
              icon: Icons.history,
              iconColor: AppColors.blue,
              label: 'Recent',
              count: _recentChannels.length,
              isSelected: false,
              onTap: () {},
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('CATEGORIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.whiteMuted)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.liveCategories.length,
              itemBuilder: (context, index) {
                final cat = provider.liveCategories[index];
                final isSelected = cat.categoryId == provider.selectedLiveCategoryId;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => provider.loadLiveStreams(cat.categoryId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.red.withOpacity(0.15) : null,
                        border: Border(left: BorderSide(color: isSelected ? AppColors.red : Colors.transparent, width: 3)),
                      ),
                      child: Text(
                        cat.categoryName,
                        style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.white : AppColors.whiteDim),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppProvider provider) {
    if (provider.isLoading && provider.currentStreams.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.red));
    }

    final streams = _filterStreams(provider.currentStreams);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action row
          Row(
            children: [
              Text('Channels', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.white)),
              const SizedBox(width: 8),
              Text('(${streams.length})', style: TextStyle(color: AppColors.whiteMuted, fontSize: 13)),
              const Spacer(),
              // Multi-view button
              if (streams.length >= 2)
                _ActionChip(
                  icon: Icons.grid_view_rounded,
                  label: 'Multi View',
                  onTap: () => _openMultiView(streams),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Featured
          if (streams.isNotEmpty) _buildFeaturedArea(provider, streams.first),
          const SizedBox(height: 16),
          // Grid
          Expanded(child: _buildChannelGrid(provider, streams)),
        ],
      ),
    );
  }

  Widget _buildMobileContent(AppProvider provider) {
    final streams = _filterStreams(provider.currentStreams);

    return Column(
      children: [
        // Top bar with search and multi-view
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search channels...',
                      hintStyle: TextStyle(color: AppColors.whiteMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.whiteMuted),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
              if (streams.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => _openMultiView(streams),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.grid_view_rounded, color: AppColors.red, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Category chips
        if (provider.liveCategories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: provider.liveCategories.length,
              itemBuilder: (context, index) {
                final cat = provider.liveCategories[index];
                final isSelected = cat.categoryId == provider.selectedLiveCategoryId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => provider.loadLiveStreams(cat.categoryId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.red : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.red : Colors.white10),
                      ),
                      child: Center(
                        child: Text(cat.categoryName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.whiteDim)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: provider.isLoading && streams.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.red))
              : _buildChannelGrid(provider, streams),
        ),
      ],
    );
  }

  List<LiveStream> _filterStreams(List<LiveStream> streams) {
    if (_searchQuery.length >= 2) return _searchResults;
    return streams;
  }

  Widget _buildFeaturedArea(AppProvider provider, LiveStream stream) {
    return GestureDetector(
      onTap: () => _playLive(provider, stream),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: RadialGradient(center: const Alignment(-0.5, 0), colors: [AppColors.red.withOpacity(0.08), Colors.transparent], radius: 1.2),
                ),
              ),
            ),
            Positioned(top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 12)]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
              ),
            ),
            Center(child: Icon(Icons.play_circle_filled, size: 56, color: Colors.white.withOpacity(0.4))),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)]),
                ),
                child: Text(stream.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelGrid(AppProvider provider, List<LiveStream> streams) {
    if (streams.isEmpty) {
      return Center(child: Text('No channels found', style: TextStyle(color: AppColors.whiteMuted)));
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 6 : (MediaQuery.of(context).size.width > 600 ? 4 : 3),
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: streams.length,
      itemBuilder: (context, index) => _ChannelCard(
        stream: streams[index],
        isFavorite: provider.isFavorite(streams[index].streamId),
        onTap: () => _playLive(provider, streams[index]),
        onLongPress: () {
          provider.toggleFavorite(streams[index].streamId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.isFavorite(streams[index].streamId) ? 'Added to favorites' : 'Removed from favorites'),
              duration: const Duration(seconds: 1),
              backgroundColor: AppColors.bgCard,
            ),
          );
        },
      ),
    );
  }

  void _playLive(AppProvider provider, LiveStream stream) {
    // Add to recents
    _recentChannels.removeWhere((s) => s.streamId == stream.streamId);
    _recentChannels.insert(0, stream);
    if (_recentChannels.length > 20) _recentChannels.removeLast();

    final url = provider.buildLiveUrl(stream.streamId);
    final streams = provider.currentStreams;
    final idx = streams.indexOf(stream);

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: url,
        title: stream.name,
        isLive: true,
        channelIcon: stream.streamIcon,
        streamId: stream.streamId,
        channelList: streams,
        currentChannelIndex: idx >= 0 ? idx : 0,
      ),
    ));
  }

  void _openMultiView(List<LiveStream> streams) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MultiViewScreen(channels: streams.take(10).toList()),
    ));
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.iconColor, required this.label, required this.count, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.red.withOpacity(0.15) : null,
            border: Border(left: BorderSide(color: isSelected ? AppColors.red : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.white : AppColors.whiteDim))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.whiteMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final LiveStream stream;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChannelCard({required this.stream, required this.isFavorite, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: stream.streamIcon != null && stream.streamIcon!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: stream.streamIcon!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  const SizedBox(height: 4),
                  Text(stream.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ],
              ),
              if (isFavorite)
                const Positioned(top: 0, right: 0, child: Icon(Icons.star, color: AppColors.gold, size: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.red.withOpacity(0.3), AppColors.redDark.withOpacity(0.3)]), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.tv, color: AppColors.whiteDim, size: 18),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.red.withOpacity(0.3))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.red),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
