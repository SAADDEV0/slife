import 'package:flutter_test/flutter_test.dart';
import 'package:slife/data/planner_repository.dart';
import 'package:slife/services/reminders.dart';
import 'package:slife/services/settings_service.dart';

void main() {
  // Monday 19 October 2026, 08:30.
  final now = DateTime(2026, 10, 19, 8, 30);

  Future<SettingsService> settings({
    bool journal = false,
    bool blocks = false,
    bool tasks = false,
  }) async {
    final s = SettingsService.memory();
    await s.setJournalReminder(journal);
    await s.setBlockReminder(blocks);
    await s.setTaskReminder(tasks);
    return s;
  }

  test('nothing is planned while every reminder is off', () async {
    final planner = PlannerRepository.memory();
    await planner.addTask('Pay rent', dueDay: '2026-10-19');
    final out = planReminders(
      now: now,
      settings: await settings(),
      planner: planner,
      wroteOn: (_) => false,
    );
    expect(out, isEmpty);
  });

  test('journal reminder skips days already written', () async {
    final out = planReminders(
      now: now,
      settings: await settings(journal: true),
      planner: PlannerRepository.memory(),
      wroteOn: (day) => day == '2026-10-19',
      days: 3,
    );
    expect(out.map((r) => r.at), [
      DateTime(2026, 10, 20, 21),
      DateTime(2026, 10, 21, 21),
    ]);
    expect(out.first.payload, 'journal:2026-10-20');
  });

  test('block reminders come before the start, skip done and past', () async {
    final s = await settings(blocks: true);
    await s.setBlockReminderLead(15);
    final planner = PlannerRepository.memory();
    const day = '2026-10-19';
    final early = planner.newBlock(
      day: day,
      startMin: 8 * 60,
      endMin: 9 * 60,
      title: 'Gym',
    );
    final deep = planner.newBlock(
      day: day,
      startMin: 10 * 60,
      endMin: 12 * 60,
      title: 'Deep work',
      note: 'Chapter 3',
    );
    final done = planner.newBlock(
      day: day,
      startMin: 14 * 60,
      endMin: 15 * 60,
      title: 'Call',
    );
    await planner.saveBlock(early);
    await planner.saveBlock(deep);
    await planner.saveBlock(done.copyWith(done: true));

    final out = planReminders(
      now: now,
      settings: s,
      planner: planner,
      wroteOn: (_) => false,
      days: 1,
    );
    final r = out.single;
    expect(r.kind, ReminderKind.block);
    expect(r.at, DateTime(2026, 10, 19, 9, 45));
    expect(r.title, 'Deep work in 15 min');
    expect(r.body, '10:00–12:00 · Chapter 3');
    expect(r.payload, 'planner:$day');
  });

  test('task digest counts due and overdue open tasks', () async {
    final s = await settings(tasks: true);
    await s.setTaskReminderMin(9 * 60);
    final planner = PlannerRepository.memory();
    await planner.addTask('Pay rent', dueDay: '2026-10-18');
    await planner.addTask('Call mom', dueDay: '2026-10-19');
    await planner.addTask('Buy dates', dueDay: '2026-10-19');
    final finished = await planner.addTask('Old', dueDay: '2026-10-19');
    await planner.toggleTask(finished.id);
    await planner.addTask('Someday');

    final out = planReminders(
      now: now,
      settings: s,
      planner: planner,
      wroteOn: (_) => true,
      days: 1,
    );
    final r = out.single;
    expect(r.at, DateTime(2026, 10, 19, 9));
    expect(r.title, '3 tasks for today');
    // Overdue first; the two due today may tie on creation time.
    expect(r.body, startsWith('Pay rent, '));
    expect(r.body, endsWith(' and 1 more · 1 overdue'));
  });

  test('reminders are sorted and capped', () async {
    final planner = PlannerRepository.memory();
    for (var h = 10; h < 20; h++) {
      await planner.saveBlock(
        planner.newBlock(
          day: '2026-10-19',
          startMin: h * 60,
          endMin: h * 60 + 30,
          title: 'B$h',
        ),
      );
    }
    final out = planReminders(
      now: now,
      settings: await settings(journal: true, blocks: true),
      planner: planner,
      wroteOn: (_) => false,
      limit: 4,
    );
    expect(out.map((r) => r.title), [
      'B10 in 10 min',
      'B11 in 10 min',
      'B12 in 10 min',
      'B13 in 10 min',
    ]);
  });
}
