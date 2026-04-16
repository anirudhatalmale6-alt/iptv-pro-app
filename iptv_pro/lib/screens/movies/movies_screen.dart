import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';
import '../player/player_screen.dart';
import 'movie_detail_sheet.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  bool _loaded = false;
  String? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showFavorites = false;
  List<VodStream> _searchResults = [];
  bool _isSearching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _initMovies();
    }
  }

  Future<void> _initMovies() async {
    final provider = context.read<AppProvider>();
    if (provider.vodCategories.isEmpty) {
      await provider.loadVodCategories();
    }
    if (!mounted) return;
    if (provider.vodCategories.isNotEmpty && provider.currentVodStreams.isEmpty && !provider.isLoadingVod) {
      final firstCat = provider.vodCategories.first.categoryId;
      setState(() => _selectedCategoryId = firstCat);
      provider.loadVodStreams(firstCat);
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
    final results = await provider.searchVodStreams(query);
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
        if (_searchQuery.length >= 2 && _searchResults.isEmpty && provider.allVodStreams.isNotEmpty) {
          _performSearch(_searchQuery);
        }

        List<VodStream> movies;
        if (_searchQuery.length >= 2) {
          movies = _searchResults;
        } else if (_showFavorites) {
          movies = provider.currentVodStreams.where((m) => provider.isMovieFavorite(m.streamId)).toList();
        } else {
          movies = provider.currentVodStreams;
        }

        return Column(
          children: [
            // Header with search and category filter
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              color: AppColors.bgSurface,
              child: Column(
                children: [
                  // Search bar
                  SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search movies...',
                        hintStyle: TextStyle(color: AppColors.whiteMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.whiteMuted, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.whiteMuted, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.bgCard,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Category chips with My List
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.vodCategories.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildCategoryChip(
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
                          return _buildCategoryChip('All', !_showFavorites && _selectedCategoryId == null, () {
                            setState(() {
                              _selectedCategoryId = null;
                              _showFavorites = false;
                            });
                            provider.loadVodStreams(null);
                          });
                        }
                        final cat = provider.vodCategories[index - 2];
                        return _buildCategoryChip(
                          cat.categoryName,
                          !_showFavorites && _selectedCategoryId == cat.categoryId,
                          () {
                            setState(() {
                              _selectedCategoryId = cat.categoryId;
                              _showFavorites = false;
                            });
                            provider.loadVodStreams(cat.categoryId);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Movie grid
            Expanded(
              child: provider.isLoadingVod && movies.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                  : movies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_showFavorites ? Icons.bookmark_border : Icons.movie_outlined, size: 48, color: AppColors.whiteMuted),
                              const SizedBox(height: 8),
                              Text(
                                _showFavorites
                                    ? 'No movies in your list yet\nLong press a movie to add it'
                                    : provider.vodError != null
                                        ? 'Error loading movies\n${provider.vodError}'
                                        : 'Tap a category to browse movies',
                                style: TextStyle(color: AppColors.whiteMuted),
                                textAlign: TextAlign.center,
                              ),
                              if (!_showFavorites && (provider.vodError != null || !provider.isLoadingVod)) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final catId = _selectedCategoryId ?? (provider.vodCategories.isNotEmpty ? provider.vodCategories.first.categoryId : null);
                                    if (catId != null) provider.loadVodStreams(catId);
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                                ),
                              ],
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
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return _MovieCard(
                              movie: movie,
                              isFavorite: provider.isMovieFavorite(movie.streamId),
                              onTap: () => MovieDetailSheet.show(context, movie, () => _playMovie(movie)),
                              onLongPress: () {
                                provider.toggleMovieFavorite(movie.streamId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.isMovieFavorite(movie.streamId) ? 'Added to My List' : 'Removed from My List'),
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

  Widget _buildCategoryChip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.whiteDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playMovie(VodStream movie) {
    final provider = context.read<AppProvider>();
    final ext = movie.containerExtension ?? 'mp4';
    final url = provider.buildVodUrl(movie.streamId, ext);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(url: url, title: movie.name),
    ));
  }
}

class _MovieCard extends StatelessWidget {
  final VodStream movie;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MovieCard({required this.movie, this.isFavorite = false, required this.onTap, this.onLongPress});

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
            // Poster
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.bgCard,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (movie.streamIcon != null && movie.streamIcon!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: movie.streamIcon!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.bgCard,
                            child: const Center(child: Icon(Icons.movie, color: AppColors.whiteMuted)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.bgCard,
                            child: const Center(child: Icon(Icons.movie, color: AppColors.whiteMuted)),
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: AppColors.bgCard,
                          child: const Center(child: Icon(Icons.movie, color: AppColors.whiteMuted, size: 32)),
                        ),
                      ),
                    // Gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          ),
                        ),
                      ),
                    ),
                    // Favorite badge
                    if (isFavorite)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Icon(Icons.bookmark, color: AppColors.red, size: 18),
                      ),
                    // Rating badge
                    if (movie.ratingValue > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: AppColors.gold, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                movie.ratingValue.toStringAsFixed(1),
                                style: const TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Quality badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              movie.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
