import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// How the reader lays out a surah.
enum QuranLayout {
  /// One card per ayah, with its translation.
  verses,

  /// Continuous Arabic text, like a printed mushaf.
  mushaf,
}

enum TranslationState { none, missing, downloading, ready, failed }

@immutable
class QuranBookmark {
  const QuranBookmark(this.surah, this.ayah, this.createdAt);

  final int surah;
  final int ayah;
  final DateTime createdAt;
}

/// One search hit.
@immutable
class AyahHit {
  const AyahHit(this.surah, this.ayah, this.text);

  final int surah;
  final int ayah;

  /// The text that matched (translation or Arabic).
  final String text;
}

/// Quran text, translations, bookmarks and reading position.
///
/// The Arabic text (Tanzil, Uthmani) ships inside the app and is decoded off
/// the UI thread on first use. A translation is downloaded once as a whole
/// (about 1 MB) from api.alquran.cloud and kept on the device.
class QuranRepository extends ChangeNotifier {
  QuranRepository(Database db, this.cacheDir, {http.Client? client})
    : _db = db,
      _client = client ?? http.Client();

  /// In-memory repository for tests and previews (no network, no disk).
  @visibleForTesting
  QuranRepository.memory({
    (int, int)? lastRead,
    QuranTranslation translation = QuranTranslation.none,
  }) : _db = null,
       _client = null,
       cacheDir = null {
    _lastRead = lastRead;
    _translation = translation;
  }

  final Database? _db;
  final http.Client? _client;
  final String? cacheDir;

  static const _api = 'https://api.alquran.cloud/v1';
  static const _asset = 'assets/quran/uthmani.json';
  static const _lastKey = 'quran.last';
  static const _prefsKey = 'quran.prefs';

  final Map<(int, int), QuranBookmark> _bookmarks = {};
  (int, int)? _lastRead;
  QuranTranslation _translation = QuranTranslation.english;
  QuranLayout _layout = QuranLayout.verses;
  double _fontScale = 1;

  _QuranText? _text;
  Future<_QuranText>? _textLoading;
  List<List<String>>? _tr;
  QuranTranslation? _trFor;
  TranslationState _trState = TranslationState.none;
  Future<void>? _trLoading;
  List<List<String>>? _searchIndex;

