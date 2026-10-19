import 'package:flutter_test/flutter_test.dart';
import 'package:slife/data/planner_repository.dart';
import 'package:slife/data/quran_repository.dart';
import 'package:slife/data/tasbih_repository.dart';
import 'package:slife/models/dhikr.dart';
import 'package:slife/models/planner.dart';
import 'package:slife/models/surah.dart';
import 'package:slife/services/life_backup.dart';
import 'package:slife/services/settings_service.dart';
import 'package:slife/utils/dates.dart';

void main() {
  group('PlannerRepository', () {
    test('suggestSlot skips over existing blocks', () async {
      final repo = PlannerRepository.memory();
      const day = '2026-10-19';
      await repo.saveBlock(
        repo.newBlock(day: day, startMin: 540, endMin: 600, title: 'A'),
      );
      await repo.saveBlock(
        repo.newBlock(day: day, startMin: 600, endMin: 690, title: 'B'),
      );
      expect(repo.suggestSlot(day, after: 540), (690, 750));
      expect(repo.suggestSlot(day, after: 480), (480, 540));
      expect(repo.blocksFor(day).map((b) => b.title), ['A', 'B']);
    });

    test('copyDay duplicates blocks unchecked', () async {
      final repo = PlannerRepository.memory();
      final b = repo.newBlock(
        day: '2026-10-18',
        startMin: 60,
        endMin: 120,
        title: 'Fajr',
      );
      await repo.saveBlock(b.copyWith(done: true));
      expect(await repo.copyDay('2026-10-18', '2026-10-19'), 1);
      final copy = repo.blocksFor('2026-10-19').single;
      expect(copy.title, 'Fajr');
      expect(copy.done, isFalse);
      expect(copy.id, isNot(b.id));
    });

    test('tasks: open before done, due date then priority', () async {
      final repo = PlannerRepository.memory();
      final today = Dates.todayKey();
      final yesterday = Dates.key(Dates.previousDay(Dates.today()));
      await repo.addTask('undated');
      await repo.addTask(
        'low today',
        dueDay: today,
        priority: TaskPriority.low,
      );
      await repo.addTask(
        'high today',
        dueDay: today,
        priority: TaskPriority.high,
      );
      await repo.addTask('overdue', dueDay: yesterday);
      final done = await repo.addTask('done', dueDay: today);
      await repo.toggleTask(done.id);

      expect(repo.tasks.map((t) => t.title), [
        'overdue',
        'high today',
        'low today',
        'undated',
        'done',
      ]);
      expect(repo.openCount, 4);
      // Today's list includes overdue tasks and today's done ones.
      expect(repo.tasksDue(today).map((t) => t.title), [
        'overdue',
        'high today',
        'low today',
        'done',
      ]);
      final cleared = await repo.clearCompleted();
      expect(cleared.single.title, 'done');
      expect(repo.tasks.length, 4);
    });
  });

  group('TasbihRepository', () {
    test('counts, completes rounds and logs today', () {
      final repo = TasbihRepository.memory();
      repo.setTarget(3);
      expect(repo.increment(), TasbihTap.counted);
      expect(repo.increment(), TasbihTap.counted);
      expect(repo.increment(), TasbihTap.roundComplete);
      expect(repo.count, 0);
      expect(repo.rounds, 1);
      repo.increment();
      repo.decrement();
      expect(repo.todayTotal, 3);
    });

    test('after-prayer sequence moves through 33/33/34', () {
      final repo = TasbihRepository.memory()..setSequence(true);
      final seen = <TasbihTap>[];
      for (var i = 0; i < 100; i++) {
        final r = repo.increment();
        if (r != TasbihTap.counted) seen.add(r);
      }
      expect(seen, [
        TasbihTap.nextInSequence,
        TasbihTap.nextInSequence,
        TasbihTap.sequenceComplete,
      ]);
      expect(repo.current.id, Dhikr.sequenceIds.first);
      expect(repo.todayTotal, 100);
      expect(repo.countOn(Dates.todayKey(), 'allahuakbar'), 34);
    });
  });

  test('life backup round-trips and merges without overwriting', () async {
    final settings = SettingsService.memory();
    final source = LifeBackup(
      planner: PlannerRepository.memory(),
      tasbih: TasbihRepository.memory(),
      quran: QuranRepository.memory(),
      settings: settings,
    );
    await source.planner.addTask('From backup');
    source.tasbih.increment();
    source.tasbih.increment();
    await source.quran.toggleBookmark(2, 255);
    await source.quran.setLastRead(18, 10);
    expect(source.dirty, isTrue);

    final local = TasbihRepository.memory();
    for (var i = 0; i < 5; i++) {
      local.increment();
    }
    final target = LifeBackup(
      planner: PlannerRepository.memory(),
      tasbih: local,
      quran: QuranRepository.memory(lastRead: (1, 1)),
      settings: SettingsService.memory(),
    );
    expect(await target.merge(source.encode()), isTrue);
    expect(target.planner.tasks.single.title, 'From backup');
    expect(target.tasbih.todayTotal, 5); // the higher count wins
    expect(target.quran.isBookmarked(2, 255), isTrue);
    expect(target.quran.lastRead, (1, 1)); // local spot kept
    expect(await target.merge('not json'), isFalse);
  });

  test('surah list is complete', () {
    expect(Surah.all.length, 114);
    for (var i = 0; i < Surah.all.length; i++) {
      expect(Surah.all[i].number, i + 1);
    }
    expect(Surah.all.fold<int>(0, (n, s) => n + s.ayahs), 6236);
  });
}
