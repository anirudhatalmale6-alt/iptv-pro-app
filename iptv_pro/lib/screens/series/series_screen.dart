import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import 'series_detail_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  bool _loaded = false;
  String? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showFavorites = false;
  List<SeriesItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _initSeries();
    }
  }

  Future<void> _initSeries() async {
    final provider = context.read<AppProvider>();

    // Wait for categories if they're being loaded by _autoLoadCategories
    if (provider.seriesCategories.isEmpty) {
      await provider.loadSeriesCategories();
    }

    if (!mounted) return;

    if (provider.seriesCategories.isNotEmpty) {
      // Only load if no data yet and not already loading
      if (provider.currentSeries.isEmpty && !provider.isLoadingSeries) {
        final firstCat = provider.seriesCategories.first.categoryId;
        setState(() => _selectedCategoryId = firstCat);
        await provider.loadSeries(firstCat);
      } else if (_selectedCategoryId == null && provider.selectedSeriesCategoryId != null) {
        // Sync selected category with provider
        setState(() => _selectedCategoryId = provider.selectedSeriesCategoryId);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    if (query.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        _performSearch(query);
      });
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
    final results = await provider.searchSeries(query);
    if (mounted && _searchQuery == query) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Re-trigger search when all data finishes loading in background
        if (_searchQuery.length >= 2 && _searchResults.isEmpty && provider.allSeries.isNotEmpty) {
          _performSearch(_searchQuery);
        }

        List<SeriesItem> series;
        if (_searchQuery.length >= 2) {
          series = _searchResults;
        } else if (_showFavorites) {
          series = provider.currentSeries.where((s) => provider.isSeriesFavorite(s.seriesId)).toList();
        } else {
          series = provider.currentSeries.toList();
        }

        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              color: AppColors.bgSurface,
              child: Column(
                children: [
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search series...',
                        hintStyle: TextStyle(color: AppColors.whiteMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.whiteMuted, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppColors.whiteMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.bgCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.seriesCategories.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildChip(
                            'My List',
                            _showFavorites,
                            () {
                              setState(() {
                                _showFavorites = !_showFavorites;
                                if (_showFavorites) _selectedCategoryId = null;
                              });
                            },
                            icon: Icons.bookmark,
                          );
                        }
                        if (index == 1) {
                          return _buildChip('All', !_showFavorites && _selectedCategoryId == null, () async {
                            setState(() {
                              _selectedCategoryId = null;
                              _showFavorites = false;
                            });
                            await provider.loadSeries(null);
                            if (mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Loaded ${provider.currentSeries.length} series (All)'),
                                  duration: const Duration(seconds: 3),
                                  backgroundColor: AppColors.bgCard,
                                ),
                              );
                            }
                          });
                        }
                        final cat = provider.seriesCategories[index - 2];
                        return _buildChip(cat.categoryName, !_showFavorites && _selectedCategoryId == cat.categoryId, () async {
                          debugPrint('Series chip tapped: ${cat.categoryId} - ${cat.categoryName}');
                          setState(() {
                            _selectedCategoryId = cat.categoryId;
                            _showFavorites = false;
                          });
                          await provider.loadSeries(cat.categoryId);
                          if (mounted) {
                            final count = provider.currentSeries.length;
                            final err = provider.seriesError;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err != null ? 'Error: $err' : 'Loaded $count series for ${cat.categoryName}'),
                                duration: const Duration(seconds: 3),
                                backgroundColor: err != null ? Colors.red : AppColors.bgCard,
                              ),
                            );
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Show results count when not loading
            if (!provider.isLoadingSeries && series.isNotEmpty && !_showFavorites)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  '${series.length} series',
                  style: const TextStyle(color: AppColors.whiteMuted, fontSize: 11),
                ),
              ),
            Expanded(
              child: provider.isLoadingSeries
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.red),
                          SizedBox(height: 12),
                          Text('Loading series...', style: TextStyle(color: AppColors.whiteMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : series.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_showFavorites ? Icons.bookmark_border : Icons.tv, size: 48, color: AppColors.whiteMuted),
                              const SizedBox(height: 8),
                              Text(
                                _showFavorites
                                    ? 'No series in your list yet\nLong press a series to add it'
                                    : provider.seriesError != null
                                        ? 'Error loading series\n${provider.seriesError}'
                                        : 'Tap a category to browse series',
                                style: TextStyle(color: AppColors.whiteMuted),
                                textAlign: TextAlign.center,
                              ),
                              if (provider.seriesError != null || (!provider.isLoadingSeries && !_showFavorites)) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final catId = _selectedCategoryId ?? (provider.seriesCategories.isNotEmpty ? provider.seriesCategories.first.categoryId : null);
                                    if (catId != null) {
                                      provider.loadSeries(catId);
                                    } else {
                                      // Force reload everything
                                      _loaded = false;
                                      _initSeries();
                                    }
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                                ),
                              ],
                              // Debug info
                              const SizedBox(height: 16),
                              Text(
                                'v3.8.2 | Cats: ${provider.seriesCategories.length} | Sel: ${_selectedCategoryId ?? "none"} | ProvSel: ${provider.selectedSeriesCategoryId ?? "none"}\n'
                                'Loading: ${provider.isLoadingSeries} | Data: ${provider.currentSeries.length} | Err: ${provider.seriesError ?? "none"}',
                                style: const TextStyle(color: AppColors.whiteMuted, fontSize: 9),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _getColumnCount(context),
                            childAspectRatio: 0.55,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: series.length,
                          itemBuilder: (context, index) {
                            final s = series[index];
                            return _SeriesCard(
                              series: s,
                              isFavorite: provider.isSeriesFavorite(s.seriesId),
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => SeriesDetailScreen(series: s),
                                ));
                              },
                              onLongPress: () {
                                provider.toggleSeriesFavorite(s.seriesId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.isSeriesFavorite(s.seriesId) ? 'Added to My List' : 'Removed from My List'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: AppColors.bgCard,
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 8;
    if (width > 900) return 6;
    if (width > 600) return 4;
    return 3;
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.red : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? AppColors.red : Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.whiteDim),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.whiteDim)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final SeriesItem series;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SeriesCard({required this.series, this.isFavorite = false, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.bgCard,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (series.cover != null && series.cover!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: series.cover!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.bgCard, child: const Center(child: Icon(Icons.tv, color: AppColors.whiteMuted))),
                          errorWidget: (_, __, ___) => Container(color: AppColors.bgCard, child: const Center(child: Icon(Icons.tv, color: AppColors.whiteMuted))),
                        ),
                      )
                    else
                      Container(color: AppColors.bgCard, child: const Center(child: Icon(Icons.tv, color: AppColors.whiteMuted, size: 32))),
                    if (isFavorite)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Icon(Icons.bookmark, color: AppColors.red, size: 18),
                      ),
                    if (series.ratingValue > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: AppColors.gold, size: 10),
                              const SizedBox(width: 2),
                              Text(series.ratingValue.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(series.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (series.genre != null)
              Text(series.genre!, style: const TextStyle(fontSize: 9, color: AppColors.whiteMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
