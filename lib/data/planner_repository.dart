import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/planner.dart';
import '../utils/dates.dart';

/// Day planner blocks and tasks, stored on the device.
///
/// Everything is kept in memory and written through to SQLite. Without a
/// database ([PlannerRepository.memory]) it works the same, minus saving.
class PlannerRepository extends ChangeNotifier {
  PlannerRepository(Database db) : _db = db;

  /// In-memory repository for tests and previews.
  @visibleForTesting
  PlannerRepository.memory({
    List<PlanBlock> blocks = const [],
    List<Task> tasks = const [],
  }) : _db = null {
    for (final b in blocks) {
      _blocks[b.id] = b;
    }
    for (final t in tasks) {
      _tasks[t.id] = t;
    }
    _reindex();
  }

  final Database? _db;
  static const _uuid = Uuid();

  final Map<String, PlanBlock> _blocks = {};
  final Map<String, Task> _tasks = {};
  Map<String, List<PlanBlock>> _byDay = const {};
  List<Task> _sortedTasks = const [];

  /// Called after every change made by the user (schedules a backup).
  VoidCallback? onLocalChange;

  void _changed() {
    _reindex();
    notifyListeners();
    onLocalChange?.call();
  }

  Future<void> load() async {
    final db = _db;
    if (db == null) return;
    final plans = await db.query('plans');
    final tasks = await db.query('tasks');
    _blocks
      ..clear()
      ..addEntries(plans.map(PlanBlock.fromRow).map((b) => MapEntry(b.id, b)));
    _tasks
      ..clear()
      ..addEntries(tasks.map(Task.fromRow).map((t) => MapEntry(t.id, t)));
    _reindex();
    notifyListeners();
  }

  void _reindex() {
    final byDay = <String, List<PlanBlock>>{};
    for (final b in _blocks.values) {
      (byDay[b.day] ??= []).add(b);
    }
    for (final list in byDay.values) {
      list.sort((a, b) {
        final c = a.startMin.compareTo(b.startMin);
        return c != 0 ? c : a.endMin.compareTo(b.endMin);
      });
    }
    _byDay = byDay;
    _sortedTasks = _tasks.values.toList()..sort(compareTasks);
  }

