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
  bool _loadingEpg = false;
  List<LiveStream> _channels = [];
  String? _selectedCategoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_channels.isEmpty) {
      _loadChannels();
    }
  }

  Future<void> _loadChannels() async {
    final provider = context.read<AppProvider>();
    if (provider.liveCategories.isEmpty) {
      await provider.loadLiveCategories();
    }
    if (provider.liveCategories.isNotEmpty) {
      _selectedCategoryId = provider.liveCategories.first.categoryId;
      final streams = await provider.service.getLiveStreams(categoryId: _selectedCategoryId);
      setState(() {
        _channels = streams.take(50).toList(); // Limit for performance
      });
      _loadEpgForChannels();
    }
  }

  Future<void> _loadEpgForChannels() async {
    if (_loadingEpg) return;
    _loadingEpg = true;
    final provider = context.read<AppProvider>();
    for (final ch in _channels.take(20)) {
      if (!_epgCache.containsKey(ch.streamId)) {
        try {
          final epg = await provider.getShortEpg(ch.streamId);
          if (mounted) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: AppColors.bgSurface,
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.whiteDim),
              const SizedBox(width: 8),
              Text(
                '${_dayName(now.weekday)}, ${_monthName(now.month)} ${now.day}, ${now.year}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
              // Category dropdown
              if (provider.liveCategories.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategoryId,
                    dropdownColor: AppColors.bgCard,
                    style: const TextStyle(color: AppColors.white, fontSize: 12),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.whiteDim),
                    items: provider.liveCategories.take(30).map((cat) {
                      return DropdownMenuItem(
                        value: cat.categoryId,
                        child: Text(cat.categoryName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() {
                          _selectedCategoryId = val;
                          _epgCache.clear();
                        });
                        final streams = await provider.service.getLiveStreams(categoryId: val);
                        setState(() {
                          _channels = streams.take(50).toList();
                        });
                        _loadEpgForChannels();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),

        // EPG Grid
        Expanded(
          child: _channels.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.red))
              : ListView.builder(
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final ch = _channels[index];
                    final epg = _epgCache[ch.streamId] ?? [];
                    return _EpgRow(
                      channel: ch,
                      epgEntries: epg,
                      onTap: () {
                        final url = provider.buildLiveUrl(ch.streamId);
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PlayerScreen(url: url, title: ch.name, isLive: true),
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
  final VoidCallback onTap;

  const _EpgRow({required this.channel, required this.epgEntries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentEpg = epgEntries.where((e) => e.isCurrentlyAiring).toList();
    final nextEpg = epgEntries.where((e) => !e.isCurrentlyAiring).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
          ),
          child: Row(
            children: [
              // Channel info
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    // Channel logo
                    Container(
                      width: 36,
                      height: 36,
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
                                errorWidget: (_, __, ___) => const Icon(Icons.tv, size: 16, color: AppColors.whiteMuted),
                              ),
                            )
                          : const Icon(Icons.tv, size: 16, color: AppColors.whiteMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        channel.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // EPG entries
              Expanded(
                child: epgEntries.isEmpty
                    ? Text('No EPG data', style: TextStyle(fontSize: 11, color: AppColors.whiteMuted))
                    : Row(
                        children: [
                          if (currentEpg.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NOW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.red, letterSpacing: 1)),
                                    Text(
                                      currentEpg.first.title ?? '',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ...nextEpg.take(2).map((e) => Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    e.title ?? '',
                                    style: const TextStyle(fontSize: 10, color: AppColors.whiteDim),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
