import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/surah.dart';

/// A translation shown under each ayah.
enum QuranTranslation {
  english('en.sahih', 'English', 'Saheeh International'),
  french('fr.hamidullah', 'Français', 'Muhammad Hamidullah'),
  none('', 'Arabic only', 'No translation');

  const QuranTranslation(this.edition, this.label, this.author);

  /// alquran.cloud edition id.
  final String edition;
  final String label;
  final String author;
}

@immutable
class QuranBookmark {
  const QuranBookmark(this.surah, this.ayah, this.createdAt);

  final int surah;
  final int ayah;
  final DateTime createdAt;
}

/// Quran text, bookmarks and reading position.
///
/// The surah list is bundled; the text of each surah is downloaded once from
/// api.alquran.cloud and kept on the device, so it opens offline afterwards.
class QuranRepository extends ChangeNotifier {
  QuranRepository(Database db, this.cacheDir, {http.Client? client})
    : _db = db,
      _client = client ?? http.Client();

  /// In-memory repository for tests and previews (no network, no disk).
  @visibleForTesting
  QuranRepository.memory({
    Map<int, List<Ayah>> surahs = const {},
    (int, int)? lastRead,
  }) : _db = null,
       _client = null,
       cacheDir = null {
    _loaded.addAll(surahs);
    _lastRead = lastRead;
  }

  final Database? _db;
  final http.Client? _client;
  final String? cacheDir;

  static const _api = 'https://api.alquran.cloud/v1';
  static const _lastKey = 'quran.last';
  static const _prefsKey = 'quran.prefs';

  final Map<int, List<Ayah>> _loaded = {};
  final Set<int> _cached = {};
  final Map<(int, int), QuranBookmark> _bookmarks = {};
  (int, int)? _lastRead;
  QuranTranslation _translation = QuranTranslation.english;
  double _fontScale = 1;

  final Map<int, Future<List<Ayah>>> _inFlight = {};

  /// Called after every change worth backing up (bookmarks, reading spot).
  VoidCallback? onLocalChange;

  int? _downloading;
  int _downloadDone = 0;
  bool _cancelDownload = false;