  /// Called after every change worth backing up (bookmarks, reading spot).
  VoidCallback? onLocalChange;

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
        _layout = QuranLayout.values.firstWhere(
          (l) => l.name == m['layout'],
          orElse: () => QuranLayout.verses,
        );
        _fontScale = (m['fontScale'] as num?)?.toDouble() ?? 1;
      } catch (_) {}
    }
    // The old per-surah cache is no longer used.
    final dir = cacheDir;
    if (dir != null) {
      for (final old in ['ar', 'en.sahih', 'fr.hamidullah']) {
        final d = Directory(p.join(dir, old));
        if (await d.exists()) unawaited(d.delete(recursive: true));
      }
    }
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
  QuranLayout get layout => _layout;
  double get fontScale => _fontScale;

  Future<void> setTranslation(QuranTranslation value) async {
    if (value == _translation) return;
    _translation = value;
    _tr = null;
    _trFor = null;
    _trState = TranslationState.none;
    _searchIndex = null;
    notifyListeners();
    await _savePrefs();
  }

  Future<void> setLayout(QuranLayout value) async {
    if (value == _layout) return;
    _layout = value;
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
    jsonEncode({
      'translation': _translation.name,
      'layout': _layout.name,
      'fontScale': _fontScale,
    }),
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

  bool get isTextReady => _text != null;

  /// Loads the bundled Arabic text (once; decoded off the UI thread).
  Future<void> ensureText() async {
    if (_text != null) return;
    _text = await (_textLoading ??= _loadText());
    notifyListeners();
  }

  Future<_QuranText> _loadText() async {
    final raw = await rootBundle.loadString(_asset, cache: false);
    // Small enough to decode inline in tests; big enough to matter on phones.
    return _db == null ? _QuranText.parse(raw) : compute(_QuranText.parse, raw);
  }

  /// Juz (1–30) that [surah]:[ayah] belongs to.
  int juzOf(int surah, int ayah) {
    final starts = _text?.juz ?? const <(int, int)>[];
    var juz = 1;
    for (var i = 0; i < starts.length; i++) {
      final (s, a) = starts[i];
      if (s < surah || (s == surah && a <= ayah)) juz = i + 1;
    }
    return juz;
  }

  /// First ayah of each juz.
  List<(int, int)> get juzStarts => _text?.juz ?? const [];

  /// The juz that begins at [surah]:[ayah], if any.
  int? juzStartingAt(int surah, int ayah) {
    final i = juzStarts.indexOf((surah, ayah));
    return i < 0 ? null : i + 1;
  }

  bool isSajda(int surah, int ayah) =>
      _text?.sajda.contains((surah, ayah)) ?? false;

  /// The ayahs of [surah] (Arabic, plus the translation when it is ready).
  /// Call [ensureText] first.
  List<Ayah> ayahs(int surah) {
    final text = _text;
    if (text == null) return const [];
    final ar = text.surahs[surah - 1];
    final tr = _tr != null && _trFor == _translation ? _tr![surah - 1] : null;
    return [
      for (var i = 0; i < ar.length; i++)
        Ayah(
          i + 1,
          i == 0 ? _stripBasmala(surah, ar[0]) : ar[i],
          tr != null && i < tr.length ? tr[i] : '',
        ),
    ];
  }

  /// The Uthmani text puts the Basmala in front of the first ayah of most
  /// surahs. SLife shows it as a header instead.
  static String _stripBasmala(int surah, String text) {
    final clean = text.replaceAll('﻿', '').trim();
    if (!Surah.byNumber(surah).hasBasmalaHeader) return clean;
    final words = clean.split(' ');
    if (words.length > 4 && words.first.startsWith('بِسْمِ')) {
      return words.skip(4).join(' ').trim();
    }
    return clean;
  }

  // --------------------------------------------------------- translation --

  TranslationState get translationState =>
      _translation == QuranTranslation.none ? TranslationState.none : _trState;

  bool get hasTranslation =>
      _tr != null && _trFor == _translation && _translation.edition.isNotEmpty;

  File? _trFile(QuranTranslation t) {
    final dir = cacheDir;
    if (dir == null || t.edition.isEmpty) return null;
    return File(p.join(dir, 'translations', '${t.edition}.json'));
  }

  /// Loads the chosen translation from the device, downloading it once if
  /// [download] is true.
  Future<void> ensureTranslation({bool download = true}) {
    if (_translation == QuranTranslation.none || hasTranslation) {
      return Future.value();
    }
    return _trLoading ??= _loadTranslation(
      _translation,
      download,
    ).whenComplete(() => _trLoading = null);
  }

  Future<void> _loadTranslation(QuranTranslation t, bool download) async {
    final file = _trFile(t);
    try {
      if (file != null && await file.exists()) {
        final data = await compute(_decodeLists, await file.readAsString());
        _setTranslation(t, data);
        return;
      }
      final client = _client;
      if (!download || client == null) {
        _trState = TranslationState.missing;
        notifyListeners();
        return;
      }
      _trState = TranslationState.downloading;
      notifyListeners();
      final res = await client
          .get(Uri.parse('$_api/quran/${t.edition}'))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('Translation download failed (${res.statusCode})');
      }
      final lists = await compute(_extractEdition, res.bodyBytes);
      if (lists.length != Surah.all.length) {
        throw const FormatException('Incomplete translation');
      }
      if (file != null) {
        // Write then rename, so a killed app never leaves half a file.
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(lists), flush: true);
        await tmp.rename(file.path);
      }
      _setTranslation(t, lists);
    } catch (e) {
      debugPrint('SLife: translation ${t.edition}: $e');
      if (_translation == t) {
        _trState = TranslationState.failed;
        notifyListeners();
      }
    }
  }

  void _setTranslation(QuranTranslation t, List<List<String>> data) {
    if (_translation != t) return; // changed meanwhile
    _tr = data;
    _trFor = t;
    _trState = TranslationState.ready;
    _searchIndex = null;
    notifyListeners();
  }

  static List<List<String>> _decodeLists(String raw) => [
    for (final s in jsonDecode(raw) as List) (s as List).cast<String>(),
  ];

  static List<List<String>> _extractEdition(Uint8List bytes) {
    final data = (jsonDecode(utf8.decode(bytes)) as Map)['data'] as Map;
    return [
      for (final s in data['surahs'] as List)
        [
          for (final a in (s as Map)['ayahs'] as List)
            (a as Map)['text'] as String,
        ],
    ];
  }

  // -------------------------------------------------------------- search --

  /// Ayahs whose translation or Arabic text contains [query]. Arabic is
  /// matched without diacritics.
  Future<List<AyahHit>> search(String query, {int limit = 60}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    await ensureText();
    final text = _text!;
    final arabic = _isArabic(q);
    List<List<String>>? haystack;
    if (arabic) {
      haystack = _searchIndex ??= _db == null
          ? _normalizeAll(text.surahs)
          : await compute(_normalizeAll, text.surahs);
    } else if (hasTranslation) {
      haystack = _tr;
    }
    if (haystack == null) return const [];
    final needle = arabic ? normalizeArabic(q) : q.toLowerCase();
    final hits = <AyahHit>[];
    for (var s = 0; s < haystack.length && hits.length < limit; s++) {
      final ayahs = haystack[s];
      for (var a = 0; a < ayahs.length && hits.length < limit; a++) {
        final h = arabic ? ayahs[a] : ayahs[a].toLowerCase();
        if (h.contains(needle)) {
          hits.add(
            AyahHit(
              s + 1,
              a + 1,
              arabic ? _stripBasmala(s + 1, text.surahs[s][a]) : _tr![s][a],
            ),
          );
        }
      }
    }
    return hits;
  }

  static bool _isArabic(String s) =>
      s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

  static final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  /// Removes diacritics and unifies letter forms for searching.
  static String normalizeArabic(String s) => s
      .replaceAll('﻿', '')
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[ٱأإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static List<List<String>> _normalizeAll(List<List<String>> surahs) => [
    for (final s in surahs) [for (final a in s) normalizeArabic(a)],
  ];

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}

/// The decoded bundled text.
class _QuranText {
  _QuranText(this.surahs, this.juz, this.sajda);

  final List<List<String>> surahs;
  final List<(int, int)> juz;
  final Set<(int, int)> sajda;

  static _QuranText parse(String raw) {
    final m = jsonDecode(raw) as Map;
    (int, int) pair(Object? x) => ((x as List)[0] as int, x[1] as int);
    return _QuranText(
      [for (final s in m['surahs'] as List) (s as List).cast<String>()],
      [for (final j in m['juz'] as List) pair(j)],
      {for (final s in m['sajda'] as List) pair(s)},
    );
  }
}
