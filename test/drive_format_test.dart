import 'package:flutter_test/flutter_test.dart';
import 'package:slife/models/journal_entry.dart';
import 'package:slife/models/media_item.dart';
import 'package:slife/models/mood.dart';
import 'package:slife/services/drive_format.dart';

void main() {
  final entry = JournalEntry(
    day: '2026-10-12',
    title: 'Sunset at the beach',
    body: 'We walked until the sky turned orange. 🌅\nBest day in weeks.',
    mood: Mood.amazing,
    createdAt: DateTime(2026, 10, 12, 9, 30),
    updatedAt: DateTime(2026, 10, 12, 22, 14),
  );
  final media = [
    MediaItem(
      id: 'm1',
      day: '2026-10-12',
      type: MediaType.image,
      fileName: 'IMG_20261012_181500_ab12.jpg',
      createdAt: DateTime(2026, 10, 12, 18, 15),
      driveFileId: 'drive-img',
    ),
    MediaItem(
      id: 'm2',
      day: '2026-10-12',
      type: MediaType.audio,
      fileName: 'AUD_20261012_190000_cd34.m4a',
      durationMs: 42000,
      createdAt: DateTime(2026, 10, 12, 19),
    ),
  ];

  test('entry.json round-trips text, mood and media metadata', () {
    final restored = DriveFormat.parseEntryJson(
      DriveFormat.entryJson(entry, media),
    );

    expect(restored.title, entry.title);
    expect(restored.body, entry.body);
    expect(restored.mood, Mood.amazing);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.updatedAt, entry.updatedAt);
    expect(restored.media, hasLength(2));

    final audio = restored.find(
      driveFileId: 'unknown',
      fileName: 'AUD_20261012_190000_cd34.m4a',
    );
    expect(audio?.id, 'm2');
    expect(audio?.durationMs, 42000);

    final image = restored.find(
      driveFileId: 'drive-img',
      fileName: 'renamed.jpg',
    );
    expect(image?.id, 'm1');
  });

  test('journal.txt is human readable and lists attachments by folder', () {
    final text = DriveFormat.journalText(entry, media);

    expect(text, contains('Monday, 12 October 2026'));
    expect(text, contains('Mood: 🤩 Amazing'));
    expect(text, contains('Sunset at the beach'));
    expect(text, contains('We walked until the sky turned orange.'));
    expect(text, contains('images/IMG_20261012_181500_ab12.jpg'));
    expect(text, contains('audios/AUD_20261012_190000_cd34.m4a  (0:42)'));
  });

  test('parsing tolerates missing optional fields', () {
    final restored = DriveFormat.parseEntryJson('{"body": "Just words"}');
    expect(restored.title, '');
    expect(restored.body, 'Just words');
    expect(restored.mood, isNull);
    expect(restored.media, isEmpty);
  });
}