  Future<void> load() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.query('quran_bookmarks');
    _bookmarks
      ..clear()
      ..addEntries(
        rows.map((r) {
          final b = QuranBookmark(
            r['surah'] as int,
            r['ayah'] as int,
            DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
          );
          return MapEntry((b.surah, b.ayah), b);
        }),
      );
    final last = await _kv(_lastKey);
    if (last != null) {
      final parts = last.split(':');
      if (parts.length == 2) {
        _lastRead = (int.parse(parts[0]), int.parse(parts[1]));
      }
    }
    final prefs = await _kv(_prefsKey);
    if (prefs != null) {
      try {
        final m = jsonDecode(prefs) as Map;
        _translation = QuranTranslation.values.firstWhere(
          (t) => t.name == m['translation'],
          orElse: () => QuranTranslation.english,
        );
        _fontScale = (m['fontScale'] as num?)?.toDouble() ?? 1;
      } catch (_) {}
    }
    await _scanCache();
    notifyListeners();
  }

  Future<String?> _kv(String key) async {
    final rows = await _db!.query('kv', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _setKv(String key, String value) async {
    await _db?.insert('kv', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------ settings --

  QuranTranslation get translation => _translation;
  double get fontScale => _fontScale;

  Future<void> setTranslation(QuranTranslation value) async {
    if (value == _translation) return;
    cancelDownload();
    _translation = value;
    _loaded.clear();
    await _scanCache();
    notifyListeners();
    await _savePrefs();
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value.clamp(0.8, 1.8).toDouble();
    notifyListeners();
    await _savePrefs();
  }

  Future<void> _savePrefs() => _setKv(
    _prefsKey,
    jsonEncode({'translation': _translation.name, 'fontScale': _fontScale}),
  );

  // --------------------------------------------------------- reading spot --

  /// (surah, ayah) where the reader stopped last.
  (int, int)? get lastRead => _lastRead;

  Future<void> setLastRead(int surah, int ayah) async {
    if (_lastRead == (surah, ayah)) return;
    _lastRead = (surah, ayah);
    notifyListeners();
    onLocalChange?.call();
    await _setKv(_lastKey, '$surah:$ayah');
  }

  // ----------------------------------------------------------- bookmarks --

  /// Newest first.
  List<QuranBookmark> get bookmarks =>
      _bookmarks.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool isBookmarked(int surah, int ayah) =>
      _bookmarks.containsKey((surah, ayah));

  Future<void> toggleBookmark(int surah, int ayah) async {
    if (_bookmarks.remove((surah, ayah)) != null) {
      notifyListeners();
      onLocalChange?.call();
      await _db?.delete(
        'quran_bookmarks',
        where: 'surah = ? AND ayah = ?',
        whereArgs: [surah, ayah],
      );
      return;
    }
    final b = QuranBookmark(surah, ayah, DateTime.now());
    _bookmarks[(surah, ayah)] = b;
    notifyListeners();
    onLocalChange?.call();
    await _db?.insert('quran_bookmarks', {
      'surah': surah,
      'ayah': ayah,
      'created_at': b.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // -------------------------------------------------------------- backup --

  Map<String, Object?> toBackup() => {
    'bookmarks': [
      for (final b in _bookmarks.values)
        {
          'surah': b.surah,
          'ayah': b.ayah,
          'created_at': b.createdAt.millisecondsSinceEpoch,
        },
    ],
    if (_lastRead != null) 'last': [_lastRead!.$1, _lastRead!.$2],
  };

  /// Adds bookmarks from a backup; takes its reading spot if there is none.
  Future<void> mergeBackup(Map<String, Object?> json) async {
    final batch = _db?.batch();
    for (final r in (json['bookmarks'] as List? ?? const [])) {
      final m = r as Map;
      final surah = m['surah'], ayah = m['ayah'], at = m['created_at'];
      if (surah is! int || ayah is! int || surah < 1 || surah > 114) continue;
      if (_bookmarks.containsKey((surah, ayah))) continue;
      final b = QuranBookmark(
        surah,
        ayah,
        DateTime.fromMillisecondsSinceEpoch(at is int ? at : 0),
      );
      _bookmarks[(surah, ayah)] = b;
      batch?.insert('quran_bookmarks', {
        'surah': surah,
        'ayah': ayah,
        'created_at': b.createdAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch?.commit(noResult: true);
    final last = json['last'];
    if (_lastRead == null && last is List && last.length == 2) {
      final (s, a) = (last[0], last[1]);
      if (s is int && a is int && s >= 1 && s <= 114) {
        _lastRead = (s, a);
        await _setKv(_lastKey, '$s:$a');
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- text --

  bool isAvailable(int surah) =>
      _loaded.containsKey(surah) || _cached.contains(surah);

  int get availableCount =>
      {..._loaded.keys, ..._cached}.length.clamp(0, Surah.all.length);

  List<Ayah>? loaded(int surah) => _loaded[surah];

  String get _editionTag =>
      _translation == QuranTranslation.none ? 'ar' : _translation.edition;

  File? _file(int surah) {
    final dir = cacheDir;
    if (dir == null) return null;
    return File(p.join(dir, _editionTag, '$surah.json'));
  }

  Future<void> _scanCache() async {
    _cached.clear();
    final dir = cacheDir;
    if (dir == null) return;
    final folder = Directory(p.join(dir, _editionTag));
    if (!await folder.exists()) return;
    await for (final f in folder.list()) {
      final n = int.tryParse(p.basenameWithoutExtension(f.path));
      if (n != null) _cached.add(n);
    }
  }

  /// The ayahs of [surah], from memory, the device, or the network.
  /// Concurrent calls for the same surah share one download.
  Future<List<Ayah>> surah(int surah) {
    final inMemory = _loaded[surah];
    if (inMemory != null) return Future.value(inMemory);
    return _inFlight[surah] ??= _fetch(surah)
        .whenComplete(() => _inFlight.remove(surah));
  }

  Future<List<Ayah>> _fetch(int surah) async {
    final inMemory = _loaded[surah];
    if (inMemory != null) return inMemory;

    final file = _file(surah);
    if (file != null && await file.exists()) {
      try {
        final ayahs = _decode(jsonDecode(await file.readAsString()) as Map);
        _loaded[surah] = ayahs;
        return ayahs;
      } catch (_) {
        await file.delete();
      }
    }

    final client = _client;
    if (client == null) throw StateError('Surah $surah is not available');
    final editions = [
      'quran-uthmani',
      if (_translation != QuranTranslation.none) _translation.edition,
    ].join(',');
    final res = await client
        .get(Uri.parse('$_api/surah/$surah/editions/$editions'))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('Quran download failed (${res.statusCode})');
    }
    final data =
        (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['data'] as List;
    List<String> texts(int i) => [
      for (final a in (data[i] as Map)['ayahs'] as List)
        (a as Map)['text'] as String,
    ];
    final arabic = texts(0);
    final compact = {
      'ar': [
        for (var i = 0; i < arabic.length; i++)
          i == 0 ? _stripBasmala(surah, arabic[0]) : arabic[i],
      ],
      'tr': data.length > 1 ? texts(1) : const <String>[],
    };
    if (file != null) {
      // Write then rename, so a killed app never leaves half a file.
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(compact), flush: true);
      await tmp.rename(file.path);
      _cached.add(surah);
    }
    final ayahs = _decode(compact);
    _loaded[surah] = ayahs;
    notifyListeners();
    return ayahs;
  }

  static List<Ayah> _decode(Map json) {
    final ar = (json['ar'] as List).cast<String>();
    final tr = (json['tr'] as List).cast<String>();
    return [
      for (var i = 0; i < ar.length; i++)
        Ayah(i + 1, ar[i], i < tr.length ? tr[i] : ''),
    ];
  }

  /// The Uthmani text puts the Basmala in front of the first ayah of most
  /// surahs. SLife shows it as a header instead.
  static String _stripBasmala(int surah, String text) {
    if (!Surah.byNumber(surah).hasBasmalaHeader) return text;
    final words = text.replaceAll('﻿', '').trim().split(' ');
    if (words.length > 4 && words.first.startsWith('بِسْمِ')) {
      return words.skip(4).join(' ').trim();
    }
    return text;
  }

  // ------------------------------------------------------ offline download --

  /// Surah currently being downloaded by [downloadAll], or null.
  int? get downloading => _downloading;
  int get downloadDone => _downloadDone;
  bool get isDownloading => _downloading != null;

  /// Saves every surah on the device. Returns false if it stopped early.
  Future<bool> downloadAll() async {
    if (isDownloading) return false;
    _cancelDownload = false;
    _downloadDone = 0;
    var ok = true;
    for (final s in Surah.all) {
      if (_cancelDownload) {
        ok = false;
        break;
      }
      _downloading = s.number;
      notifyListeners();
      try {
        if (!_cached.contains(s.number)) await surah(s.number);
        _loaded.remove(s.number); // keep memory small
      } catch (_) {
        ok = false;
        break;
      }
      _downloadDone++;
    }
    _downloading = null;
    notifyListeners();
    return ok;
  }

  void cancelDownload() => _cancelDownload = true;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
