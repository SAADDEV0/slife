import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

/// Reads one surah: Arabic text, translation, bookmarks.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, this.initialAyah});

  final int surah;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late Future<List<Ayah>> _ayahs;
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final Map<int, GlobalKey> _keys = {};
  Timer? _positionTimer;
  late final QuranRepository _repo;
  int _current = 1;
  bool _jumped = false;

  Surah get _surah => Surah.byNumber(widget.surah);

  @override
  void initState() {
    super.initState();
    _repo = context.read<QuranRepository>();
    _current = widget.initialAyah ?? 1;
    _load();
  }

  void _load() {
    _jumped = false;
    _ayahs = _repo.surah(widget.surah);
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    // Not while the tree is locked: listeners rebuild.
    final surah = widget.surah, ayah = _current, repo = _repo;
    scheduleMicrotask(() => repo.setLastRead(surah, ayah));
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int ayah) => _keys[ayah] ??= GlobalKey();

  void _jumpToInitial() {
    if (_jumped) return;
    _jumped = true;
    final ayah = widget.initialAyah;
    if (ayah == null || ayah <= 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[ayah]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.05);
    });
  }

  /// Remembers the ayah at the top of the screen as the reading position.
  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification) {
      _positionTimer?.cancel();
      _positionTimer = Timer(const Duration(milliseconds: 300), _track);
    }
    return false;
  }

  void _track() {
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !mounted) return;
    final top = viewport.localToGlobal(Offset.zero).dy + 80;
    var current = 1;
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= top && e.key > current) current = e.key;
    }
    // At the very end the last ayahs never reach the top of the screen.
    if (_scroll.hasClients && _scroll.position.extentAfter < 48) {
      current = _surah.ayahs;
    }
    if (current != _current) setState(() => _current = current);
    _repo.setLastRead(widget.surah, current);
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: _repo,
        child: const _ReaderSettings(),
      ),
    ).then((_) {
      // A new translation means new text.
      if (mounted && _repo.loaded(widget.surah) == null) {
        setState(_load);
      }
    });
  }

  void _ayahActions(Ayah a) {
    final s = _surah;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
              leading: const Icon(Icons.bookmark_added_outlined),
              title: const Text('Mark as last read'),
              onTap: () {
                _current = a.number;
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
    final s = _surah;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name),
            Text('${s.number} · ${s.meaning}', style: context.text.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _current / s.ayahs),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 2,
              semanticsLabel: 'Reading progress',
              semanticsValue: 'Ayah $_current of ${s.ayahs}',
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Ayah>>(
        future: _ayahs,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load ${s.name}',
                message:
                    'SLife downloads each surah once, then it works offline. '
                    'Check your connection and try again.',
                action: FilledButton.icon(
                  onPressed: () => setState(_load),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ),
            );
          }
          final ayahs = snap.data;
          if (ayahs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _jumpToInitial();
          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SingleChildScrollView(
              key: _viewport,
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SurahHeader(surah: s),
                  const SizedBox(height: 8),
                  for (final a in ayahs)
                    _AyahTile(
                      key: _keyFor(a.number),
                      surah: s.number,
                      ayah: a,
                      onMore: () => _ayahActions(a),
                    ),
                  const SizedBox(height: 16),
                  _SurahNav(surah: s.number),
                ],
              ),
            ),
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
    return SurfaceCard(
      color: c.primarySoft,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          Text(
            surah.arabic,
            textDirection: TextDirection.rtl,
            style: AppTheme.arabic(fontSize: 34, color: c.primary),
          ),
          Text(
            '${surah.revelation} · ${surah.ayahs} ayahs',
            style: context.text.labelMedium,
          ),
          if (surah.hasBasmalaHeader) ...[
            const SizedBox(height: 14),
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: AppTheme.arabic(fontSize: 26, color: c.ink, height: 1.8),
            ),
          ],
        ],
      ),
    );
  }
}

class _AyahTile extends StatelessWidget {
  const _AyahTile({
    super.key,
    required this.surah,
    required this.ayah,
    required this.onMore,
  });

  final int surah;
  final Ayah ayah;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<QuranRepository>();
    final scale = repo.fontScale;
    final marked = repo.isBookmarked(surah, ayah.number);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.cardAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$surah:${ayah.number}',
                    style: context.text.labelSmall,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: marked ? 'Remove bookmark' : 'Bookmark',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    repo.toggleBookmark(surah, ayah.number);
                  },
                  icon: Icon(
                    marked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: marked ? c.primary : c.muted,
                  ),
                ),
                IconButton(
                  tooltip: 'More',
                  visualDensity: VisualDensity.compact,
                  onPressed: onMore,
                  icon: Icon(Icons.more_horiz_rounded, color: c.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${ayah.arabic} ${_arabicNumber(ayah.number)}',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: AppTheme.arabic(
                fontSize: 26 * scale,
                color: c.ink,
                height: 2.0,
              ),
            ),
            if (ayah.translation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                ayah.translation,
                style: context.text.bodyMedium?.copyWith(
                  fontSize: 14.5 * scale.clamp(0.9, 1.4),
                  color: c.muted,
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ayah end marker with Arabic-Indic digits: ﴿١٢﴾
  static String _arabicNumber(int n) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    final s = n.toString().split('').map((d) => digits[int.parse(d)]).join();
    return '﴿$s﴾';
  }
}

class _SurahNav extends StatelessWidget {
  const _SurahNav({required this.surah});

  final int surah;

  @override
  Widget build(BuildContext context) {
    void go(int n) => Navigator.of(context).pushReplacement(surahRoute(n));
    return Row(
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
                fontSize: 26 * repo.fontScale,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text('Translation', style: context.text.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<QuranTranslation>(
              showSelectedIcon: false,
              segments: [
                for (final t in QuranTranslation.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {repo.translation},
              onSelectionChanged: (s) => repo.setTranslation(s.first),
            ),
            const SizedBox(height: 6),
            Text(
              repo.translation == QuranTranslation.none
                  ? 'Only the Arabic text is shown.'
                  : '${repo.translation.author}. Downloaded when you open a surah.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
