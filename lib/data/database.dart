import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite schema for SLife.
///
/// * `entries`         – one row per journaled day (text, mood, Drive ids)
/// * `media`           – photos, videos and voice notes attached to a day
/// * `drive_trash`     – Drive files/folders to move to the Drive trash on
///                       the next sync (things deleted in the app)
/// * `plans`           – time blocks of the day planner
/// * `tasks`           – the task manager's to-dos
/// * `dhikr`           – tasbih phrases added by the user
/// * `tasbih_log`      – tasbih count per day and phrase
/// * `quran_bookmarks` – bookmarked ayahs
/// * `kv`              – small bits of state (tasbih session, last read ayah)
class AppDatabase {
  AppDatabase._();

  static const _version = 2;

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'slife.db'),
      version: _version,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE entries(
            day TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            mood INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            rev INTEGER NOT NULL DEFAULT 0,
            dirty INTEGER NOT NULL DEFAULT 1,
            drive_folder_id TEXT,
            drive_json_id TEXT,
            drive_text_id TEXT
          )''');
        batch.execute('''
          CREATE TABLE media(
            id TEXT PRIMARY KEY,
            day TEXT NOT NULL,
            type TEXT NOT NULL,
            file_name TEXT NOT NULL,
            thumb_name TEXT,
            duration_ms INTEGER,
            created_at INTEGER NOT NULL,
            drive_file_id TEXT
          )''');
        batch.execute('CREATE INDEX idx_media_day ON media(day)');
        batch.execute('CREATE TABLE drive_trash(drive_id TEXT PRIMARY KEY)');
        _createV2(batch);
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, from, to) async {
        final batch = db.batch();
        if (from < 2) _createV2(batch);
        await batch.commit(noResult: true);
      },
    );
  }

  /// Planner, tasks, tasbih and Quran (added in version 2).
  static void _createV2(Batch batch) {
    batch.execute('''
      CREATE TABLE plans(
        id TEXT PRIMARY KEY,
        day TEXT NOT NULL,
        start_min INTEGER NOT NULL,
        end_min INTEGER NOT NULL,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        color INTEGER NOT NULL DEFAULT 0,
        done INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('CREATE INDEX idx_plans_day ON plans(day)');
    batch.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        due_day TEXT,
        priority INTEGER NOT NULL DEFAULT 0,
        done INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      )''');
    batch.execute('''
      CREATE TABLE dhikr(
        id TEXT PRIMARY KEY,
        arabic TEXT NOT NULL DEFAULT '',
        latin TEXT NOT NULL,
        meaning TEXT NOT NULL DEFAULT '',
        target INTEGER NOT NULL DEFAULT 33,
        created_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE tasbih_log(
        day TEXT NOT NULL,
        dhikr TEXT NOT NULL,
        count INTEGER NOT NULL,
        PRIMARY KEY(day, dhikr)
      )''');
    batch.execute('''
      CREATE TABLE quran_bookmarks(
        surah INTEGER NOT NULL,
        ayah INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(surah, ayah)
      )''');
    batch.execute('CREATE TABLE kv(key TEXT PRIMARY KEY, value TEXT)');
  }
}
