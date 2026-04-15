import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final SeriesItem series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesInfo? _info;
  bool _loading = true;
  String? _selectedSeason;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final provider = context.read<AppProvider>();
      final info = await provider.getSeriesInfo(widget.series.seriesId);
      setState(() {
        _info = info;
        _loading = false;
        if (info.seasons.isNotEmpty) {
          _selectedSeason = info.seasons.keys.first;
        }
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        title: Text(widget.series.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : _info == null
              ? const Center(child: Text('Failed to load series info', style: TextStyle(color: AppColors.whiteMuted)))
              : CustomScrollView(
                  slivers: [
                    // Series header
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cover
                            if (widget.series.cover != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.series.cover!,
                                  width: 120,
                                  height: 170,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 120,
                                    height: 170,
                                    color: AppColors.bgCard,
                                    child: const Icon(Icons.tv, color: AppColors.whiteMuted),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.series.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                                  const SizedBox(height: 8),
                                  if (widget.series.genre != null)
                                    Text(widget.series.genre!, style: const TextStyle(color: AppColors.whiteDim, fontSize: 13)),
                                  if (widget.series.releaseDate != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(widget.series.releaseDate!, style: const TextStyle(color: AppColors.whiteMuted, fontSize: 12)),
                                    ),
                                  if (widget.series.ratingValue > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star, color: AppColors.gold, size: 16),
                                          const SizedBox(width: 4),
                                          Text(widget.series.ratingValue.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                  if (widget.series.plot != null && widget.series.plot!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        widget.series.plot!,
                                        style: const TextStyle(color: AppColors.whiteDim, fontSize: 12, height: 1.4),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (widget.series.cast != null && widget.series.cast!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('Cast: ${widget.series.cast}', style: const TextStyle(color: AppColors.whiteMuted, fontSize: 11), maxLines: 2),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Season tabs
                    if (_info!.seasons.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            height: 38,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _info!.seasons.keys.map((season) {
                                final isSelected = season == _selectedSeason;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedSeason = season),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.red : AppColors.bgCard,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isSelected ? AppColors.red : Colors.white10),
                                      ),
                                      child: Text(
                                        'Season $season',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : AppColors.whiteDim,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Episodes
                    if (_selectedSeason != null && _info!.seasons[_selectedSeason] != null)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final episode = _info!.seasons[_selectedSeason]![index];
                            return _EpisodeTile(
                              episode: episode,
                              onTap: () {
                                final provider = context.read<AppProvider>();
                                final ext = episode.containerExtension ?? 'mp4';
                                final url = provider.buildSeriesUrl(int.parse(episode.id ?? '0'), ext);
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    url: url,
                                    title: '${widget.series.name} - ${episode.title ?? 'Episode ${episode.episodeNum}'}',
                                  ),
                                ));
                              },
                            );
                          },
                          childCount: _info!.seasons[_selectedSeason]!.length,
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final VoidCallback onTap;

  const _EpisodeTile({required this.episode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
          ),
          child: Row(
            children: [
              // Episode number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${episode.episodeNum ?? '?'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.red),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title ?? 'Episode ${episode.episodeNum}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (episode.plot != null && episode.plot!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(episode.plot!, style: const TextStyle(color: AppColors.whiteMuted, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    if (episode.duration != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(episode.duration!, style: const TextStyle(color: AppColors.whiteMuted, fontSize: 10)),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_outline, color: AppColors.red, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