  /// Open tasks first; then by due date (undated last), priority, age.
  /// Done tasks: most recently completed first.
  static int compareTasks(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.done) {
      return (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      );
    }
    final ad = a.dueDay, bd = b.dueDay;
    if (ad != bd) {
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    }
    if (a.priority != b.priority) {
      return b.priority.index.compareTo(a.priority.index);
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  // ------------------------------------------------------------- planner --

  List<PlanBlock> blocksFor(String day) => _byDay[day] ?? const [];

  bool hasPlans(String day) => _byDay[day]?.isNotEmpty ?? false;

  /// Inserts or replaces [block].
  Future<void> saveBlock(PlanBlock block) async {
    _blocks[block.id] = block;
    _changed();
    await _db?.insert(
      'plans',
      block.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  PlanBlock newBlock({
    required String day,
    required int startMin,
    required int endMin,
    required String title,
    String note = '',
    int color = 0,
  }) {
    return PlanBlock(
      id: _uuid.v4(),
      day: day,
      startMin: startMin,
      endMin: endMin,
      title: title.trim(),
      note: note.trim(),
      color: color,
      createdAt: DateTime.now(),
    );
  }

  Future<void> toggleBlock(String id) async {
    final b = _blocks[id];
    if (b != null) await saveBlock(b.copyWith(done: !b.done));
  }

  Future<void> deleteBlock(String id) async {
    if (_blocks.remove(id) == null) return;
    _changed();
    await _db?.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  /// Copies every block of [from] onto [to] (unchecked). Returns how many.
  Future<int> copyDay(String from, String to) async {
    final copies = [
      for (final b in blocksFor(from))
        newBlock(
          day: to,
          startMin: b.startMin,
          endMin: b.endMin,
          title: b.title,
          note: b.note,
          color: b.color,
        ),
    ];
    if (copies.isEmpty) return 0;
    for (final b in copies) {
      _blocks[b.id] = b;
    }
    _changed();
    final batch = _db?.batch();
    for (final b in copies) {
      batch?.insert('plans', b.toRow());
    }
    await batch?.commit(noResult: true);
    return copies.length;
  }

  // -------------------------------------------------------------- backup --

  Map<String, Object?> toBackup() => {
    'plans': [for (final b in _blocks.values) b.toRow()],
    'tasks': [for (final t in _tasks.values) t.toRow()],
  };

  /// Adds blocks and tasks from a backup that are not on this device yet.
  /// Returns how many were added.
  Future<int> mergeBackup(Map<String, Object?> json) async {
    final plans = [
      for (final r in (json['plans'] as List? ?? const []))
        PlanBlock.fromRow((r as Map).cast<String, Object?>()),
    ].where((b) => !_blocks.containsKey(b.id)).toList();
    final tasks = [
      for (final r in (json['tasks'] as List? ?? const []))
        Task.fromRow((r as Map).cast<String, Object?>()),
    ].where((t) => !_tasks.containsKey(t.id)).toList();
    if (plans.isEmpty && tasks.isEmpty) return 0;
    final batch = _db?.batch();
    for (final b in plans) {
      _blocks[b.id] = b;
      batch?.insert(
        'plans',
        b.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    for (final t in tasks) {
      _tasks[t.id] = t;
      batch?.insert(
        'tasks',
        t.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch?.commit(noResult: true);
    _reindex();
    notifyListeners();
    return plans.length + tasks.length;
  }

  /// The first free slot of [day] that starts at or after [after] minutes,
  /// one hour long by default. Used to prefill new blocks.
  (int, int) suggestSlot(String day, {int after = 9 * 60, int length = 60}) {
    var start = after;
    for (final b in blocksFor(day)) {
      if (b.endMin <= start) continue;
      if (b.startMin >= start + length) break;
      start = b.endMin;
    }
    start = start.clamp(0, 24 * 60 - 15);
    return (start, (start + length).clamp(start + 15, 24 * 60));
  }

  // --------------------------------------------------------------- tasks --

  /// All tasks: open first (by due date and priority), then done.
  List<Task> get tasks => _sortedTasks;

  Task? task(String id) => _tasks[id];

  int get openCount => _tasks.values.where((t) => !t.done).length;

  /// Open tasks due on [day], plus overdue ones when [day] is today.
  List<Task> tasksDue(String day) {
    final today = Dates.isToday(day);
    return [
      for (final t in _sortedTasks)
        if (t.dueDay != null &&
            (t.dueDay == day ||
                (today && !t.done && t.dueDay!.compareTo(day) < 0)))
          t,
    ];
  }

  Future<Task> addTask(
    String title, {
    String note = '',
    String? dueDay,
    TaskPriority priority = TaskPriority.none,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      note: note.trim(),
      dueDay: dueDay,
      priority: priority,
      createdAt: DateTime.now(),
    );
    await saveTask(task);
    return task;
  }

  /// Inserts or replaces [task] (also used to undo a delete).
  Future<void> saveTask(Task task) async {
    _tasks[task.id] = task;
    _changed();
    await _db?.insert(
      'tasks',
      task.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> toggleTask(String id) async {
    final t = _tasks[id];
    if (t != null) await saveTask(t.copyWith(done: !t.done));
  }

  Future<void> deleteTask(String id) async {
    if (_tasks.remove(id) == null) return;
    _changed();
    await _db?.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Removes every done task. Returns them so the action can be undone.
  Future<List<Task>> clearCompleted() async {
    final done = _tasks.values.where((t) => t.done).toList();
    if (done.isEmpty) return done;
    for (final t in done) {
      _tasks.remove(t.id);
    }
    _changed();
    await _db?.delete('tasks', where: 'done = 1');
    return done;
  }
}
