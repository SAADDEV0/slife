import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/planner_repository.dart';
import '../models/planner.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';

/// Opens the editor for a new block on [day], or for [block].
Future<void> showBlockEditor(
  BuildContext context, {
  required String day,
  PlanBlock? block,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<PlannerRepository>(),
      child: _BlockEditor(day: day, block: block),
    ),
  );
}

/// Opens the editor for a new task (optionally due on [dueDay]) or [task].
Future<void> showTaskEditor(
  BuildContext context, {
  Task? task,
  String? dueDay,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<PlannerRepository>(),
      child: _TaskEditor(task: task, dueDay: dueDay),
    ),
  );
}

/// Bottom-sheet scaffolding: title row, scrollable content, keyboard inset.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children, this.onDelete});

  final String title;
  final List<Widget> children;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.text.titleLarge)),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.danger,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ block --

class _BlockEditor extends StatefulWidget {
  const _BlockEditor({required this.day, this.block});

  final String day;
  final PlanBlock? block;

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  late final _title = TextEditingController(text: widget.block?.title ?? '');
  late final _note = TextEditingController(text: widget.block?.note ?? '');
  late int _start;
  late int _end;
  late int _color;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    if (b != null) {
      _start = b.startMin;
      _end = b.endMin;
      _color = b.color;
    } else {
      final repo = context.read<PlannerRepository>();
      final now = DateTime.now();
      // Today: start from the next quarter hour; other days from 9:00.
      final after = Dates.isToday(widget.day)
          ? ((now.hour * 60 + now.minute + 14) ~/ 15) * 15
          : 9 * 60;
      final (start, end) = repo.suggestSlot(widget.day, after: after);
      _start = start;
      _end = end;
      _color = repo.blocksFor(widget.day).length % planColors.length;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty && _end > _start;

  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ~/ 60) % 24, minute: current % 60),
      helpText: start ? 'Starts at' : 'Ends at',
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        final length = _end - _start;
        _start = m;
        // Keep the block's length when moving its start.
        _end = (m + (length > 0 ? length : 60)).clamp(m + 5, 24 * 60);
      } else {
        _end = m == 0 ? 24 * 60 : m;
      }
    });
  }

  Future<void> _save() async {
    if (!_valid) return;
    final repo = context.read<PlannerRepository>();
    final b = widget.block;
    await repo.saveBlock(
      b == null
          ? repo.newBlock(
              day: widget.day,
              startMin: _start,
              endMin: _end,
              title: _title.text,
              note: _note.text,
              color: _color,
            )
          : b.copyWith(
              startMin: _start,
              endMin: _end,
              title: _title.text.trim(),
              note: _note.text.trim(),
              color: _color,
            ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isNew = widget.block == null;
    return _Sheet(
      title: isNew ? 'New block' : 'Edit block',
      onDelete: isNew
          ? null
          : () {
              context.read<PlannerRepository>().deleteBlock(widget.block!.id);
              Navigator.pop(context);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: isNew,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'What will you do? e.g. Deep work',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Start',
                value: PlanBlock.clock(_start),
                onTap: () => _pick(true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded, color: c.muted),
            ),
            Expanded(
              child: _TimeButton(
                label: 'End',
                value: PlanBlock.clock(_end),
                onTap: () => _pick(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _end > _start
              ? PlanBlock.length(_end - _start)
              : 'The end must be after the start',
          style: context.text.bodySmall?.copyWith(
            color: _end > _start ? c.muted : c.danger,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < planColors.length; i++)
              Semantics(
                button: true,
                selected: i == _color,
                label: 'Color ${i + 1}',
                child: GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: planColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _color ? c.ink : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: i == _color
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Notes (optional)'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: Text(isNew ? 'Add to plan' : 'Save'),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.cardAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(label, style: context.text.labelSmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.text.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- task --

/// Color of a task's priority flag.
Color priorityColor(BuildContext context, TaskPriority p) {
  final c = context.colors;
  return switch (p) {
    TaskPriority.high => c.danger,
    TaskPriority.medium => c.accent,
    TaskPriority.low => c.primary,
    TaskPriority.none => c.muted,
  };
}

/// "Today", "Tomorrow", "Yesterday" or "Mon, 12 Oct".
String dueLabel(String day) {
  final d = Dates.parse(day);
  final diff = d.difference(Dates.today()).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ when d.year == Dates.today().year => Dates.header(d),
    _ => Dates.compact(d),
  };
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({this.task, this.dueDay});

  final Task? task;
  final String? dueDay;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late final _note = TextEditingController(text: widget.task?.note ?? '');
  late String? _due = widget.task?.dueDay ?? widget.dueDay;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.none;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = Dates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due == null ? today : Dates.parse(_due!),
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) setState(() => _due = Dates.key(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = context.read<PlannerRepository>();
    final t = widget.task;
    if (t == null) {
      await repo.addTask(
        title,
        note: _note.text,
        dueDay: _due,
        priority: _priority,
      );
    } else {
      await repo.saveTask(
        t.copyWith(
          title: title,
          note: _note.text.trim(),
          dueDay: _due,
          clearDue: _due == null,
          priority: _priority,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.task == null;
    final today = Dates.todayKey();
    final tomorrow = Dates.key(Dates.today().add(const Duration(days: 1)));
    final custom = _due != null && _due != today && _due != tomorrow;

    return _Sheet(
      title: isNew ? 'New task' : 'Edit task',
      onDelete: isNew
          ? null
          : () {
              context.read<PlannerRepository>().deleteTask(widget.task!.id);
              Navigator.pop(context);
            },
      children: [
        TextField(
          controller: _title,
          autofocus: isNew,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Task name'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Notes (optional)'),
        ),
        const SizedBox(height: 18),
        Text('Due', style: context.text.labelMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('No date'),
              selected: _due == null,
              onSelected: (_) => setState(() => _due = null),
            ),
            ChoiceChip(
              label: const Text('Today'),
              selected: _due == today,
              onSelected: (_) => setState(() => _due = today),
            ),
            ChoiceChip(
              label: const Text('Tomorrow'),
              selected: _due == tomorrow,
              onSelected: (_) => setState(() => _due = tomorrow),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: Text(custom ? dueLabel(_due!) : 'Pick a date'),
              selected: custom,
              onSelected: (_) => _pickDate(),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Priority', style: context.text.labelMedium),
        const SizedBox(height: 8),
        SegmentedButton<TaskPriority>(
          showSelectedIcon: false,
          segments: [
            for (final p in TaskPriority.values)
              ButtonSegment(
                value: p,
                label: Text(p == TaskPriority.none ? 'None' : p.label),
                icon: p == TaskPriority.none
                    ? null
                    : Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: priorityColor(context, p),
                      ),
              ),
          ],
          selected: {_priority},
          onSelectionChanged: (s) => setState(() => _priority = s.first),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _title.text.trim().isEmpty ? null : _save,
          child: Text(isNew ? 'Add task' : 'Save'),
        ),
      ],
    );
  }
}
