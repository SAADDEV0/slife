import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../models/mood.dart';
import '../utils/dates.dart';
import 'media_storage.dart';

/// The local-first source of truth for the journal.
///
/// Everything is written to SQLite + the device file system first; the
/// [onLocalChange] hook tells the sync engine there is something new to
/// upload to Google Drive.
class JournalRepository extends ChangeNotifier {
  JournalRepository(Database db, this.storage) : _db = db;

  /// Read-only, in-memory repository used by tests and previews.
  @visibleForTesting
  JournalRepository.preview(
    this.storage, {
    List<JournalEntry> entries = const [],
    List<MediaItem> media = const [],
  }) : _db = null {
    _setAll(entries, media);
  }

  final Database? _db;
  final MediaStorage storage;
  static const _uuid = Uuid();

  final Map<String, JournalEntry> _entries = {};
  final Map<String, List<MediaItem>> _media = {};
  List<JournalEntry> _sorted = const [];
  List<MediaItem> _visual = const [];
  int _trashCount = 0;

  /// Called after every local change that should be backed up.
  VoidCallback? onLocalChange;

  Database get _database =>
      _db ?? (throw StateError('Preview repository is read-only'));

  // ---------------------------------------------------------------- reads --

  /// All journaled days, newest first.
  List<JournalEntry> get entries => _sorted;

  bool get isEmpty => _entries.isEmpty;

  JournalEntry? entryFor(String day) => _entries[day];

  List<MediaItem> mediaFor(String day) => _media[day] ?? const [];

  /// Every photo and video, newest day first.
  List<MediaItem> get visualMedia => _visual;

  int get mediaCount => _media.values.fold(0, (n, list) => n + list.length);

  /// Number of things waiting to be uploaded to (or removed from) Drive.
  int get pendingUploads {
    var n = _trashCount;
    for (final e in _entries.values) {
      if (e.dirty) n++;
    }
    for (final list in _media.values) {
      for (final m in list) {
        if (!m.isSynced) n++;
      }
    }
    return n;
  }

  /// Consecutive journaled days ending today (or yesterday).
  int get streak {
    var d = Dates.today();
    if (!_entries.containsKey(Dates.key(d))) d = Dates.previousDay(d);
    var n = 0;
    while (_entries.containsKey(Dates.key(d))) {
      n++;
      d = Dates.previousDay(d);
    }
    return n;
  }

  List<JournalEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _sorted
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.body.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> load() async {
    final db = _database;
    final entryRows = await db.query('entries');
    final mediaRows = await db.query('media', orderBy: 'created_at ASC');
    _trashCount = await _countTrash(db);
    _setAll(
      entryRows.map(JournalEntry.fromRow),
      mediaRows.map(MediaItem.fromRow),
    );
    notifyListeners();
  }

  void _setAll(Iterable<JournalEntry> entries, Iterable<MediaItem> media) {
    _entries
      ..clear()
      ..addEntries(entries.map((e) => MapEntry(e.day, e)));
    _media.clear();
    for (final m in media) {
      (_media[m.day] ??= []).add(m);
    }
    _rebuild();
  }

  void _rebuild() {
    _sorted = _entries.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    final visual = <MediaItem>[];
    for (final e in _sorted) {
      final list = _media[e.day];
      if (list == null) continue;
      visual.addAll(list.reversed.where((m) => m.isVisual));
    }
    _visual = visual;
  }

