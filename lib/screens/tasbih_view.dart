import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/tasbih_repository.dart';
import '../models/dhikr.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Digital tasbih: tap the bead ring to count.
class TasbihView extends StatefulWidget {
  const TasbihView({super.key});

  @override
  State<TasbihView> createState() => _TasbihViewState();
}

class _TasbihViewState extends State<TasbihView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      context.read<TasbihRepository>().flush();
    }
  }

  void _tap() {
    final repo = context.read<TasbihRepository>();
    final result = repo.increment();
    switch (result) {
      case TasbihTap.counted:
        HapticFeedback.lightImpact();
      case TasbihTap.roundComplete:
      case TasbihTap.nextInSequence:
        HapticFeedback.heavyImpact();
      case TasbihTap.sequenceComplete:
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('After-prayer tasbih complete. Taqabbal Allah.'),
            ),
          );
    }
  }

  Future<void> _chooseTarget() async {
    final repo = context.read<TasbihRepository>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in const [33, 34, 99, 100, 1000, 0])
              ListTile(
                title: Text(n == 0 ? 'No limit' : '$n'),
                trailing: repo.target == n
                    ? Icon(Icons.check_rounded, color: ctx.colors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, n),
              ),
            ListTile(
              title: const Text('Custom…'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked >= 0) {
      repo.setTarget(picked);
      return;
    }
    final text = await promptText(
      context,
      title: 'Target',
      hint: 'e.g. 500',
      initial: repo.target > 0 ? '${repo.target}' : '',
      keyboardType: TextInputType.number,
    );
    final n = int.tryParse(text?.trim() ?? '');
    if (n != null && n > 0) repo.setTarget(n);
  }

  Future<void> _addDhikr() async {
    final repo = context.read<TasbihRepository>();
    final d = await showModalBottomSheet<Dhikr>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _NewDhikrSheet(),
    );
    if (d == null) return;
    final added = await repo.addDhikr(
      latin: d.latin,
      arabic: d.arabic,
      meaning: d.meaning,
      target: d.target,
    );
    repo.select(added.id);
  }

  Future<void> _deleteDhikr(Dhikr d) async {
    final repo = context.read<TasbihRepository>();
    final ok = await confirmDialog(
      context,
      title: 'Remove "${d.latin}"?',
      message: 'Counts already saved in your history stay.',
      confirm: 'Remove',
      destructive: true,
    );
    if (ok) await repo.deleteDhikr(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<TasbihRepository>();
    final d = repo.current;

    return SliverList.list(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final x in repo.all)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: x.custom
                      ? InputChip(
                          label: Text(x.latin),
                          selected: x.id == d.id,
                          showCheckmark: false,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            repo.select(x.id);
                          },
                          deleteButtonTooltipMessage: 'Remove',
                          onDeleted: () => _deleteDhikr(x),
                        )
                      : ChoiceChip(
                          label: Text(x.latin),
                          selected: x.id == d.id,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            repo.select(x.id);
                          },
                        ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                onPressed: _addDhikr,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (d.arabic.isNotEmpty)
                Text(
                  d.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppTheme.arabic(
                    fontSize: 30,
                    color: c.ink,
                    height: 1.6,
                  ),
                ),
              Text(
                d.latin,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              if (d.meaning.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  d.meaning,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(box.maxWidth - 64, 280.0);
              return Semantics(
                button: true,
                label:
                    'Count ${d.latin}. ${repo.count}${repo.target > 0 ? ' of ${repo.target}' : ''}',
                excludeSemantics: true,
                child: Pressable(
                  scale: 0.97,
                  onTap: _tap,
                  child: SizedBox.square(
                    dimension: size,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: repo.progress,
                        target: repo.target,
                        count: repo.count,
                        track: c.emeraldSoft,
                        fill: c.emerald,
                        bead: c.card,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 120),
                              transitionBuilder: (child, a) => ScaleTransition(
                                scale: Tween(begin: 0.85, end: 1.0).animate(a),
                                child: FadeTransition(opacity: a, child: child),
                              ),
                              child: Text(
                                '${repo.count}',
                                key: ValueKey(repo.count),
                                style:
                                    AppTheme.font(
                                      fontSize: size * 0.26,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                      letterSpacing: -2,
                                    ).copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ),
                            Text(
                              repo.target > 0
                                  ? 'of ${repo.target}'
                                  : 'no limit',
                              style: context.text.labelMedium,
                            ),
                            if (repo.rounds > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.emeraldSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${repo.rounds} ${repo.rounds == 1 ? 'round' : 'rounds'}',
                                  style: context.text.labelSmall?.copyWith(
                                    color: c.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<TasbihRepository>(),
                  child: const TasbihFocusScreen(),
                ),
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: c.emerald),
            icon: const Icon(Icons.fullscreen_rounded),
            label: const Text('Focus mode: tap anywhere'),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Take back one',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: repo.count == 0
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        repo.decrement();
                      },
                icon: const Icon(Icons.undo_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _chooseTarget,
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: Text(
                    repo.target > 0 ? 'Goal ${repo.target}' : 'No goal',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Start over',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  side: BorderSide(color: c.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: repo.count == 0 && repo.rounds == 0
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        repo.reset();
                      },
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GroupCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_mode_rounded),
                title: const Text('After-prayer tasbih'),
                subtitle: const Text(
                  'SubhanAllah 33 · Alhamdulillah 33 · Allahu Akbar 34, one after another',
                ),
                value: repo.sequence,
                onChanged: repo.setSequence,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _TasbihStats(),
        ),
      ],
    );
  }
}

