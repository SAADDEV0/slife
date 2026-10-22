import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/quran_repository.dart';
import '../models/surah.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

Route<void> surahRoute(int surah, {int? ayah}) => MaterialPageRoute<void>(
  builder: (_) => QuranReaderScreen(surah: surah, initialAyah: ayah),
);

/// Opens [surah], scrolled to [ayah] when given.
Future<void> openSurah(BuildContext context, int surah, {int? ayah}) =>
    Navigator.of(context).push(surahRoute(surah, ayah: ayah));

/// Ayahs per paragraph in the mushaf layout.
const _chunk = 8;

/// Reads one surah. Only the ayahs on screen are built, so even Al-Baqarah
/// opens instantly and can jump straight to any ayah.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, this.initialAyah});

  final int surah;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late final QuranRepository _repo = context.read<QuranRepository>();
  final _scroll = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  late final ValueNotifier<int> _current = ValueNotifier(
    widget.initialAyah ?? 1,
  );
  Timer? _saveTimer;
  QuranLayout? _layoutShown;

  Surah get _surah => Surah.byNumber(widget.surah);

  @override
  void initState() {
    super.initState();
    _repo.ensureText();
    _repo.ensureTranslation(download: false);
    _positions.itemPositions.addListener(_onPositions);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onPositions);
    _saveTimer?.cancel();
    // Not while the tree is locked: listeners rebuild.
    final surah = widget.surah, ayah = _current.value, repo = _repo;
    scheduleMicrotask(() => repo.setLastRead(surah, ayah));
    _current.dispose();
    super.dispose();
  }

  int _indexOfAyah(int ayah, QuranLayout layout) {
    if (ayah <= 1) return 0;
    return layout == QuranLayout.verses ? ayah : (ayah - 1) ~/ _chunk + 1;
  }

  void _onPositions() {
    final layout = _layoutShown;
    if (layout == null) return;
    final visible = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0.12)
        .toList();
    if (visible.isEmpty) return;
    var index = visible.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final total = _surah.ayahs;
    final last = visible.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final lastIndex = layout == QuranLayout.verses
        ? total + 1
        : (total - 1) ~/ _chunk + 2;
    var ayah = switch (layout) {
      QuranLayout.verses => index.clamp(1, total),
      QuranLayout.mushaf => ((index - 1) * _chunk + 1).clamp(1, total),
    };
    if (last >= lastIndex) ayah = total; // reached the end
    if (index == 0) ayah = 1;
    if (ayah == _current.value) return;
    _current.value = ayah;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 700),
      () => _repo.setLastRead(widget.surah, ayah),
    );
  }

  void _jumpTo(int ayah) {
    final layout = _layoutShown;
    if (layout == null || !_scroll.isAttached) return;
    _scroll.scrollTo(
      index: _indexOfAyah(ayah, layout),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToAyah() async {
    final ayah = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AyahPicker(count: _surah.ayahs, current: _current.value),
    );
    if (ayah != null) _jumpTo(ayah);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: _repo,
        child: const _ReaderSettings(),
      ),
    );
  }

  void _ayahActions(Ayah a) {
    final s = _surah;
    final marked = _repo.isBookmarked(s.number, a.number);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '${s.name} · ${a.number}',
                style: ctx.text.titleMedium,
              ),
            ),
            ListTile(
              leading: Icon(
                marked
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
              ),
              title: Text(marked ? 'Remove bookmark' : 'Bookmark'),
              onTap: () {
                _repo.toggleBookmark(s.number, a.number);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy ayah'),
              onTap: () {
                Clipboard.setData(
                  ClipboardData(
                    text: [
                      a.arabic,
                      if (a.translation.isNotEmpty) a.translation,
                      '(${s.name} ${s.number}:${a.number})',
                    ].join('\n\n'),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Mark as last read'),
              onTap: () {
                _current.value = a.number;
                _repo.setLastRead(s.number, a.number);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _surah;
    final repo = context.watch<QuranRepository>();
    final layout = repo.layout;
    final ready = repo.isTextReady;
    final ayahs = ready ? repo.ayahs(s.number) : const <Ayah>[];

    // Keep the reading spot when switching layout.
    if (ready && _layoutShown != null && _layoutShown != layout) {
      final ayah = _current.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.isAttached) {
          _scroll.jumpTo(index: _indexOfAyah(ayah, layout));
        }
      });
    }
    if (ready) _layoutShown = layout;

    final count = layout == QuranLayout.verses
        ? ayahs.length + 2
        : (ayahs.length + _chunk - 1) ~/ _chunk + 2;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name),
            ValueListenableBuilder<int>(
              valueListenable: _current,
              builder: (context, ayah, _) => Text(
                'Ayah $ayah of ${s.ayahs} · Juz ${repo.juzOf(s.number, ayah)}',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Go to ayah',
            icon: const Icon(Icons.format_list_numbered_rounded),
            onPressed: ready ? _goToAyah : null,
          ),
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: ValueListenableBuilder<int>(
            valueListenable: _current,
            builder: (context, ayah, _) => TweenAnimationBuilder<double>(
              tween: Tween(end: ayah / s.ayahs),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                color: c.emerald,
                backgroundColor: c.emeraldSoft,
                semanticsLabel: 'Reading progress, ayah $ayah of ${s.ayahs}',
              ),
            ),
          ),
        ),
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : ScrollablePositionedList.builder(
              key: ValueKey(layout),
              itemCount: count,
              itemScrollController: _scroll,
              itemPositionsListener: _positions,
              initialScrollIndex: _indexOfAyah(
                _layoutShown == layout ? _current.value : 1,
                layout,
              ).clamp(0, count - 1),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              itemBuilder: (context, i) {
                if (i == 0) return _SurahHeader(surah: s);
                if (i == count - 1) return _SurahNav(surah: s.number);
                if (layout == QuranLayout.verses) {
                  final a = ayahs[i - 1];
                  return _AyahTile(
                    surah: s.number,
                    ayah: a,
                    fontScale: repo.fontScale,
                    bookmarked: repo.isBookmarked(s.number, a.number),
                    sajda: repo.isSajda(s.number, a.number),
                    juz: repo.juzStartingAt(s.number, a.number),
                    onTap: () => _ayahActions(a),
                    onBookmark: () {
                      HapticFeedback.selectionClick();
                      repo.toggleBookmark(s.number, a.number);
                    },
                  );
                }
                final from = (i - 1) * _chunk;
                return _MushafParagraph(
                  ayahs: ayahs.sublist(
                    from,
                    (from + _chunk).clamp(0, ayahs.length),
                  ),
                  surah: s.number,
                  fontScale: repo.fontScale,
                  onAyahTap: _ayahActions,
                );
              },
            ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  const _SurahHeader({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<QuranRepository>();
    final state = repo.translationState;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.isDark
                      ? const [Color(0xFF0F5C49), Color(0xFF123A4E)]
                      : const [Color(0xFF0E8F6E), Color(0xFF136A8A)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  children: [
                    Text(
                      surah.arabic,
                      textDirection: TextDirection.rtl,
                      style: AppTheme.arabic(
                        fontSize: 36,
                        color: const Color(0xFFFFE3A6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${surah.meaning} · ${surah.revelation} · ${surah.ayahs} ayahs',
                      textAlign: TextAlign.center,
                      style: context.text.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (surah.hasBasmalaHeader) ...[
                      const SizedBox(height: 14),
                      Text(
                        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        style: AppTheme.arabic(
                          fontSize: 26,
                          color: Colors.white,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (repo.layout == QuranLayout.verses &&
              (state == TranslationState.missing ||
                  state == TranslationState.failed ||
                  state == TranslationState.downloading)) ...[
            const SizedBox(height: 10),
            SurfaceCard(
              color: c.emeraldSoft,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: c.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state == TranslationState.downloading
                          ? 'Downloading translation…'
                          : 'Show the ${repo.translation.label} translation',
                      style: context.text.bodyMedium,
                    ),
                  ),
                  if (state == TranslationState.downloading)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: repo.ensureTranslation,
                      style: TextButton.styleFrom(foregroundColor: c.emerald),
                      child: const Text('Download'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AyahTile extends StatelessWidget {
  const _AyahTile({
    required this.surah,
    required this.ayah,
    required this.fontScale,
    required this.bookmarked,
    required this.sajda,
    required this.juz,
    required this.onTap,
    required this.onBookmark,
  });

  final int surah;
  final Ayah ayah;
  final double fontScale;
  final bool bookmarked;
  final bool sajda;
  final int? juz;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (juz != null)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Row(
              children: [
                Expanded(child: Divider(color: c.gold.withValues(alpha: 0.5))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'JUZ $juz',
                    style: context.text.labelSmall?.copyWith(
                      color: c.gold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: c.gold.withValues(alpha: 0.5))),
              ],
            ),
          ),
        InkWell(
          onTap: onTap,
          onLongPress: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _AyahNumber(ayah.number),
                    if (sajda) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Sajdah',
                          style: context.text.labelSmall?.copyWith(
                            color: c.gold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
                      visualDensity: VisualDensity.compact,
                      onPressed: onBookmark,
                      icon: Icon(
                        bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color: bookmarked ? c.emerald : c.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ayah.arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: AppTheme.arabic(
                    fontSize: 27 * fontScale,
                    color: c.ink,
                    height: 2.05,
                  ),
                ),
                if (ayah.translation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    ayah.translation,
                    style: context.text.bodyMedium?.copyWith(
                      fontSize: 15 * fontScale.clamp(0.9, 1.4),
                      color: c.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(color: c.line),
      ],
    );
  }
}

class _AyahNumber extends StatelessWidget {
  const _AyahNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.emeraldSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$number',
        style: context.text.labelSmall?.copyWith(
          color: c.emerald,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A run of ayahs as continuous Arabic text with ornate end markers.
class _MushafParagraph extends StatelessWidget {
  const _MushafParagraph({
    required this.ayahs,
    required this.surah,
    required this.fontScale,
    required this.onAyahTap,
  });

  final List<Ayah> ayahs;
  final int surah;
  final double fontScale;
  final ValueChanged<Ayah> onAyahTap;

  static String _arabicDigits(int n) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return n.toString().split('').map((d) => digits[int.parse(d)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.read<QuranRepository>();
    final style = AppTheme.arabic(
      fontSize: 27 * fontScale,
      color: c.ink,
      height: 2.2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text.rich(
        TextSpan(
          children: [
            for (final a in ayahs) ...[
              TextSpan(text: '${a.arabic} '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => onAyahTap(a),
                  child: Text(
                    '﴿${_arabicDigits(a.number)}﴾',
                    style: style.copyWith(
                      color: repo.isBookmarked(surah, a.number)
                          ? c.emerald
                          : c.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' '),
            ],
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        style: style,
      ),
    );
  }
}

class _SurahNav extends StatelessWidget {
  const _SurahNav({required this.surah});

  final int surah;

  @override
  Widget build(BuildContext context) {
    void go(int n) => Navigator.of(context).pushReplacement(surahRoute(n));
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          if (surah > 1)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => go(surah - 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(
                  Surah.byNumber(surah - 1).name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (surah > 1 && surah < 114) const SizedBox(width: 8),
          if (surah < 114)
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.emerald,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => go(surah + 1),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(
                  Surah.byNumber(surah + 1).name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grid of ayah numbers to jump to.
class _AyahPicker extends StatelessWidget {
  const _AyahPicker({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [Text('Go to ayah', style: context.text.titleLarge)],
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: count,
              itemBuilder: (context, i) {
                final n = i + 1;
                final on = n == current;
                return Material(
                  color: on ? c.emerald : c.cardAlt,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, n),
                    child: Center(
                      child: Text(
                        '$n',
                        style: context.text.titleSmall?.copyWith(
                          color: on ? Colors.white : c.ink,
                        ),
                      ),
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

class _ReaderSettings extends StatelessWidget {
  const _ReaderSettings();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<QuranRepository>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reading', style: context.text.titleLarge),
            const SizedBox(height: 16),
            PillTabs<QuranLayout>(
              values: QuranLayout.values,
              selected: repo.layout,
              onChanged: repo.setLayout,
              labelOf: (l) =>
                  l == QuranLayout.verses ? 'Ayah by ayah' : 'Mushaf',
              iconOf: (l) => l == QuranLayout.verses
                  ? Icons.view_agenda_outlined
                  : Icons.menu_book_outlined,
            ),
            const SizedBox(height: 18),
            Text('Text size', style: context.text.labelMedium),
            Row(
              children: [
                Icon(Icons.text_decrease_rounded, color: c.muted),
                Expanded(
                  child: Slider(
                    value: repo.fontScale,
                    min: 0.8,
                    max: 1.8,
                    divisions: 10,
                    activeColor: c.emerald,
                    onChanged: repo.setFontScale,
                  ),
                ),
                Icon(Icons.text_increase_rounded, color: c.muted),
              ],
            ),
            Text(
              'بِسْمِ ٱللَّهِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(
                fontSize: 27 * repo.fontScale,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text('Translation', style: context.text.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in QuranTranslation.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: repo.translation == t,
                    onSelected: (_) async {
                      await repo.setTranslation(t);
                      await repo.ensureTranslation(download: false);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              repo.translation == QuranTranslation.none
                  ? 'Only the Arabic text is shown.'
                  : '${repo.translation.author}. Downloaded once, then offline.',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
