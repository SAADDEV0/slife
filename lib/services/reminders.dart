import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../models/planner.dart';
import '../utils/dates.dart';
import '../utils/prompts.dart';
import 'prayer_times.dart';
import 'settings_service.dart';

enum ReminderKind { journal, block, tasks, prayer, adhkar }

/// A local notification SLife wants shown at [at].
@immutable
class Reminder {
  const Reminder({
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final ReminderKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// What a tap opens: `journal:`, `planner:` or `deen:` + `yyyy-MM-dd`.
  final String payload;

  @override
  String toString() => 'Reminder(${kind.name} @ $at: $title)';
}

/// Works out every reminder of the next [days] days from the current
/// settings, plans and tasks. Pure, so it is easy to test; the
/// [NotificationService] turns the result into scheduled notifications.
///
/// iOS keeps at most 64 pending notifications, so the soonest [limit] win.
List<Reminder> planReminders({
  required DateTime now,
  required SettingsService settings,
  required PlannerRepository planner,
  required bool Function(String day) wroteOn,
  int days = 7,
  int limit = 60,
}) {
  final out = <Reminder>[];
  final today = DateTime(now.year, now.month, now.day);

  for (var i = 0; i < days; i++) {
    final date = DateTime(today.year, today.month, today.day + i);
    final day = Dates.key(date);
    DateTime at(int minutes) =>
        DateTime(date.year, date.month, date.day, 0, minutes);

    if (settings.journalReminder && !wroteOn(day)) {
      final when = at(settings.journalReminderMin);
      if (when.isAfter(now)) {
        out.add(
          Reminder(
            kind: ReminderKind.journal,
            at: when,
            title: 'How was your day?',
            body: Prompts.forDay(date),
            payload: 'journal:$day',
          ),
        );
      }
    }

    if (settings.taskReminder) {
      final when = at(settings.taskReminderMin);
      final due = [
        for (final t in planner.tasks)
          if (!t.done && t.dueDay != null && t.dueDay!.compareTo(day) <= 0) t,
      ];
      if (due.isNotEmpty && when.isAfter(now)) {
        final overdue = due.where((t) => t.dueDay != day).length;
        out.add(
          Reminder(
            kind: ReminderKind.tasks,
            at: when,
            title: due.length == 1
                ? '1 task for today'
                : '${due.length} tasks for today',
            body: _taskSummary(due, overdue),
            payload: 'planner:$day',
          ),
        );
      }
    }

    if (settings.prayerReminder) {
      final prayers = DayPrayers.of(settings, date);
      final muted = settings.prayerMuted;
      for (final p in Salah.values) {
        if (prayers == null || !p.isPrayer || muted.contains(p.name)) continue;
        final when = prayers[p];
        if (!when.isAfter(now)) continue;
        final name = p.labelOn(date);
        out.add(
          Reminder(
            kind: ReminderKind.prayer,
            at: when,
            title: '$name · ${p.arabic}',
            body: 'It is time for $name (${Dates.time(when)})',
            payload: 'deen:$day',
          ),
        );
      }
    }

    for (final (on, minutes, title, body) in [
      (
        settings.morningAdhkar,
        settings.morningAdhkarMin,
        'Morning adhkar',
        'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ · Start your day with remembrance',
      ),
      (
        settings.eveningAdhkar,
        settings.eveningAdhkarMin,
        'Evening adhkar',
        'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ · End your day with remembrance',
      ),
    ]) {
      final when = at(minutes);
      if (!on || !when.isAfter(now)) continue;
      out.add(
        Reminder(
          kind: ReminderKind.adhkar,
          at: when,
          title: title,
          body: body,
          payload: 'deen:$day',
        ),
      );
    }

    if (settings.blockReminder) {
      final lead = settings.blockReminderLead;
      for (final b in planner.blocksFor(day)) {
        if (b.done) continue;
        final when = at(b.startMin - lead);
        if (!when.isAfter(now)) continue;
        final range =
            '${PlanBlock.clock(b.startMin)}–${PlanBlock.clock(b.endMin)}';
        out.add(
          Reminder(
            kind: ReminderKind.block,
            at: when,
            title: lead == 0
                ? '${b.title} is starting'
                : '${b.title} in $lead min',
            body: b.note.isEmpty ? range : '$range · ${b.note}',
            payload: 'planner:$day',
          ),
        );
      }
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// "Call mom, Pay rent and 2 more · 1 overdue"
String _taskSummary(List<Task> due, int overdue) {
  final names = due.take(2).map((t) => t.title).join(', ');
  final more = due.length > 2 ? ' and ${due.length - 2} more' : '';
  final late = overdue > 0 ? ' · $overdue overdue' : '';
  return '$names$more$late';
}
