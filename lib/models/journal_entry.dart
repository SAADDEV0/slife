import '../utils/dates.dart';
import 'mood.dart';

/// One journal page. SLife keeps exactly one entry per calendar day, which
/// maps 1:1 to a day folder in Google Drive.
class JournalEntry {
  const JournalEntry({
    required this.day,
    this.title = '',
    this.body = '',
    this.mood,
    required this.createdAt,
    required this.updatedAt,
    this.rev = 0,
    this.dirty = true,
    this.driveFolderId,
    this.driveJsonId,
    this.driveTextId,
  });

  /// Day key, `yyyy-MM-dd`.
  final String day;
  final String title;
  final String body;
  final Mood? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Incremented on every local change; used to detect edits made while an
  /// upload was in flight.
  final int rev;

  /// True when the text/metadata still needs to be uploaded.
  final bool dirty;

  final String? driveFolderId;
  final String? driveJsonId;
  final String? driveTextId;

  DateTime get date => Dates.parse(day);

  bool get hasText => title.trim().isNotEmpty || body.trim().isNotEmpty;

  int get wordCount => countWords(body) + countWords(title);

  String get displayTitle =>
      title.trim().isEmpty ? 'Untitled day' : title.trim();

  String get snippet => body.trim().replaceAll(RegExp(r'\s+'), ' ');

  static int countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  factory JournalEntry.fromRow(Map<String, Object?> row) {
    return JournalEntry(
      day: row['day'] as String,
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      mood: Mood.fromIndex(row['mood'] as int?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      rev: (row['rev'] as int?) ?? 0,
      dirty: (row['dirty'] as int? ?? 1) == 1,
      driveFolderId: row['drive_folder_id'] as String?,
      driveJsonId: row['drive_json_id'] as String?,
      driveTextId: row['drive_text_id'] as String?,
    );
  }

  Map<String, Object?> toRow() => {
    'day': day,
    'title': title,
    'body': body,
    'mood': mood?.index,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'rev': rev,
    'dirty': dirty ? 1 : 0,
    'drive_folder_id': driveFolderId,
    'drive_json_id': driveJsonId,
    'drive_text_id': driveTextId,
  };
}
