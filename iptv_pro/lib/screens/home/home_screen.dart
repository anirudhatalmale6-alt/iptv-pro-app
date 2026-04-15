import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _categoriesLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_categoriesLoaded) {
      _categoriesLoaded = true;
      final provider = context.read<AppProvider>();
      provider.loadLiveCategories();
      // Load first category streams
      Future.delayed(const Duration(milliseconds: 500), () {
        if (provider.liveCategories.isNotEmpty) {
          provider.loadLiveStreams(provider.liveCategories.first.categoryId);
        }
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? AppColors.red : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        cat.categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.white : AppColors.whiteDim,
                        ),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured player area
          if (provider.currentStreams.isNotEmpty)
            _buildFeaturedArea(provider),
          const SizedBox(height: 20),

          // Channel grid
          Text(
            'Channels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildChannelGrid(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedArea(AppProvider provider) {
    final stream = provider.currentStreams.first;
    return GestureDetector(
      onTap: () => _playLive(stream),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: RadialGradient(
                    center: const Alignment(-0.5, 0),
                    colors: [AppColors.red.withOpacity(0.08), Colors.transparent],
                    radius: 1.2,
                  ),
                ),
              ),
            ),
            // Live badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 12)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
            // Quality badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Text('FHD', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
            // Play icon
            Center(
              child: Icon(Icons.play_arrow_rounded, size: 56, color: Colors.white.withOpacity(0.4)),
            ),
            // Bottom info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stream.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text('Tap to watch', style: TextStyle(fontSize: 12, color: AppColors.whiteDim)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelGrid(AppProvider provider) {
    final streams = provider.currentStreams;
    if (streams.isEmpty) {
      return Center(
        child: Text('No channels in this category', style: TextStyle(color: AppColors.whiteMuted)),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 6 : (MediaQuery.of(context).size.width > 600 ? 4 : 3),
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: streams.length,
      itemBuilder: (context, index) => _ChannelCard(
        stream: streams[index],
        onTap: () => _playLive(streams[index]),
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

  Widget _buildMobileContent(AppProvider provider) {
    return Column(
      children: [
        // Category chips
        if (provider.liveCategories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        child: Text(
                          cat.categoryName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.whiteDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: provider.isLoading && provider.currentStreams.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.red))
              : _buildChannelGrid(provider),
        ),
      ],
    );
  }

  void _playLive(LiveStream stream) {
    final provider = context.read<AppProvider>();
    final url = provider.buildLiveUrl(stream.streamId);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        url: url,
        title: stream.name,
        isLive: true,
      ),
    ));
  }
}

class _ChannelCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChannelCard({required this.stream, required this.onTap, this.onLongPress});

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
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Channel icon
              Expanded(
                child: stream.streamIcon != null && stream.streamIcon!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: stream.streamIcon!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => _buildPlaceholderIcon(),
                        errorWidget: (_, __, ___) => _buildPlaceholderIcon(),
                      )
                    : _buildPlaceholderIcon(),
              ),
              const SizedBox(height: 6),
              Text(
                stream.name,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.red.withOpacity(0.3), AppColors.redDark.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.tv, color: AppColors.whiteDim, size: 20),
    );
  }
}
