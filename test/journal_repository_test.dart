import 'package:flutter_test/flutter_test.dart';
import 'package:slife/data/journal_repository.dart';
import 'package:slife/data/media_storage.dart';
import 'package:slife/models/journal_entry.dart';
import 'package:slife/models/media_item.dart';
import 'package:slife/utils/dates.dart';

JournalEntry _entry(
  DateTime day, {
  String title = '',
  String body = '',
  bool dirty = false,
}) {
  return JournalEntry(
    day: Dates.key(day),
    title: title,
    body: body,
    createdAt: day,
    updatedAt: day,
    dirty: dirty,
  );
}

MediaItem _media(
  String id,
  DateTime day,
  MediaType type, {
  int minute = 0,
  bool synced = true,
}) {
  return MediaItem(
    id: id,
    day: Dates.key(day),
    type: type,
    fileName: '$id.bin',
    createdAt: day.add(Duration(minutes: minute)),
    driveFileId: synced ? 'drive-$id' : null,
  );
}

void main() {
  final storage = MediaStorage('/tmp/slife-test');
  final today = Dates.today();
  final yesterday = Dates.previousDay(today);
  final twoDaysAgo = Dates.previousDay(yesterday);
  final lastWeek = DateTime(today.year, today.month, today.day - 7);

  test('streak counts consecutive days ending today', () {
    final repo = JournalRepository.preview(
      storage,
      entries: [
        _entry(today),
        _entry(yesterday),
        _entry(twoDaysAgo),
        _entry(lastWeek),
      ],
    );
    expect(repo.streak, 3);
  });

  test('streak still counts when today is not written yet', () {
    final repo = JournalRepository.preview(
      storage,
      entries: [_entry(yesterday), _entry(twoDaysAgo)],
    );
    expect(repo.streak, 2);
  });

  test(
    'entries are sorted newest first and album holds only photos and videos',
    () {
      final repo = JournalRepository.preview(
        storage,
        entries: [_entry(lastWeek), _entry(today)],
        media: [
          _media('old-photo', lastWeek, MediaType.image),
          _media('voice', today, MediaType.audio),
          _media('first', today, MediaType.image, minute: 1),
          _media('second', today, MediaType.video, minute: 2),
        ],
      );
      expect(repo.entries.map((e) => e.day), [
        Dates.key(today),
        Dates.key(lastWeek),
      ]);
      expect(repo.visualMedia.map((m) => m.id), [
        'second',
        'first',
        'old-photo',
      ]);
      expect(repo.mediaCount, 4);
    },
  );

  test('pending uploads count dirty days and unsynced media', () {
    final repo = JournalRepository.preview(
      storage,
      entries: [_entry(today, dirty: true), _entry(yesterday)],
      media: [
        _media('a', today, MediaType.image, synced: false),
        _media('b', yesterday, MediaType.image),
      ],
    );
    expect(repo.pendingUploads, 2);
  });

  test('search matches title and body, case-insensitively', () {
    final repo = JournalRepository.preview(
      storage,
      entries: [
        _entry(today, title: 'Beach day', body: 'Swimming with Sara'),
        _entry(yesterday, title: 'Work', body: 'Long meeting'),
      ],
    );
    expect(repo.search('sara').map((e) => e.title), ['Beach day']);
    expect(repo.search('WORK').map((e) => e.title), ['Work']);
    expect(repo.search('   '), isEmpty);
  });

  test('file names are unique, typed and sortable', () {
    final at = DateTime(2026, 10, 12, 10, 15, 30);
    final a = storage.newFileName(MediaType.image, '.JPG', at);
    final b = storage.newFileName(MediaType.image, '.JPG', at);
    expect(a, startsWith('IMG_20261012_101530_'));
    expect(a, endsWith('.jpg'));
    expect(a, isNot(b));
    expect(storage.newFileName(MediaType.audio, ''), endsWith('.m4a'));
  });
}
