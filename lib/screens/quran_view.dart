import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quran_repository.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'quran_reader_screen.dart';

/// Quran home: continue reading, bookmarks and the list of surahs.
class QuranView extends StatefulWidget {
  const QuranView({super.key});

  @override
  State<QuranView> createState() => _QuranViewState();
}

class _QuranViewState extends State<QuranView> {
  String _query = '';

  List<Surah> get _surahs {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return Surah.all;
    String simple(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[\s\-'ʿʾ]"), '');
    final sq = simple(q);
    return [
      for (final s in Surah.all)
        if ('${s.number}' == q ||
            simple(s.name).contains(sq) ||
            s.meaning.toLowerCase().contains(q) ||
            s.arabic.contains(q))
          s,
    ];
  }

  Future<void> _download() async {
    final repo = context.read<QuranRepository>();
    final messenger = ScaffoldMessenger.of(context);
    if (repo.isDownloading) {
      repo.cancelDownload();
      return;
    }
    final ok = await repo.downloadAll();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'The whole Quran is saved on this phone.'
                : 'Download stopped. Check your connection and try again.',
          ),
        ),
      );
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<QuranRepository>(),
        child: const _BookmarksSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<QuranRepository>();
    final last = repo.lastRead;
    final surahs = _surahs;
    final available = repo.availableCount;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.list(
        children: [
          _ContinueCard(last: last),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showBookmarks,
                  icon: const Icon(Icons.bookmark_outline_rounded, size: 20),
                  label: Text('Bookmarks · ${repo.bookmarks.length}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      available >= Surah.all.length && !repo.isDownloading
                      ? null
                      : _download,
                  icon: repo.isDownloading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          available >= Surah.all.length
                              ? Icons.offline_pin_rounded
                              : Icons.download_rounded,
                          size: 20,
                        ),
                  label: Text(
                    repo.isDownloading
                        ? '${repo.downloadDone}/114 · Stop'
                        : available >= Surah.all.length
                        ? 'Offline'
                        : 'Save offline',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              hintText: 'Search a surah: name or number',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (surahs.isEmpty)
            const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No surah found',
              message: 'Try a name like "Yasin" or a number from 1 to 114.',
            )
          else
            GroupCard(
              children: [
                for (final s in surahs)
                  _SurahTile(
                    surah: s,
                    saved: repo.isAvailable(s.number),
                    reading: last?.$1 == s.number,
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'Text: Tanzil (Uthmani) via alquran.cloud. '
            'Translation: ${repo.translation.author}.',
            style: context.text.bodySmall?.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.last});

  final (int, int)? last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final surah = Surah.byNumber(last?.$1 ?? 1);
    final ayah = last?.$2 ?? 1;
    return SurfaceCard(
      color: c.primary,
      onTap: () => openSurah(context, surah.number, ayah: ayah),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: c.onPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      last == null ? 'Start reading' : 'Continue reading',
                      style: context.text.labelMedium?.copyWith(
                        color: c.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  surah.name,
                  style: context.text.headlineSmall?.copyWith(
                    color: c.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ayah $ayah of ${surah.ayahs}',
                  style: context.text.bodyMedium?.copyWith(
                    color: c.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Text(
            surah.arabic,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(fontSize: 30, color: c.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.saved,
    required this.reading,
  });

  final Surah surah;
  final bool saved;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = surah;
    return ListTile(
      onTap: () => openSurah(context, s.number),
      leading: SurahNumber(s.number, highlight: reading),
      title: Text(s.name),
      subtitle: Text(
        '${s.meaning} · ${s.ayahs} ayahs',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saved)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.offline_pin_rounded,
                size: 16,
                color: c.muted.withValues(alpha: 0.6),
              ),
            ),
          Text(
            s.arabic,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(fontSize: 20, color: c.ink),
          ),
        ],
      ),
    );
  }
}

/// The surah number in a rotated rounded square.
class SurahNumber extends StatelessWidget {
  const SurahNumber(this.number, {super.key, this.highlight = false});

  final int number;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox.square(
      dimension: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: highlight ? c.primary : c.primarySoft,
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          Text(
            '$number',
            style: context.text.labelSmall?.copyWith(
              color: highlight ? c.onPrimary : c.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarksSheet extends StatelessWidget {
  const _BookmarksSheet();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepository>();
    final marks = repo.bookmarks;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [Text('Bookmarks', style: context.text.titleLarge)],
            ),
          ),
          Expanded(
            child: marks.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'No bookmarks yet',
                      message:
                          'Tap the bookmark icon on an ayah to keep it here.',
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: marks.length,
                    itemBuilder: (context, i) {
                      final b = marks[i];
                      final s = Surah.byNumber(b.surah);
                      return ListTile(
                        leading: SurahNumber(s.number),
                        title: Text('${s.name} · ${b.ayah}'),
                        subtitle: Text(s.meaning),
                        trailing: IconButton(
                          tooltip: 'Remove bookmark',
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          onPressed: () => repo.toggleBookmark(b.surah, b.ayah),
                        ),
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(surahRoute(b.surah, ayah: b.ayah));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
