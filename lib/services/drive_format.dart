import 'dart:convert';

import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../models/mood.dart';
import '../utils/dates.dart';

/// The files SLife writes into every day folder in Google Drive:
///
/// ```
/// SLife/
///   2026-10-12/
///     journal.txt   ← human readable
///     entry.json    ← machine readable (used to restore)
///     images/  videos/  audios/
/// ```
class DriveFormat {
  DriveFormat._();

  static const jsonName = 'entry.json';
  static const textName = 'journal.txt';
  static const formatVersion = 1;

  static String entryJson(JournalEntry entry, List<MediaItem> media) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'SLife',
      'version': formatVersion,
      'day': entry.day,
      'title': entry.title,
      'body': entry.body,
      'mood': entry.mood?.name,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
      'media': [
        for (final m in media)
          {
            'id': m.id,
            'type': m.type.name,
            'file': m.relativePath,
            'durationMs': m.durationMs,
            'createdAt': m.createdAt.toUtc().toIso8601String(),
            'driveFileId': m.driveFileId,
          },
      ],
    });
  }

  static String journalText(JournalEntry entry, List<MediaItem> media) {
    final b = StringBuffer()
      ..writeln(
        'SLife · ${Dates.weekday(entry.date)}, ${Dates.long(entry.date)}',
      );
    final mood = entry.mood;
    if (mood != null) b.writeln('Mood: ${mood.emoji} ${mood.label}');
    b.writeln();
    if (entry.title.trim().isNotEmpty) {
      b
        ..writeln(entry.title.trim())
        ..writeln('=' * entry.title.trim().length.clamp(3, 60))
        ..writeln();
    }
    if (entry.body.trim().isNotEmpty) {
      b
        ..writeln(entry.body.trim())
        ..writeln();
    }
    if (media.isNotEmpty) {
      b.writeln('— Attachments —');
      for (final type in MediaType.values) {
        final ofType = media.where((m) => m.type == type).toList();
        if (ofType.isEmpty) continue;
        b.writeln('${type.label}s (${ofType.length})');
        for (final m in ofType) {
          final d = m.duration;
          b.writeln(
            '  • ${m.relativePath}${d == null ? '' : '  (${Dates.duration(d)})'}',
          );
        }
      }
      b.writeln();
    }
    b.writeln(
      'Last edited ${Dates.compact(entry.updatedAt)} at ${Dates.time(entry.updatedAt)}',
    );
    return b.toString();
  }

  static RestoredDay parseEntryJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final moodName = json['mood'] as String?;
    Mood? mood;
    for (final m in Mood.values) {
      if (m.name == moodName) mood = m;
    }
    final media = <RestoredMedia>[];
    for (final raw in (json['media'] as List<dynamic>? ?? const [])) {
      final m = raw as Map<String, dynamic>;
      final file = m['file'] as String? ?? '';
      media.add(
        RestoredMedia(
          id: m['id'] as String?,
          fileName: file.split('/').last,
          durationMs: (m['durationMs'] as num?)?.toInt(),
          createdAt: _date(m['createdAt']),
          driveFileId: m['driveFileId'] as String?,
        ),
      );
    }
    return RestoredDay(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      mood: mood,
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      media: media,
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

class RestoredDay {
  RestoredDay({
    required this.title,
    required this.body,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
    required this.media,
  });

  final String title;
  final String body;
  final Mood? mood;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RestoredMedia> media;

  RestoredMedia? find({required String driveFileId, required String fileName}) {
    for (final m in media) {
      if (m.driveFileId == driveFileId) return m;
    }
    for (final m in media) {
      if (m.fileName == fileName) return m;
    }
    return null;
  }
}

class RestoredMedia {
  RestoredMedia({
    required this.id,
    required this.fileName,
    required this.durationMs,
    required this.createdAt,
    required this.driveFileId,
  });

  final String? id;
  final String fileName;
  final int? durationMs;
  final DateTime? createdAt;
  final String? driveFileId;
}
