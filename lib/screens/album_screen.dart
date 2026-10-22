import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/audio_tile.dart';
import '../widgets/common.dart';
import '../widgets/media_thumb.dart';
import 'routes.dart';

enum _Filter { all, photos, videos, voice }

enum _Layout {
  grid('Grid', Icons.grid_view_rounded),
  days('By day', Icons.view_day_outlined),
  months('By month', Icons.calendar_view_month_rounded);

  const _Layout(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Every memory of the journal: photos, videos and voice notes, in a grid,
/// by day or by month, plus "On this day".
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  _Filter _filter = _Filter.all;
  _Layout _layout = _Layout.months;
  int _columns = 3;
  double _scaleStart = 1;

  void _setColumns(int n) {
    final next = n.clamp(2, 5);
    if (next == _columns) return;
    HapticFeedback.selectionClick();
    setState(() => _columns = next);
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalRepository>();
    final all = journal.visualMedia;
    final photos = all.where((m) => m.type == MediaType.image).toList();
    final videos = all.where((m) => m.type == MediaType.video).toList();
    final voice = [
      for (final e in journal.entries)
        ...journal
            .mediaFor(e.day)
            .reversed
            .where((m) => m.type == MediaType.audio),
    ];
    final items = switch (_filter) {
      _Filter.all => all,
      _Filter.photos => photos,
      _Filter.videos => videos,
      _Filter.voice => voice,
    };
    final onThisDay = _onThisDay(all);

    return GestureDetector(
      // Pinch the grid to change how many photos fit in a row.
      onScaleStart: (_) => _scaleStart = 1,
      onScaleUpdate: (d) {
        if (d.pointerCount < 2 || _filter == _Filter.voice) return;
        if (d.scale > _scaleStart * 1.25) {
          _scaleStart = d.scale;
          _setColumns(_columns - 1);
        } else if (d.scale < _scaleStart * 0.8) {
          _scaleStart = d.scale;
          _setColumns(_columns + 1);
        }
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 124,
            title: const Text('Album'),
            actions: [
              if (_filter != _Filter.voice)
                PopupMenuButton<Object>(
                  tooltip: 'View',
                  icon: Icon(_layout.icon),
                  onSelected: (v) {
                    if (v is _Layout) setState(() => _layout = v);
                    if (v is int) _setColumns(v);
                  },
                  itemBuilder: (_) => [
                    for (final l in _Layout.values)
                      CheckedPopupMenuItem(
                        value: l,
                        checked: l == _layout,
                        child: Text(l.label),
                      ),
                    if (_layout != _Layout.days) ...[
                      const PopupMenuDivider(),
                      for (final n in const [2, 3, 4, 5])
                        CheckedPopupMenuItem(
                          value: n,
                          checked: n == _columns,
                          child: Text('$n per row'),
                        ),
                    ],
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: PillTabs<_Filter>(
                values: _Filter.values,
                selected: _filter,
                onChanged: (f) => setState(() => _filter = f),
                labelOf: (f) => switch (f) {
                  _Filter.all => 'All',
                  _Filter.photos => 'Photos',
                  _Filter.videos => 'Videos',
                  _Filter.voice => 'Voice',
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                _summary(photos.length, videos.length, voice.length),
                style: context.text.bodySmall,
              ),
            ),
          ),
          if (onThisDay.isNotEmpty && _filter == _Filter.all)
            SliverToBoxAdapter(child: _OnThisDay(items: onThisDay)),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: EmptyState(
                  icon: switch (_filter) {
                    _Filter.voice => Icons.mic_none_rounded,
                    _Filter.videos => Icons.videocam_outlined,
                    _ => Icons.photo_library_outlined,
                  },
                  title: 'No memories yet',
                  message: _filter == _Filter.voice
                      ? 'Voice notes you record on your days will appear here.'
                      : 'Photos and videos you add to your days will appear here.',
                ),
              ),
            )
          else if (_filter == _Filter.voice)
            ..._voiceSlivers(context, items)
          else
            ...switch (_layout) {
              _Layout.grid => [_grid(items, items.length, (i) => i)],
              _Layout.months => _monthSlivers(context, items),
              _Layout.days => _daySlivers(context, journal, items),
            },
          const SliverToBoxAdapter(child: BottomSpace()),
        ],
      ),
    );
  }

  static String _summary(int photos, int videos, int voice) {
    String n(int count, String one, String many) =>
        '$count ${count == 1 ? one : many}';
    return [
      n(photos, 'photo', 'photos'),
      n(videos, 'video', 'videos'),
      n(voice, 'voice note', 'voice notes'),
    ].join(' · ');
  }

  /// Visual memories from this calendar day in earlier years, or else from
  /// this day of the month in earlier months.
  static List<MediaItem> _onThisDay(List<MediaItem> all) {
    final today = Dates.today();
    final sameDay = [
      for (final m in all)
        if (_isOnThisDay(Dates.parse(m.day), today, years: true)) m,
    ];
    if (sameDay.isNotEmpty) return sameDay;
    return [
      for (final m in all)
        if (_isOnThisDay(Dates.parse(m.day), today, years: false)) m,
    ];
  }

  static bool _isOnThisDay(DateTime d, DateTime today, {required bool years}) {
    if (!d.isBefore(today)) return false;
    return years
        ? d.month == today.month && d.day == today.day
        : d.day == today.day;
  }

