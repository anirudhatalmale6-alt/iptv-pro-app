import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';

class TvGuideScreen extends StatefulWidget {
  const TvGuideScreen({super.key});

  @override
  State<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends State<TvGuideScreen> {
  final Map<int, List<EpgEntry>> _epgCache = {};
  bool _loadingChannels = false;
  bool _loadingEpg = false;
  List<LiveStream> _channels = [];
  String? _selectedCategoryId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadChannels();
    }
  }

  Future<void> _loadChannels() async {
    setState(() => _loadingChannels = true);
    final provider = context.read<AppProvider>();
    try {
      if (provider.liveCategories.isEmpty) {
        await provider.loadLiveCategories();
      }
      if (provider.liveCategories.isNotEmpty) {
        _selectedCategoryId ??= provider.liveCategories.first.categoryId;
        final streams = await provider.service.getLiveStreams(categoryId: _selectedCategoryId);
        if (mounted) {
          setState(() {
            _channels = streams;
            _loadingChannels = false;
          });
          _loadEpgForChannels();
        }
      } else {
        if (mounted) setState(() => _loadingChannels = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  Future<void> _loadEpgForChannels() async {
    if (_loadingEpg) return;
    _loadingEpg = true;
    final provider = context.read<AppProvider>();
    // Load EPG for all visible channels (up to 50)
    for (final ch in _channels.take(50)) {
      if (!_epgCache.containsKey(ch.streamId)) {
        try {
          final epg = await provider.getShortEpg(ch.streamId);
          if (mounted && epg.isNotEmpty) {
            setState(() {
              _epgCache[ch.streamId] = epg;
            });
          }
        } catch (_) {}
      }
    }
    _loadingEpg = false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.bgSurface,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.whiteDim),
                  const SizedBox(width: 8),
                  Text(
                    '${_dayName(now.weekday)}, ${_monthName(now.month)} ${now.day}, ${now.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        const Text('NOW', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_loadingEpg)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.red, strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              // Category chips
              if (provider.liveCategories.isNotEmpty)
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.liveCategories.length,
                    itemBuilder: (context, index) {
                      final cat = provider.liveCategories[index];
                      final isSelected = _selectedCategoryId == cat.categoryId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = cat.categoryId;
                              _epgCache.clear();
                            });
                            _loadChannels();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.red : AppColors.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? AppColors.red : Colors.white10),
                            ),
                            child: Text(cat.categoryName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.whiteDim)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),

        // EPG Grid
        Expanded(
          child: _loadingChannels && _channels.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.red),
                      SizedBox(height: 12),
                      Text('Loading TV Guide...', style: TextStyle(color: AppColors.whiteMuted, fontSize: 12)),
                    ],
                  ),
                )
              : _channels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tv_off, size: 48, color: AppColors.whiteMuted),
                          const SizedBox(height: 8),
                          const Text('No channels found', style: TextStyle(color: AppColors.whiteMuted)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadChannels,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _channels.length,
                      itemBuilder: (context, index) {
                        final ch = _channels[index];
                        final epg = _epgCache[ch.streamId] ?? [];
                        return _EpgRow(
                          channel: ch,
                          epgEntries: epg,
                          isLoadingEpg: !_epgCache.containsKey(ch.streamId) && _loadingEpg,
                          onTap: () {
                            final url = provider.buildLiveUrl(ch.streamId);
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                url: url,
                                title: ch.name,
                                isLive: true,
                                channelIcon: ch.streamIcon,
                                streamId: ch.streamId,
                                channelList: _channels,
                                currentChannelIndex: index,
                              ),
                            ));
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _dayName(int d) => ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d];
  String _monthName(int m) => ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

class _EpgRow extends StatelessWidget {
  final LiveStream channel;
  final List<EpgEntry> epgEntries;
  final bool isLoadingEpg;
  final VoidCallback onTap;

  const _EpgRow({required this.channel, required this.epgEntries, this.isLoadingEpg = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentEpg = epgEntries.where((e) => e.isCurrentlyAiring).toList();
    final upcomingEpg = epgEntries.where((e) => e.isUpcoming).take(2).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
          ),
          child: Row(
            children: [
              // Channel info
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.bgCard,
                      ),
                      child: channel.streamIcon != null && channel.streamIcon!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: channel.streamIcon!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 14, color: AppColors.whiteMuted),
                              ),
                            )
                          : const Icon(Icons.tv, size: 14, color: AppColors.whiteMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channel.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // EPG entries
              Expanded(
                child: isLoadingEpg
                    ? Row(children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: AppColors.whiteMuted, strokeWidth: 1.5)),
                        const SizedBox(width: 8),
                        Text('Loading...', style: TextStyle(fontSize: 10, color: AppColors.whiteMuted)),
                      ])
                    : epgEntries.isEmpty
                        ? Text('No EPG data available', style: TextStyle(fontSize: 10, color: AppColors.whiteMuted))
                        : Row(
                            children: [
                              // Currently airing
                              if (currentEpg.isNotEmpty)
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.red.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text('NOW', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: AppColors.red, letterSpacing: 0.8)),
                                            const SizedBox(width: 6),
                                            if (currentEpg.first.timeRange.isNotEmpty)
                                              Text(currentEpg.first.timeRange, style: TextStyle(fontSize: 8, color: AppColors.whiteMuted)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentEpg.first.title ?? 'Unknown',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (epgEntries.isNotEmpty)
                                // No currently airing - show all as upcoming
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgCard,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (epgEntries.first.timeRange.isNotEmpty)
                                          Text(epgEntries.first.timeRange, style: TextStyle(fontSize: 8, color: AppColors.whiteMuted)),
                                        Text(
                                          epgEntries.first.title ?? 'Unknown',
                                          style: const TextStyle(fontSize: 10, color: AppColors.whiteDim),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Upcoming
                              ...upcomingEpg.map((e) => Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgCard,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (e.timeRange.isNotEmpty)
                                            Text(e.timeRange, style: TextStyle(fontSize: 8, color: AppColors.whiteMuted)),
                                          Text(
                                            e.title ?? 'Unknown',
                                            style: const TextStyle(fontSize: 9, color: AppColors.whiteDim),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