/// Progress ring with a bead travelling around it.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.target,
    required this.count,
    required this.track,
    required this.fill,
    required this.bead,
  });

  final double progress;
  final int target;
  final int count;
  final Color track;
  final Color fill;
  final Color bead;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.06;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Without a target, the bead loops every 33.
    final sweep = target > 0 ? progress : (count % 33) / 33;
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
    final angle = -math.pi / 2 + 2 * math.pi * sweep;
    final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(p, stroke * 0.85, Paint()..color = fill);
    canvas.drawCircle(p, stroke * 0.42, Paint()..color = bead);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.count != count ||
      old.target != target ||
      old.fill != fill ||
      old.track != track;
}

class _TasbihStats extends StatelessWidget {
  const _TasbihStats();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.watch<TasbihRepository>();
    final history = repo.history();
    final maxDay = history.fold<int>(1, (m, e) => math.max(m, e.$2));
    final breakdown = repo.todayBreakdown;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: context.text.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Your dhikr'),
        SurfaceCard(
          child: Column(
            children: [
              Row(
                children: [
                  stat('${repo.todayTotal}', 'today'),
                  stat(
                    '${repo.streak}',
                    repo.streak == 1 ? 'day streak' : 'days streak',
                  ),
                  stat('${repo.lifetimeTotal}', 'all time'),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 92,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (day, n) in history)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Tooltip(
                                message: '${Dates.compact(day)}: $n',
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: n == 0 ? 4 : 4 + 56 * n / maxDay,
                                  decoration: BoxDecoration(
                                    color: day == Dates.today()
                                        ? c.emerald
                                        : (n == 0 ? c.cardAlt : c.emeraldSoft),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                Dates.shortWeekday(day).substring(0, 1),
                                style: context.text.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (breakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          GroupCard(
            children: [
              for (final (d, n) in breakdown)
                ListTile(
                  dense: true,
                  title: Text(d.latin),
                  trailing: Text('$n', style: context.text.titleSmall),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NewDhikrSheet extends StatefulWidget {
  const _NewDhikrSheet();

  @override
  State<_NewDhikrSheet> createState() => _NewDhikrSheetState();
}

class _NewDhikrSheetState extends State<_NewDhikrSheet> {
  final _latin = TextEditingController();
  final _arabic = TextEditingController();
  final _meaning = TextEditingController();
  final _target = TextEditingController(text: '33');

  @override
  void dispose() {
    _latin.dispose();
    _arabic.dispose();
    _meaning.dispose();
    _target.dispose();
    super.dispose();
  }

  void _save() {
    if (_latin.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      Dhikr(
        id: '',
        latin: _latin.text,
        arabic: _arabic.text,
        meaning: _meaning.text,
        target: int.tryParse(_target.text.trim()) ?? 33,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New dhikr', style: context.text.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: _latin,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Name, e.g. Ya Latif',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _arabic,
              textDirection: TextDirection.rtl,
              style: AppTheme.arabic(fontSize: 20, color: context.colors.ink),
              decoration: const InputDecoration(hintText: 'Arabic (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _meaning,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Meaning (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Target',
                prefixText: 'Target  ',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _latin.text.trim().isEmpty ? null : _save,
              child: const Text('Add dhikr'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen counter: the whole screen is the button, so you can count
/// without looking. Closes with the X or the back gesture.
class TasbihFocusScreen extends StatelessWidget {
  const TasbihFocusScreen({super.key});

  void _tap(BuildContext context) {
    final result = context.read<TasbihRepository>().increment();
    switch (result) {
      case TasbihTap.counted:
        HapticFeedback.lightImpact();
      case TasbihTap.roundComplete || TasbihTap.nextInSequence:
        HapticFeedback.heavyImpact();
      case TasbihTap.sequenceComplete:
        HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasbihRepository>();
    final d = repo.current;
    const fg = Colors.white;
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Semantics(
          button: true,
          label:
              'Count ${d.latin}. ${repo.count}${repo.target > 0 ? ' of ${repo.target}' : ''}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tap(context),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B5E4A), Color(0xFF0B2E3D)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Close',
                          color: fg,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Spacer(),
                        if (repo.rounds > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              '${repo.rounds} ${repo.rounds == 1 ? 'round' : 'rounds'}',
                              style: context.text.labelLarge?.copyWith(
                                color: fg.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (d.arabic.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          d.arabic,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: AppTheme.arabic(
                            fontSize: 36,
                            color: const Color(0xFFFFE3A6),
                            height: 1.6,
                          ),
                        ),
                      ),
                    Text(
                      d.latin,
                      style: context.text.titleMedium?.copyWith(
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox.square(
                      dimension: 240,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: repo.progress,
                          target: repo.target,
                          count: repo.count,
                          track: fg.withValues(alpha: 0.12),
                          fill: const Color(0xFFFFE3A6),
                          bead: const Color(0xFF0B4A3C),
                        ),
                        child: Center(
                          child: Text(
                            '${repo.count}',
                            style:
                                AppTheme.font(
                                  fontSize: 76,
                                  fontWeight: FontWeight.w800,
                                  color: fg,
                                  letterSpacing: -3,
                                ).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      repo.target > 0 ? 'Goal ${repo.target}' : 'No goal',
                      style: context.text.labelLarge?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton.icon(
                        onPressed: repo.count == 0 ? null : repo.decrement,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          disabledForegroundColor: fg.withValues(alpha: 0.3),
                        ),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Take back one'),
                      ),
                    ),
                    Text(
                      'Tap anywhere to count',
                      style: context.text.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