  Future<int> _countTrash(DatabaseExecutor db) async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM drive_trash'),
      ) ??
      0;

  Future<void> refreshDay(String day) async {
    final db = _database;
    final rows = await db.query('entries', where: 'day = ?', whereArgs: [day]);
    final media = await db.query(
      'media',
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'created_at ASC',
    );
    _trashCount = await _countTrash(db);
    if (rows.isEmpty) {
      _entries.remove(day);
    } else {
      _entries[day] = JournalEntry.fromRow(rows.first);
    }
    if (media.isEmpty) {
      _media.remove(day);
    } else {
      _media[day] = media.map(MediaItem.fromRow).toList();
    }
    _rebuild();
    notifyListeners();
  }

  void _changed() => onLocalChange?.call();

  // ------------------------------------------------------- user changes --

  /// Saves the text and mood for [day]. Empty days are not created.
  Future<void> saveEntry(
    String day, {
    required String title,
    required String body,
    required Mood? mood,
  }) async {
    final existing = _entries[day];
    if (existing == null) {
      if (title.trim().isEmpty && body.trim().isEmpty && mood == null) return;
    } else if (existing.title == title &&
        existing.body == body &&
        existing.mood == mood) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = _database;
    final updated = await db.rawUpdate(
      'UPDATE entries SET title = ?, body = ?, mood = ?, updated_at = ?, '
      'rev = rev + 1, dirty = 1 WHERE day = ?',
      [title, body, mood?.index, now, day],
    );
    if (updated == 0) {
      await db.insert('entries', {
        'day': day,
        'title': title,
        'body': body,
        'mood': mood?.index,
        'created_at': now,
        'updated_at': now,
        'rev': 1,
        'dirty': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await refreshDay(day);
    _changed();
  }

  /// Copies a picked photo/video into the journal.
  Future<MediaItem> addMediaFile(
    String day,
    MediaType type,
    String sourcePath, {
    int? durationMs,
    bool move = false,
  }) async {
    final fileName = await storage.importFile(
      day,
      type,
      sourcePath,
      move: move,
    );
    return _registerMedia(day, type, fileName, durationMs: durationMs);
  }

  /// Registers a voice note that was recorded straight into the day folder.
  Future<MediaItem> addRecording(String day, String path, Duration duration) {
    return _registerMedia(
      day,
      MediaType.audio,
      p.basename(path),
      durationMs: duration.inMilliseconds,
    );
  }

  Future<MediaItem> _registerMedia(
    String day,
    MediaType type,
    String fileName, {
    int? durationMs,
  }) async {
    final thumb = type == MediaType.video
        ? await storage.createVideoThumb(day, fileName)
        : null;
    final item = MediaItem(
      id: _uuid.v4(),
      day: day,
      type: type,
      fileName: fileName,
      thumbName: thumb,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    await _database.transaction((txn) async {
      await _ensureEntry(txn, day);
      await txn.insert('media', item.toRow());
      await _touch(txn, day);
    });
    await refreshDay(day);
    _changed();
    return item;
  }

  Future<void> deleteMedia(MediaItem item) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'media',
        columns: ['drive_file_id'],
        where: 'id = ?',
        whereArgs: [item.id],
      );
      final driveId = rows.isEmpty
          ? null
          : rows.first['drive_file_id'] as String?;
      if (driveId != null) await _queueTrash(txn, driveId);
      await txn.delete('media', where: 'id = ?', whereArgs: [item.id]);
      await _touch(txn, item.day);
    });
    await storage.deleteMediaFiles(item);
    await refreshDay(item.day);
    _changed();
  }

  /// Deletes a whole day locally; its Drive folder is moved to the Drive trash.
  Future<void> deleteEntry(String day) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'entries',
        columns: ['drive_folder_id'],
        where: 'day = ?',
        whereArgs: [day],
      );
      final folderId = rows.isEmpty
          ? null
          : rows.first['drive_folder_id'] as String?;
      if (folderId != null) {
        await _queueTrash(txn, folderId);
      } else {
        final media = await txn.query(
          'media',
          columns: ['drive_file_id'],
          where: 'day = ? AND drive_file_id IS NOT NULL',
          whereArgs: [day],
        );
        for (final m in media) {
          await _queueTrash(txn, m['drive_file_id'] as String);
        }
      }
      await txn.delete('media', where: 'day = ?', whereArgs: [day]);
      await txn.delete('entries', where: 'day = ?', whereArgs: [day]);
    });
    await storage.deleteDay(day);
    await refreshDay(day);
    _changed();
  }

  /// Removes a day that ended up with no words, mood or media.
  Future<void> deleteIfEmpty(String day) async {
    final e = _entries[day];
    if (e == null || e.hasText || e.mood != null || mediaFor(day).isNotEmpty) {
      return;
    }
    await deleteEntry(day);
  }

  Future<void> _ensureEntry(DatabaseExecutor txn, String day) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await txn.insert('entries', {
      'day': day,
      'title': '',
      'body': '',
      'created_at': now,
      'updated_at': now,
      'rev': 1,
      'dirty': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _touch(DatabaseExecutor txn, String day) {
    return txn.rawUpdate(
      'UPDATE entries SET rev = rev + 1, dirty = 1, updated_at = ? WHERE day = ?',
      [DateTime.now().millisecondsSinceEpoch, day],
    );
  }

  Future<void> _queueTrash(DatabaseExecutor txn, String driveId) {
    return txn.insert('drive_trash', {
      'drive_id': driveId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ------------------------------------------------------ sync helpers --

  Future<List<String>> trashQueue() async {
    final rows = await _database.query('drive_trash');
    return rows.map((r) => r['drive_id'] as String).toList();
  }

  Future<void> removeFromTrashQueue(String driveId) async {
    await _database.delete(
      'drive_trash',
      where: 'drive_id = ?',
      whereArgs: [driveId],
    );
    _trashCount = await _countTrash(_database);
    notifyListeners();
  }

  /// Days whose text changed or that have media not yet uploaded.
  Future<List<String>> daysNeedingSync() async {
    final rows = await _database.rawQuery(
      'SELECT day FROM entries WHERE dirty = 1 '
      'UNION SELECT day FROM media WHERE drive_file_id IS NULL',
    );
    return rows.map((r) => r['day'] as String).toList()..sort();
  }

  Future<JournalEntry?> readEntry(String day) async {
    final rows = await _database.query(
      'entries',
      where: 'day = ?',
      whereArgs: [day],
    );
    return rows.isEmpty ? null : JournalEntry.fromRow(rows.first);
  }

  Future<List<MediaItem>> readMedia(String day) async {
    final rows = await _database.query(
      'media',
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'created_at ASC',
    );
    return rows.map(MediaItem.fromRow).toList();
  }

  /// Returns false if the day was deleted in the meantime.
  Future<bool> setDriveFolder(String day, String folderId) async {
    final n = await _database.rawUpdate(
      'UPDATE entries SET drive_folder_id = ? WHERE day = ?',
      [folderId, day],
    );
    return n > 0;
  }

  /// Forgets every Drive id of a day so it is uploaded again from scratch
  /// (used when its Drive folder was deleted by hand).
  Future<void> forgetDriveIds(String day) async {
    await _database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE entries SET drive_folder_id = NULL, drive_json_id = NULL, '
        'drive_text_id = NULL, dirty = 1 WHERE day = ?',
        [day],
      );
      await txn.rawUpdate(
        'UPDATE media SET drive_file_id = NULL WHERE day = ?',
        [day],
      );
    });
  }

  /// Marks the whole journal for re-upload (used when the `SLife` folder
  /// itself disappeared from Drive).
  Future<void> forgetAllDriveIds() async {
    await _database.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE entries SET drive_folder_id = NULL, drive_json_id = NULL, '
        'drive_text_id = NULL, dirty = 1',
      );
      await txn.rawUpdate('UPDATE media SET drive_file_id = NULL');
      await txn.delete('drive_trash');
    });
    await load();
  }

  /// Returns false if the media item was deleted in the meantime.
  Future<bool> setMediaDriveId(MediaItem item, String driveId) async {
    final n = await _database.rawUpdate(
      'UPDATE media SET drive_file_id = ? WHERE id = ?',
      [driveId, item.id],
    );
    if (n > 0) {
      // The day's entry.json lists media ids, so it needs a refresh too.
      await _database.rawUpdate('UPDATE entries SET dirty = 1 WHERE day = ?', [
        item.day,
      ]);
    }
    return n > 0;
  }

  /// Stores the uploaded text file ids. The day stays dirty if it was edited
  /// after [rev] was read.
  Future<void> markTextSynced(
    String day, {
    required int rev,
    required String jsonId,
    required String textId,
  }) async {
    await _database.rawUpdate(
      'UPDATE entries SET drive_json_id = ?, drive_text_id = ?, '
      'dirty = CASE WHEN rev = ? THEN 0 ELSE 1 END WHERE day = ?',
      [jsonId, textId, rev, day],
    );
  }

  // ----------------------------------------------------------- restore --

  Future<bool> hasEntry(String day) async => (await readEntry(day)) != null;

  Future<void> importEntry(JournalEntry entry) async {
    await _database.insert(
      'entries',
      entry.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> importMedia(MediaItem item) async {
    await _database.insert(
      'media',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
