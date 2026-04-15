import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/xtream_data.dart';
import '../../providers/app_provider.dart';

class MovieDetailSheet extends StatelessWidget {
  final VodStream movie;
  final VoidCallback onPlay;

  const MovieDetailSheet({super.key, required this.movie, required this.onPlay});

  static void show(BuildContext context, VodStream movie, VoidCallback onPlay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovieDetailSheet(movie: movie, onPlay: onPlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.whiteMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      if (movie.streamIcon != null && movie.streamIcon!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: movie.streamIcon!,
                            width: 110,
                            height: 160,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(width: 110, height: 160, color: AppColors.bgCard, child: const Icon(Icons.movie, color: AppColors.whiteMuted)),
                          ),
                        )
                      else
                        Container(width: 110, height: 160, decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.movie, color: AppColors.whiteMuted, size: 40)),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18), maxLines: 3),
                            const SizedBox(height: 8),
                            // Meta row
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (movie.ratingValue > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: AppColors.gold, size: 16),
                                      const SizedBox(width: 4),
                                      Text(movie.ratingValue.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                                    ],
                                  ),
                                if (movie.containerExtension != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
                                    child: Text(movie.containerExtension!.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Play button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onPlay();
                                },
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('Play Now'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // My List button
                            Consumer<AppProvider>(
                              builder: (context, provider, _) {
                                final isFav = provider.isMovieFavorite(movie.streamId);
                                return SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => provider.toggleMovieFavorite(movie.streamId),
                                    icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                    label: Text(isFav ? 'In My List' : 'Add to My List'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isFav ? AppColors.red : AppColors.whiteDim,
                                      side: BorderSide(color: isFav ? AppColors.red : Colors.white24),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
