import 'package:flutter_test/flutter_test.dart';
import 'package:slife/data/planner_repository.dart';
import 'package:slife/services/prayer_times.dart';
import 'package:slife/services/reminders.dart';
import 'package:slife/services/settings_service.dart';

void main() {
  // Rabat, Morocco.
  Future<SettingsService> rabat() async {
    final s = SettingsService.memory();
    await s.setPrayerLocation(34.0209, -6.8416, 'Rabat, Morocco');
    await s.setPrayerMethod(PrayerMethod.morocco.name);
    return s;
  }

  final day = DateTime(2026, 10, 19);

  test('no location means no prayer times', () {
    expect(DayPrayers.of(SettingsService.memory(), day), isNull);
    expect(DayPrayers.next(SettingsService.memory(), day), isNull);
  });

  test('times are in order and Dhuhr is near solar noon', () async {
    final t = DayPrayers.of(await rabat(), day)!;
    final order = Salah.values.map((p) => t[p]).toList();
    for (var i = 1; i < order.length; i++) {
      expect(order[i].isAfter(order[i - 1]), isTrue, reason: '$i');
    }
    // Solar noon at 6.84° W in mid October is about 12:12 UTC.
    final dhuhr = t[Salah.dhuhr].toUtc();
    expect(
      dhuhr.hour * 60 + dhuhr.minute,
      inInclusiveRange(12 * 60 + 5, 12 * 60 + 25),
    );
    // Fajr about 1 h 25 min before sunrise at 19°.
    final gap = t[Salah.sunrise].difference(t[Salah.fajr]).inMinutes;
    expect(gap, inInclusiveRange(75, 95));
  });

  test('Hanafi Asr is later than the standard one', () async {
    final s = await rabat();
    final standard = DayPrayers.of(s, day)![Salah.asr];
    await s.setPrayerHanafi(true);
    final hanafi = DayPrayers.of(s, day)![Salah.asr];
    expect(hanafi.difference(standard).inMinutes, greaterThan(20));
  });

  test('next prayer skips sunrise and rolls over to tomorrow', () async {
    final s = await rabat();
    final t = DayPrayers.of(s, day)!;
    final afterFajr = t[Salah.fajr].add(const Duration(minutes: 1));
    expect(DayPrayers.next(s, afterFajr)!.$1, Salah.dhuhr);
    final (p, at) = DayPrayers.next(s, t[Salah.isha])!;
    expect(p, Salah.fajr);
    expect(at.day, 20);
  });

  test('country codes pick the local method', () {
    expect(PrayerMethod.forCountry('ma'), PrayerMethod.morocco);
    expect(PrayerMethod.forCountry('FR'), PrayerMethod.france);
    expect(PrayerMethod.forCountry(null), PrayerMethod.muslimWorldLeague);
  });

  test(
    'prayer reminders skip muted prayers and Friday Dhuhr is Jumuah',
    () async {
      final s = await rabat();
      await s.setPrayerReminder(true);
      await s.setPrayerMuted({'fajr', 'isha'});
      final friday = DateTime(2026, 10, 23);
      final out = planReminders(
        now: friday,
        settings: s,
        planner: PlannerRepository.memory(),
        wroteOn: (_) => true,
        days: 1,
      );
      expect(out.map((r) => r.title), [
        'Jumuʿah · الظهر',
        'Asr · العصر',
        'Maghrib · المغرب',
      ]);
      expect(out.first.payload, 'deen:2026-10-23');
    },
  );

  test('adhkar reminders use their own times', () async {
    final s = SettingsService.memory();
    await s.setMorningAdhkar(true);
    await s.setEveningAdhkar(true);
    await s.setEveningAdhkarMin(18 * 60);
    final out = planReminders(
      now: DateTime(2026, 10, 19, 12),
      settings: s,
      planner: PlannerRepository.memory(),
      wroteOn: (_) => true,
      days: 2,
    );
    expect(out.map((r) => (r.title, r.at)), [
      ('Evening adhkar', DateTime(2026, 10, 19, 18)),
      ('Morning adhkar', DateTime(2026, 10, 20, 7)),
      ('Evening adhkar', DateTime(2026, 10, 20, 18)),
    ]);
  });
}
