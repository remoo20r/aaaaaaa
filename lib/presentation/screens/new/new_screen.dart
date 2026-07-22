import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/series_item.dart';
import '../../../data/models/vod_item.dart';
import '../../../state/series_providers.dart'
    show allSeriesProvider, adultSeriesIdsProvider, adultSeriesCategoryIdsProvider;
import '../../../state/vod_providers.dart'
    show allVodProvider, adultVodIdsProvider, adultVodCategoryIdsProvider;
import '../../common/grid_metrics.dart';
import '../../common/tv_focusable.dart';

/// One entry in the "NEW" grid — either a movie or a series, tagged so a tap
/// routes to the right detail screen.
class _NewEntry {
  _NewEntry({
    required this.id,
    required this.name,
    required this.image,
    required this.added,
    required this.isSeries,
  });

  final String id;
  final String name;
  final String? image;
  final int added;
  final bool isSeries;
}

/// Combined "recently added" screen: the newest movies AND series across the
/// whole playlist, sorted newest-first. Fed from the same data the server marks
/// as recently added; here we simply merge and re-sort by the added timestamp.
class NewScreen extends ConsumerWidget {
  const NewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vodAsync = ref.watch(allVodProvider);
    final seriesAsync = ref.watch(allSeriesProvider);
    final adultVod = ref.watch(adultVodIdsProvider).value ?? const <String>{};
    final adultVodCats = ref.watch(adultVodCategoryIdsProvider).value ?? const <String>{};
    final adultSeries = ref.watch(adultSeriesIdsProvider).value ?? const <String>{};
    final adultSeriesCats = ref.watch(adultSeriesCategoryIdsProvider).value ?? const <String>{};

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('New'),
      ),
        body: (vodAsync.isLoading || seriesAsync.isLoading)
            ? const Center(child: CircularProgressIndicator())
            : Builder(builder: (context) {
                final entries = <_NewEntry>[];
                for (final VodItem v in vodAsync.value ?? const []) {
                  if (adultVod.contains(v.streamId) || adultVodCats.contains(v.categoryId)) {
                    continue;
                  }
                  entries.add(_NewEntry(
                    id: v.streamId,
                    name: v.name,
                    image: v.posterUrl,
                    added: v.added,
                    isSeries: false,
                  ));
                }
                for (final SeriesItem s in seriesAsync.value ?? const []) {
                  if (adultSeries.contains(s.seriesId) || adultSeriesCats.contains(s.categoryId)) {
                    continue;
                  }
                  entries.add(_NewEntry(
                    id: s.seriesId,
                    name: s.name,
                    image: s.coverUrl,
                    added: s.added,
                    isSeries: true,
                  ));
                }
                // Newest first, capped so the grid stays snappy on TV boxes.
                entries.sort((a, b) => b.added.compareTo(a.added));
                final top = entries.take(120).toList();

                if (top.isEmpty) {
                  return const Center(child: Text('Nothing new yet.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: GridMetrics.posterExtent,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: top.length,
                  itemBuilder: (context, i) => _NewPoster(entry: top[i]),
                );
              }),
    );
  }
}

class _NewPoster extends StatelessWidget {
  const _NewPoster({required this.entry});

  final _NewEntry entry;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: () => context.push(
        entry.isSeries ? '/series/${entry.id}' : '/vod/${entry.id}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: entry.image != null
                        ? CachedNetworkImage(
                            imageUrl: entry.image!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        : Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.movie_outlined),
                          ),
                  ),
                ),
                // Tag whether it's a movie or a series.
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (entry.isSeries ? AppColors.gold : AppColors.red)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.isSeries ? 'SERIES' : 'MOVIE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
