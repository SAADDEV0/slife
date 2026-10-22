import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quran_repository.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'quran_reader_screen.dart';

enum _Tab { surahs, juz, saved }

/// Quran home: continue reading, search, surahs, juz and bookmarks.
/// Every list is built lazily so the tab opens instantly.
class QuranView extends StatefulWidget {
  const QuranView({super.key});

  @override
  State<QuranView> createState() => _QuranViewState();
}

class _QuranViewState extends State<QuranView> {
  _Tab _tab = _Tab.surahs;
  String _query = '';
  Timer? _debounce;
  Future<List<AyahHit>>? _hits;

  @override
  void initState() {
    super.initState();
    final repo = context.read<QuranRepository>();
    // Warm up in the background: the text, and a saved translation if any.
    repo.ensureText();
    repo.ensureTranslation(download: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _hits = value.trim().length >= 3
            ? context.read<QuranRepository>().search(value)
            : null;
      });
    });
  }

  List<Surah> get _surahs {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return Surah.all;
    String simple(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[\s\-'ʿʾ]"), '');
    final sq = simple(q);
    final aq = QuranRepository.normalizeArabic(q);
    return [
      for (final s in Surah.all)
        if ('${s.number}' == q ||
            simple(s.name).contains(sq) ||
            s.meaning.toLowerCase().contains(q) ||
            QuranRepository.normalizeArabic(s.arabic).contains(aq))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<QuranRepository>();
    final searching = _query.trim().isNotEmpty;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              _ContinueCard(last: repo.lastRead),
              const SizedBox(height: 12),
              const _TranslationBanner(),
              TextField(
                onChanged: _onQuery,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search surahs or words in the Quran',
                  prefixIcon: const Icon(Icons.search_rounded),
                  fillColor: context.colors.card,
                ),
              ),
              const SizedBox(height: 14),
              if (!searching) ...[
                PillTabs<_Tab>(
                  values: _Tab.values,
                  selected: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                  labelOf: (t) => switch (t) {
                    _Tab.surahs => 'Surahs',
                    _Tab.juz => 'Juz',
                    _Tab.saved => 'Saved · ${repo.bookmarks.length}',
                  },
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        if (searching)
          ..._searchSlivers(context)
        else
          switch (_tab) {
            _Tab.surahs => _CardList(
              count: Surah.all.length,
              builder: (context, i) => _SurahTile(
                surah: Surah.all[i],
                reading: repo.lastRead?.$1 == i + 1,
              ),
            ),
            _Tab.juz => _JuzList(starts: repo.juzStarts),
            _Tab.saved => _SavedList(marks: repo.bookmarks),
          },
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Arabic text: Tanzil Quran Text (Uthmani), tanzil.net.'
              '${repo.translation == QuranTranslation.none ? '' : ' Translation: ${repo.translation.author}.'}',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _searchSlivers(BuildContext context) {
    final surahs = _surahs;
    return [
      if (surahs.isNotEmpty) ...[
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(child: SectionLabel('Surahs')),
        ),
        _CardList(
          count: surahs.length,
          builder: (context, i) => _SurahTile(surah: surahs[i]),
        ),
      ],
      SliverToBoxAdapter(
        child: FutureBuilder<List<AyahHit>>(
          future: _hits,
          builder: (context, snap) {
            final repo = context.read<QuranRepository>();
            if (_query.trim().length < 3) return const SizedBox.shrink();
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final hits = snap.data ?? const [];
            final needsTr =
                hits.isEmpty &&
                !QuranRepository.normalizeArabic(_query)
                    .contains(RegExp('[؀-ۿ]')) &&
                !repo.hasTranslation;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionLabel(
                    hits.length >= 60
                        ? 'Ayahs · first 60'
                        : 'Ayahs · ${hits.length}',
                  ),
                  if (hits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        needsTr
                            ? 'Download a translation to search by meaning, or type in Arabic.'
                            : 'No ayah contains “${_query.trim()}”.',
                        style: context.text.bodySmall,
                      ),
                    )
                  else
                    for (final h in hits.take(60))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SurfaceCard(
                          onTap: () =>
                              openSurah(context, h.surah, ayah: h.ayah),
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${Surah.byNumber(h.surah).name} ${h.surah}:${h.ayah}',
                                style: context.text.labelSmall?.copyWith(
                                  color: context.colors.emerald,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                h.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textDirection: RegExp('[؀-ۿ]').hasMatch(h.text)
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: RegExp('[؀-ۿ]').hasMatch(h.text)
                                    ? AppTheme.arabic(
                                        fontSize: 20,
                                        color: context.colors.ink,
                                        height: 1.8,
                                      )
                                    : context.text.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// A lazily built list drawn as one rounded card.
class _CardList extends StatelessWidget {
  const _CardList({required this.count, required this.builder});

  final int count;
  final IndexedWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.line.withValues(alpha: 0.7)),
          boxShadow: c.cardShadow,
        ),
        sliver: SliverList.separated(
          itemCount: count,
          itemBuilder: builder,
          separatorBuilder: (_, _) =>
              Divider(indent: 68, endIndent: 16, color: c.line),
        ),
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
    final progress = surah.ayahs == 0 ? 0.0 : ayah / surah.ayahs;
    return SurfaceCard(
      onTap: () => openSurah(context, surah.number, ayah: ayah),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.menu_book_rounded, color: c.emerald),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      last == null ? 'Start reading' : 'Continue reading',
                      style: context.text.labelMedium,
                    ),
                    Text(surah.name, style: context.text.titleLarge),
                  ],
                ),
              ),
              Text(
                surah.arabic,
                textDirection: TextDirection.rtl,
                style: AppTheme.arabic(
                  fontSize: 28,
                  color: c.emerald,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              color: c.emerald,
              backgroundColor: c.emeraldSoft,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Ayah $ayah of ${surah.ayahs}',
                style: context.text.bodySmall,
              ),
              const Spacer(),
              Text(
                last == null ? 'Open' : 'Resume',
                style: context.text.labelLarge?.copyWith(color: c.emerald),
              ),
              Icon(Icons.arrow_forward_rounded, size: 18, color: c.emerald),
            ],
          ),
        ],
      ),
    );
  }
}