  Widget _grid(List<MediaItem> items, int count, int Function(int) indexOf) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final index = indexOf(i);
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
            cacheWidth: _columns <= 2 ? 600 : 360,
            heroTag: 'album-${item.id}',
            showSyncBadge: true,
          ),
        );
      },
    );
  }

  List<Widget> _monthSlivers(BuildContext context, List<MediaItem> items) {
    // Group by month, remembering each item's index in [items] for the viewer.
    final groups = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      (groups[Dates.month(Dates.parse(items[i].day))] ??= []).add(i);
    }
    return [
      for (final MapEntry(key: month, value: indexes) in groups.entries) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: Text(month, style: context.text.titleMedium)),
                Text('${indexes.length}', style: context.text.bodySmall),
              ],
            ),
          ),
        ),
        _grid(items, indexes.length, (i) => indexes[i]),
      ],
    ];
  }

  List<Widget> _daySlivers(
    BuildContext context,
    JournalRepository journal,
    List<MediaItem> items,
  ) {
    final days = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      (days[items[i].day] ??= []).add(i);
    }
    final keys = days.keys.toList();
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.builder(
          itemCount: keys.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DayCard(
              entry: journal.entryFor(keys[i]),
              day: keys[i],
              items: items,
              indexes: days[keys[i]]!,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _voiceSlivers(BuildContext context, List<MediaItem> items) {
    final days = <String, List<MediaItem>>{};
    for (final m in items) {
      (days[m.day] ??= []).add(m);
    }
    return [
      for (final MapEntry(key: day, value: notes) in days.entries)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
            children: [
              SectionLabel(
                Dates.compact(Dates.parse(day)),
                trailing: TextButton(
                  onPressed: () => openDay(context, day),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 30)),
                  child: const Text('Open day'),
                ),
              ),
              for (final m in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AudioTile(key: ValueKey(m.id), item: m),
                ),
            ],
          ),
        ),
    ];
  }
}

/// A day's memories with its title and mood, as a small mosaic.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.entry,
    required this.day,
    required this.items,
    required this.indexes,
  });

  final JournalEntry? entry;
  final String day;
  final List<MediaItem> items;
  final List<int> indexes;

  @override
  Widget build(BuildContext context) {
    final date = Dates.parse(day);
    final shown = indexes.take(4).toList();
    final extra = indexes.length - shown.length;
    Widget tile(int k, {double radius = 12}) {
      final index = shown[k];
      final item = items[index];
      return GestureDetector(
        onTap: () => openMediaViewer(
          context,
          items: items,
          initialIndex: index,
          heroPrefix: 'album-day',
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumb(
              item: item,
              radius: radius,
              cacheWidth: 600,
              heroTag: 'album-day-${item.id}',
            ),
            if (k == shown.length - 1 && extra > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Text(
                      '+$extra',
                      style: context.text.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final mosaic = switch (shown.length) {
      1 => AspectRatio(aspectRatio: 16 / 10, child: tile(0)),
      2 => AspectRatio(
        aspectRatio: 2,
        child: Row(
          children: [
            Expanded(child: tile(0)),
            const SizedBox(width: 4),
            Expanded(child: tile(1)),
          ],
        ),
      ),
      3 => AspectRatio(
        aspectRatio: 16 / 10,
        child: Row(
          children: [
            Expanded(flex: 2, child: tile(0)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(1)),
                  const SizedBox(height: 4),
                  Expanded(child: tile(2)),
                ],
              ),
            ),
          ],
        ),
      ),
      _ => AspectRatio(
        aspectRatio: 1.25,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(0)),
                  const SizedBox(width: 4),
                  Expanded(child: tile(1)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: tile(2)),
                  const SizedBox(width: 4),
                  Expanded(child: tile(3)),
                ],
              ),
            ),
          ],
        ),
      ),
    };

    return SurfaceCard(
      onTap: () => openDay(context, day),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              children: [
                Text('${date.day}', style: context.text.headlineSmall),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.title.trim().isNotEmpty == true
                            ? entry!.title.trim()
                            : Dates.weekday(date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      Text(
                        '${Dates.month(date)} · ${indexes.length} ${indexes.length == 1 ? 'memory' : 'memories'}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (entry?.mood != null)
                  Text(
                    entry!.mood!.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
              ],
            ),
          ),
          mosaic,
        ],
      ),
    );
  }
}

/// Memories from this day in the past, as a horizontal strip.
class _OnThisDay extends StatelessWidget {
  const _OnThisDay({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = Dates.today();
    String ago(String day) {
      final d = Dates.parse(day);
      final years = today.year - d.year;
      if (d.month == today.month && years > 0) {
        return years == 1 ? '1 year ago' : '$years years ago';
      }
      final months = (today.year - d.year) * 12 + today.month - d.month;
      return months == 1 ? '1 month ago' : '$months months ago';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Text('On this day', style: context.text.titleSmall),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final m = items[i];
                return GestureDetector(
                  onTap: () => openMediaViewer(
                    context,
                    items: items,
                    initialIndex: i,
                    heroPrefix: 'otd',
                  ),
                  child: SizedBox(
                    width: 128,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaThumb(item: m, radius: 18, heroTag: 'otd-${m.id}'),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ago(m.day),
                              style: AppTheme.font(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
