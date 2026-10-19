enum MediaType {
  image('images', 'IMG', 'Photo'),
  video('videos', 'VID', 'Video'),
  audio('audios', 'AUD', 'Voice note');

  const MediaType(this.folder, this.prefix, this.label);

  /// Sub-folder name, both on the device and inside the Drive day folder.
  final String folder;
  final String prefix;
  final String label;

  static MediaType? fromFolder(String folder) {
    for (final t in values) {
      if (t.folder == folder) return t;
    }
    return null;
  }
}

/// A photo, video or voice note attached to a day.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.day,
    required this.type,
    required this.fileName,
    this.thumbName,
    this.durationMs,
    required this.createdAt,
    this.driveFileId,
  });

  final String id;
  final String day;
  final MediaType type;
  final String fileName;

  /// Thumbnail file name (videos only).
  final String? thumbName;
  final int? durationMs;
  final DateTime createdAt;
  final String? driveFileId;

  bool get isSynced => driveFileId != null;
  bool get isVisual => type != MediaType.audio;

  /// Path relative to the day folder, e.g. `images/IMG_20261012_101530_ab12.jpg`.
  String get relativePath => '${type.folder}/$fileName';

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  factory MediaItem.fromRow(Map<String, Object?> row) {
    return MediaItem(
      id: row['id'] as String,
      day: row['day'] as String,
      type: MediaType.values.byName(row['type'] as String),
      fileName: row['file_name'] as String,
      thumbName: row['thumb_name'] as String?,
      durationMs: row['duration_ms'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      driveFileId: row['drive_file_id'] as String?,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'day': day,
    'type': type.name,
    'file_name': fileName,
    'thumb_name': thumbName,
    'duration_ms': durationMs,
    'created_at': createdAt.millisecondsSinceEpoch,
    'drive_file_id': driveFileId,
  };
}
