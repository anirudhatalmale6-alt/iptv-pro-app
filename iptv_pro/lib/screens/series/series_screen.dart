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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<AppProvider>().loadSeriesCategories();
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
                          return _buildChip('All', !_showFavorites && _selectedCategoryId == null, () {
                            setState(() {
                              _selectedCategoryId = null;
                              _showFavorites = false;
                            });
                            provider.loadSeries(null);
                          });
                        }
                        final cat = provider.seriesCategories[index - 2];
                        return _buildChip(cat.categoryName, !_showFavorites && _selectedCategoryId == cat.categoryId, () {
                          setState(() {
                            _selectedCategoryId = cat.categoryId;
                            _showFavorites = false;
                          });
                          provider.loadSeries(cat.categoryId);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: provider.isLoading && series.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                  : series.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_showFavorites ? Icons.bookmark_border : Icons.tv, size: 48, color: AppColors.whiteMuted),
                              const SizedBox(height: 8),
                              Text(
                                _showFavorites ? 'No series in your list yet\nLong press a series to add it' : 'Select a category to browse series',
                                style: TextStyle(color: AppColors.whiteMuted),
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
