import 'package:flutter/material.dart';

/// Colors a planner block can take, indexed by [PlanBlock.color].
const planColors = <Color>[
  Color(0xFF6D5DF6), // violet
  Color(0xFF2F9BFF), // sky
  Color(0xFF1FB57A), // green
  Color(0xFFFFA62B), // amber
  Color(0xFFFF6B6B), // coral
  Color(0xFFB45EDB), // orchid
];

/// A time block in the day planner, e.g. "Deep work 09:00–11:00".
@immutable
class PlanBlock {
  const PlanBlock({
    required this.id,
    required this.day,
    required this.startMin,
    required this.endMin,
    required this.title,
    this.note = '',
    this.color = 0,
    this.done = false,
    required this.createdAt,
  });

  final String id;

  /// `yyyy-MM-dd`.
  final String day;

  /// Minutes since midnight.
  final int startMin;
  final int endMin;
  final String title;
  final String note;
  final int color;
  final bool done;
  final DateTime createdAt;

  int get minutes => endMin - startMin;

  Color get swatch => planColors[color % planColors.length];

  TimeOfDay get start => TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60);
  TimeOfDay get end => TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);

  PlanBlock copyWith({
    String? day,
    int? startMin,
    int? endMin,
    String? title,
    String? note,
    int? color,
    bool? done,
  }) {
    return PlanBlock(
      id: id,
      day: day ?? this.day,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      title: title ?? this.title,
      note: note ?? this.note,
      color: color ?? this.color,
      done: done ?? this.done,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'day': day,
    'start_min': startMin,
    'end_min': endMin,
    'title': title,
    'note': note,
    'color': color,
    'done': done ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory PlanBlock.fromRow(Map<String, Object?> r) => PlanBlock(
    id: r['id'] as String,
    day: r['day'] as String,
    startMin: r['start_min'] as int,
    endMin: r['end_min'] as int,
    title: r['title'] as String,
    note: r['note'] as String? ?? '',
    color: r['color'] as int? ?? 0,
    done: (r['done'] as int? ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );

  /// 09:30
  static String clock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 1 h 30 min
  static String length(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }
}

enum TaskPriority {
  none('No priority'),
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.label);
  final String label;
}

/// A to-do in the task manager.
@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    this.note = '',
    this.dueDay,
    this.priority = TaskPriority.none,
    this.done = false,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String note;

  /// `yyyy-MM-dd`, or null when the task has no date.
  final String? dueDay;
  final TaskPriority priority;
  final bool done;
  final DateTime createdAt;
  final DateTime? completedAt;

  Task copyWith({
    String? title,
    String? note,
    String? dueDay,
    bool clearDue = false,
    TaskPriority? priority,
    bool? done,
  }) {
    final isDone = done ?? this.done;
    return Task(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueDay: clearDue ? null : (dueDay ?? this.dueDay),
      priority: priority ?? this.priority,
      done: isDone,
      createdAt: createdAt,
      completedAt: isDone ? (completedAt ?? DateTime.now()) : null,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'title': title,
    'note': note,
    'due_day': dueDay,
    'priority': priority.index,
    'done': done ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
    'completed_at': completedAt?.millisecondsSinceEpoch,
  };

  factory Task.fromRow(Map<String, Object?> r) {
    final completed = r['completed_at'] as int?;
    return Task(
      id: r['id'] as String,
      title: r['title'] as String,
      note: r['note'] as String? ?? '',
      dueDay: r['due_day'] as String?,
      priority: TaskPriority.values[(r['priority'] as int? ?? 0).clamp(0, 3)],
      done: (r['done'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      completedAt: completed == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completed),
    );
  }
}
