import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/media_thumb.dart';
import 'routes.dart';

enum _Filter { all, photos, videos }

/// Every photo and video of the journal, grouped by month.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<JournalRepository>().visualMedia;
    final photos = all.where((m) => m.type == MediaType.image).length;
    final videos = all.length - photos;
    final items = switch (_filter) {
      _Filter.all => all,
      _Filter.photos => all.where((m) => m.type == MediaType.image).toList(),
      _Filter.videos => all.where((m) => m.type == MediaType.video).toList(),
    };

    // Group by month, remembering each item's index in [items] for the viewer.
    final groups = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      (groups[Dates.month(Dates.parse(items[i].day))] ??= []).add(i);
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(expandedHeight: 124, title: const Text('Album')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Filter>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Filter.all,
                    label: Text('All · ${all.length}'),
                  ),
                  ButtonSegment(
                    value: _Filter.photos,
                    label: Text('Photos · $photos'),
                  ),
                  ButtonSegment(
                    value: _Filter.videos,
                    label: Text('Videos · $videos'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: EmptyState(
                icon: _filter == _Filter.videos
                    ? Icons.videocam_outlined
                    : Icons.photo_library_outlined,
                title: 'No memories yet',
                message:
                    'Photos and videos you add to your days will appear here.',
              ),
            ),
          )
        else
          for (final MapEntry(key: month, value: indexes)
              in groups.entries) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(month, style: context.text.titleMedium),
                    ),
                    Text('${indexes.length}', style: context.text.bodySmall),
                  ],
                ),
              ),
            ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: indexes.length,
              itemBuilder: (context, i) {
                final index = indexes[i];
                final item = items[index];
                return GestureDetector(
                  onTap: () => openMediaViewer(
                    context,
                    items: items,
                    initialIndex: index,
                    heroPrefix: 'album',
                  ),
                  child: MediaThumb(
                    item: item,
                    radius: 0,
                    heroTag: 'album-${item.id}',
                    showSyncBadge: true,
                  ),
                );
              },
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