/// Offers to download the chosen translation, or shows its progress.
class _TranslationBanner extends StatelessWidget {
  const _TranslationBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<QuranRepository>();
    final state = repo.translationState;
    if (state == TranslationState.none || state == TranslationState.ready) {
      return const SizedBox.shrink();
    }
    final downloading = state == TranslationState.downloading;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        color: c.emeraldSoft,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(
              state == TranslationState.failed
                  ? Icons.wifi_off_rounded
                  : Icons.translate_rounded,
              color: c.emerald,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(switch (state) {
                TranslationState.downloading =>
                  'Downloading the ${repo.translation.label} translation…',
                TranslationState.failed =>
                  'Could not download the translation. Check your connection.',
                _ =>
                  'Get the ${repo.translation.label} translation (about 1 MB, once).',
              }, style: context.text.bodyMedium),
            ),
            if (downloading)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              TextButton(
                onPressed: repo.ensureTranslation,
                style: TextButton.styleFrom(foregroundColor: c.emerald),
                child: Text(
                  state == TranslationState.failed ? 'Retry' : 'Download',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, this.reading = false});

  final Surah surah;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = surah;
    return InkWell(
      onTap: () => openSurah(context, s.number),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Row(
          children: [
            SurahNumber(s.number, highlight: reading),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${s.meaning} · ${s.ayahs} ayahs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              s.arabic,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(fontSize: 21, color: c.ink, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzList extends StatelessWidget {
  const _JuzList({required this.starts});

  final List<(int, int)> starts;

  @override
  Widget build(BuildContext context) {
    if (starts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _CardList(
      count: starts.length,
      builder: (context, i) {
        final (s, a) = starts[i];
        final surah = Surah.byNumber(s);
        return InkWell(
          onTap: () => openSurah(context, s, ayah: a),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            child: Row(
              children: [
                SurahNumber(i + 1),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Juz ${i + 1}', style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Starts at ${surah.name} $s:$a',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colors.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedList extends StatelessWidget {
  const _SavedList({required this.marks});

  final List<QuranBookmark> marks;

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) {
      return const SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.bookmark_outline_rounded,
          title: 'No saved ayahs',
          message: 'Tap the bookmark on any ayah to keep it here.',
        ),
      );
    }
    final repo = context.read<QuranRepository>();
    return _CardList(
      count: marks.length,
      builder: (context, i) {
        final b = marks[i];
        final s = Surah.byNumber(b.surah);
        return InkWell(
          onTap: () => openSurah(context, b.surah, ayah: b.ayah),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                SurahNumber(s.number),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.name} · Ayah ${b.ayah}',
                        style: context.text.titleSmall,
                      ),
                      Text(s.meaning, style: context.text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove bookmark',
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  onPressed: () => repo.toggleBookmark(b.surah, b.ayah),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The surah number in an eight-pointed star.
class SurahNumber extends StatelessWidget {
  const SurahNumber(this.number, {super.key, this.highlight = false});

  final int number;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = highlight ? c.emerald : c.emeraldSoft;
    return SizedBox.square(
      dimension: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final angle in const [0.0, 0.785398])
            Transform.rotate(
              angle: angle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          Text(
            '$number',
            style: context.text.labelSmall?.copyWith(
              color: highlight ? Colors.white : c.emerald,
              fontWeight: FontWeight.w800,
              fontSize: number > 99 ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
