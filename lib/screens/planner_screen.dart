import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/planner_repository.dart';
import '../models/planner.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/planner_sheets.dart';

enum _View { day, tasks }

enum _TaskFilter {
  today('Today'),
  upcoming('Upcoming'),
  someday('No date'),
  all('All'),
  done('Done');

  const _TaskFilter(this.label);
  final String label;
}

/// The day planner (time blocks) and the task manager.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  _View _view = _View.day;
  DateTime _day = Dates.today();
  _TaskFilter _filter = _TaskFilter.today;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // Moves the "now" marker along.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String get _dayKey => Dates.key(_day);

  void _goTo(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() => _day = DateTime(day.year, day.month, day.day));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 5),
      lastDate: DateTime(_day.year + 5),
    );
    if (picked != null) _goTo(picked);
  }

  Future<void> _copyPrevious() async {
    final repo = context.read<PlannerRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final from = Dates.key(Dates.previousDay(_day));
    final n = await repo.copyDay(from, _dayKey);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Nothing planned the day before.'
                : 'Copied $n ${n == 1 ? 'block' : 'blocks'}.',
          ),
        ),
      );
  }

  void _deletedTask(Task task) {
    final repo = context.read<PlannerRepository>();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.saveTask(task),
          ),
        ),
      );
  }

  void _deletedBlock(PlanBlock block) {
    final repo = context.read<PlannerRepository>();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Block removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.saveBlock(block),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlannerRepository>();
    final isToday = _day == Dates.today();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 124,
            title: const Text('Planner'),
            actions: [
              if (_view == _View.day) ...[
                if (!isToday)
                  TextButton(
                    onPressed: () => _goTo(Dates.today()),
                    child: const Text('Today'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'copy') _copyPrevious();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy the day before'),
                    ),
                  ],
                ),
              ] else if (repo.tasks.any((t) => t.done))
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) async {
                    if (v != 'clear') return;
                    final messenger = ScaffoldMessenger.of(context);
                    final removed = await repo.clearCompleted();
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Cleared ${removed.length} done'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () {
                              for (final t in removed) {
                                repo.saveTask(t);
                              }
                            },
                          ),
                        ),
                      );
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'clear',
                      child: Text('Clear completed tasks'),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: PillTabs<_View>(
                values: _View.values,
                selected: _view,
                onChanged: (v) => setState(() => _view = v),
                labelOf: (v) => v == _View.day
                    ? 'Day plan'
                    : (repo.openCount == 0
                          ? 'Tasks'
                          : 'Tasks · ${repo.openCount}'),
                iconOf: (v) => v == _View.day
                    ? Icons.view_timeline_outlined
                    : Icons.checklist_rounded,
              ),
            ),
          ),
          if (_view == _View.day)
            ..._daySlivers(context, repo)
          else
            ..._taskSlivers(context, repo),
          const SliverToBoxAdapter(child: BottomSpace(extra: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'planner-add',
        onPressed: () => _view == _View.day
            ? showBlockEditor(context, day: _dayKey)
            : showTaskEditor(
                context,
                dueDay: _filter == _TaskFilter.today ? Dates.todayKey() : null,
              ),
        icon: const Icon(Icons.add_rounded),
        label: Text(_view == _View.day ? 'Block' : 'Task'),
      ),
    );
  }

  // ------------------------------------------------------------- day view --

  List<Widget> _daySlivers(BuildContext context, PlannerRepository repo) {
    final blocks = repo.blocksFor(_dayKey);
    final due = repo.tasksDue(_dayKey);
    final done = blocks.where((b) => b.done).length;
    final planned = blocks.fold<int>(0, (m, b) => m + b.minutes);
    final now = DateTime.now();
    final nowMin = _day == Dates.today() ? now.hour * 60 + now.minute : null;
    final hasYesterday = repo.hasPlans(Dates.key(Dates.previousDay(_day)));

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.list(
          children: [
            _DayPicker(
              day: _day,
              hasPlans: repo.hasPlans,
              onSelect: _goTo,
              onPickDate: _pickDay,
            ),
            const SizedBox(height: 12),
            if (blocks.isNotEmpty) ...[
              _DaySummary(done: done, total: blocks.length, minutes: planned),
              const SizedBox(height: 16),
              for (final b in blocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Dismissible(
                    key: ValueKey('block-${b.id}'),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    onDismissed: (_) {
                      repo.deleteBlock(b.id);
                      _deletedBlock(b);
                    },
                    child: _BlockTile(
                      block: b,
                      isNow:
                          nowMin != null &&
                          nowMin >= b.startMin &&
                          nowMin < b.endMin,
                      isPast: nowMin != null && nowMin >= b.endMin,
                      onTap: () =>
                          showBlockEditor(context, day: _dayKey, block: b),
                      onToggle: () {
                        HapticFeedback.lightImpact();
                        repo.toggleBlock(b.id);
                      },
                    ),
                  ),
                ),
            ] else
              EmptyState(
                icon: Icons.view_timeline_outlined,
                title: 'Nothing planned',
                message:
                    'Split ${_day == Dates.today() ? 'your day' : 'this day'} into blocks of time: work, prayer, sport, rest.',
                action: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => showBlockEditor(context, day: _dayKey),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add a block'),
                    ),
                    if (hasYesterday)
                      OutlinedButton.icon(
                        onPressed: _copyPrevious,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy the day before'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            SectionLabel(
              'Tasks for ${_day == Dates.today() ? 'today' : Dates.header(_day)}',
              trailing: TextButton.icon(
                onPressed: () => showTaskEditor(context, dueDay: _dayKey),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 32)),
              ),
            ),
            if (due.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                child: Text(
                  'No tasks due on this day.',
                  style: context.text.bodySmall,
                ),
              )
            else
              for (final t in due) _taskTile(context, repo, t),
          ],
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ task view --

  List<Widget> _taskSlivers(BuildContext context, PlannerRepository repo) {
    final today = Dates.todayKey();
    bool matches(Task t, _TaskFilter f) => switch (f) {
      _TaskFilter.today =>
        !t.done && t.dueDay != null && t.dueDay!.compareTo(today) <= 0,
      _TaskFilter.upcoming =>
        !t.done && t.dueDay != null && t.dueDay!.compareTo(today) > 0,
      _TaskFilter.someday => !t.done && t.dueDay == null,
      _TaskFilter.all => !t.done,
      _TaskFilter.done => t.done,
    };
    final tasks = repo.tasks.where((t) => matches(t, _filter)).toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.list(
          children: [
            _QuickAdd(
              hint: _filter == _TaskFilter.today
                  ? 'Add a task for today'
                  : 'Add a task',
              onSubmit: (title) => repo.addTask(
                title,
                dueDay: _filter == _TaskFilter.today ? today : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final f in _TaskFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(() {
                      final n = repo.tasks.where((t) => matches(t, f)).length;
                      return n == 0 ? f.label : '${f.label} · $n';
                    }()),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        sliver: tasks.isEmpty
            ? SliverToBoxAdapter(
                child: EmptyState(
                  icon: _filter == _TaskFilter.done
                      ? Icons.task_alt_rounded
                      : Icons.checklist_rounded,
                  title: switch (_filter) {
                    _TaskFilter.today => 'All clear for today',
                    _TaskFilter.done => 'Nothing done yet',
                    _ => 'No tasks here',
                  },
                  message: _filter == _TaskFilter.done
                      ? 'Tasks you check off will show up here.'
                      : 'Type above or tap + to add a task.',
                ),
              )
            : SliverList.list(
                children: [for (final t in tasks) _taskTile(context, repo, t)],
              ),
      ),
    ];
  }

  Widget _taskTile(BuildContext context, PlannerRepository repo, Task t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('task-${t.id}'),
        direction: DismissDirection.endToStart,
        background: const _DeleteBackground(),
        onDismissed: (_) {
          repo.deleteTask(t.id);
          _deletedTask(t);
        },
        child: TaskTile(
          task: t,
          onTap: () => showTaskEditor(context, task: t),
          onToggle: () {
            HapticFeedback.lightImpact();
            repo.toggleTask(t.id);
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ parts --

/// Month header plus the week of [day]; dots mark days with a plan.
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.day,
    required this.hasPlans,
    required this.onSelect,
    required this.onPickDate,
  });

  final DateTime day;
  final bool Function(String day) hasPlans;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = Dates.today();
    final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
    final week = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: () =>
                    onSelect(DateTime(day.year, day.month, day.day - 7)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Dates.header(day),
                          style: context.text.titleMedium,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: c.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () =>
                    onSelect(DateTime(day.year, day.month, day.day + 7)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final d in week)
                _WeekDay(
                  day: d,
                  selected: d == day,
                  isToday: d == today,
                  planned: hasPlans(Dates.key(d)),
                  onTap: () => onSelect(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.planned,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool planned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : (isToday ? c.primary : c.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: Dates.compact(day),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                Dates.shortWeekday(day).substring(0, 1),
                style: context.text.labelSmall?.copyWith(
                  color: selected ? c.onPrimary : c.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: context.text.titleSmall?.copyWith(color: fg),
              ),
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: planned
                      ? (selected ? c.onPrimary : c.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.done,
    required this.total,
    required this.minutes,
  });

  final int done;
  final int total;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$done of $total done', style: context.text.titleSmall),
              const Spacer(),
              Text(
                '${PlanBlock.length(minutes)} planned',
                style: context.text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              color: done == total ? c.success : c.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.block,
    required this.isNow,
    required this.isPast,
    required this.onTap,
    required this.onToggle,
  });

  final PlanBlock block;
  final bool isNow;
  final bool isPast;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = block;
    final dim = b.done || (isPast && !isNow);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PlanBlock.clock(b.startMin),
                  style: context.text.titleSmall?.copyWith(
                    color: isNow ? c.primary : c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  PlanBlock.clock(b.endMin),
                  style: context.text.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: isNow ? c.primarySoft : c.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isNow ? c.primary : c.line,
                width: isNow ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5,
                      color: b.swatch.withValues(alpha: dim ? 0.4 : 1),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    b.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleMedium?.copyWith(
                                      color: dim ? c.muted : c.ink,
                                      decoration: b.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                if (isNow) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Now',
                                      style: context.text.labelSmall?.copyWith(
                                        color: c.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              PlanBlock.length(b.minutes),
                              style: context.text.bodySmall,
                            ),
                            if (b.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                b.note,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: _CheckCircle(
                        checked: b.done,
                        color: b.swatch,
                        onTap: onToggle,
                        label: b.done ? 'Mark not done' : 'Mark done',
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A task row: check circle, title, due date and priority.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = task;
    final overdue =
        !t.done &&
        t.dueDay != null &&
        t.dueDay!.compareTo(Dates.todayKey()) < 0;
    final details = <Widget>[
      if (t.dueDay != null)
        _Meta(
          icon: Icons.event_outlined,
          text: dueLabel(t.dueDay!),
          color: overdue ? c.danger : c.muted,
        ),
      if (t.priority != TaskPriority.none)
        _Meta(
          icon: Icons.flag_rounded,
          text: t.priority.label,
          color: priorityColor(context, t.priority),
        ),
      if (t.note.isNotEmpty)
        _Meta(icon: Icons.notes_rounded, text: 'Note', color: c.muted),
    ];

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      radius: 16,
      child: Row(
        children: [
          _CheckCircle(
            checked: t.done,
            color: t.priority == TaskPriority.none
                ? c.primary
                : priorityColor(context, t.priority),
            onTap: onToggle,
            label: t.done ? 'Mark not done' : 'Mark done',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: context.text.bodyLarge?.copyWith(
                      fontSize: 15.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: t.done ? c.muted : c.ink,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 12, runSpacing: 2, children: details),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.checked,
    required this.color,
    required this.onTap,
    required this.label,
  });

  final bool checked;
  final Color color;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _QuickAdd extends StatefulWidget {
  const _QuickAdd({required this.hint, required this.onSubmit});

  final String hint;
  final ValueChanged<String> onSubmit;

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
    _focus.requestFocus(); // keep typing the next one
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      onTapOutside: (_) => _focus.unfocus(),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.add_task_rounded),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.trim().isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Add',
                  onPressed: _submit,
                  icon: Icon(
                    Icons.arrow_upward_rounded,
                    color: context.colors.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.delete_outline_rounded, color: c.danger),
    );
  }
}
