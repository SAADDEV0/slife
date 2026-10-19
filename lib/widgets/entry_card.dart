import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';
import 'media_thumb.dart';

/// One day in a list: date, title, snippet, attachment counts and a cover
/// thumbnail.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = context.read<JournalRepository>().mediaFor(entry.day);
    final visual = media.where((m) => m.isVisual).toList();
    final synced = !entry.dirty && media.every((m) => m.isSynced);
    final snippet = entry.snippet;
    final date = entry.date;

    return Semantics(
      button: true,
      label:
          '${Dates.weekday(date)} ${Dates.long(date)}, ${entry.displayTitle}',
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: AppTheme.font(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    Dates.shortWeekday(date),
                    style: context.text.labelMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium?.copyWith(
                            color: entry.title.trim().isEmpty ? c.muted : c.ink,
                          ),
                        ),
                      ),
                      if (entry.mood != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          entry.mood!.emoji,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ],
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _MetaRow(entry: entry, media: media, synced: synced),
                ],
              ),
            ),
            if (visual.isNotEmpty) ...[
              const SizedBox(width: 12),
              _Cover(item: visual.first, count: visual.length),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.entry,
    required this.media,
    required this.synced,
  });

  final JournalEntry entry;
  final List<MediaItem> media;
  final bool synced;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    int count(MediaType t) => media.where((m) => m.type == t).length;
    final style = context.text.labelMedium?.copyWith(fontSize: 12);
    final items = <Widget>[];
    void add(IconData icon, String text) {
      if (items.isNotEmpty) items.add(const SizedBox(width: 12));
      items
        ..add(Icon(icon, size: 14, color: c.muted))
        ..add(const SizedBox(width: 4))
        ..add(Text(text, style: style));
    }

    final photos = count(MediaType.image);
    final videos = count(MediaType.video);
    final voices = count(MediaType.audio);
    if (photos > 0) add(Icons.image_outlined, '$photos');
    if (videos > 0) add(Icons.videocam_outlined, '$videos');
    if (voices > 0) add(Icons.mic_none_rounded, '$voices');
    if (items.isEmpty) {
      final words = entry.wordCount;
      add(Icons.notes_rounded, '$words ${words == 1 ? 'word' : 'words'}');
    }

    return Row(
      children: [
        ...items,
        const Spacer(),
        Tooltip(
          message: synced ? 'Backed up' : 'Waiting to back up',
          child: Icon(
            synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            size: 15,
            color: synced ? c.muted : c.primary,
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item, required this.count});

  final MediaItem item;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 68,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumb(item: item, radius: 12, cacheWidth: 200),
          if (count > 1)
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${count - 1}',
                  style: context.text.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
