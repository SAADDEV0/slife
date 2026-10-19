import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/dhikr.dart';
import '../utils/dates.dart';

/// What happened after a tap on the counter.
enum TasbihTap {
  /// Counted, nothing else.
  counted,

  /// The round's target was just reached.
  roundComplete,

  /// The target was reached and the after-prayer sequence moved on to the
  /// next phrase.
  nextInSequence,

  /// The last phrase of the after-prayer sequence was completed.
  sequenceComplete,
}

/// The digital tasbih: current session plus a per-day log of every count.
class TasbihRepository extends ChangeNotifier {
  TasbihRepository(Database db) : _db = db;

  /// In-memory repository for tests and previews.
  @visibleForTesting
  TasbihRepository.memory({Map<String, Map<String, int>> log = const {}})
    : _db = null {
    for (final e in log.entries) {
      _log[e.key] = Map.of(e.value);
    }
  }

  final Database? _db;
  static const _uuid = Uuid();
  static const _sessionKey = 'tasbih.session';

  final List<Dhikr> _custom = [];

  /// day → dhikr id → count.
  final Map<String, Map<String, int>> _log = {};

  String _dhikrId = Dhikr.presets.first.id;
  int _count = 0;
  int _target = Dhikr.presets.first.target;
  int _rounds = 0;
  bool _sequence = false;
  Timer? _saveTimer;

  /// Called after every change worth backing up.
  VoidCallback? onLocalChange;

  Future<void> load() async {
    final db = _db;
    if (db == null) return;
    final custom = await db.query('dhikr', orderBy: 'created_at');
    _custom
      ..clear()
      ..addAll(custom.map(Dhikr.fromRow));
    final rows = await db.query('tasbih_log');
    _log.clear();
    for (final r in rows) {
      (_log[r['day'] as String] ??= {})[r['dhikr'] as String] =
          r['count'] as int;
    }
    final session = await db.query(
      'kv',
      where: 'key = ?',
      whereArgs: [_sessionKey],
    );
    if (session.isNotEmpty) {
      try {
        final s = jsonDecode(session.first['value'] as String) as Map;
        _dhikrId = s['dhikr'] as String? ?? _dhikrId;
        _count = s['count'] as int? ?? 0;
        _target = s['target'] as int? ?? _target;
        _rounds = s['rounds'] as int? ?? 0;
        _sequence = s['sequence'] as bool? ?? false;
      } catch (_) {}
    }
    if (dhikrById(_dhikrId) == null) _dhikrId = Dhikr.presets.first.id;
    notifyListeners();
  }

  // ---------------------------------------------------------------- reads --

  List<Dhikr> get all => [...Dhikr.presets, ..._custom];

  Dhikr? dhikrById(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  Dhikr get current => dhikrById(_dhikrId) ?? Dhikr.presets.first;
  int get count => _count;

  /// Goal of one round; 0 means no limit.
  int get target => _target;
  int get rounds => _rounds;

  /// Whether SubhanAllah → Alhamdulillah → Allahu Akbar advance on their own.
  bool get sequence => _sequence;

  double get progress =>
      _target <= 0 ? 0 : (_count / _target).clamp(0.0, 1.0).toDouble();

  int totalOn(String day) =>
      _log[day]?.values.fold<int>(0, (a, b) => a + b) ?? 0;

  int countOn(String day, String dhikrId) => _log[day]?[dhikrId] ?? 0;

  int get todayTotal => totalOn(Dates.todayKey());

  int get lifetimeTotal => _log.values.fold(
    0,
    (sum, day) => sum + day.values.fold<int>(0, (a, b) => a + b),
  );

  /// Today's count for each phrase, highest first.
  List<(Dhikr, int)> get todayBreakdown {
    final today = _log[Dates.todayKey()] ?? const {};
    final list = [
      for (final e in today.entries)
        if (e.value > 0) (dhikrById(e.key) ?? _unknown(e.key), e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  /// Totals of the last [days] days, oldest first.
  List<(DateTime, int)> history({int days = 7}) {
    final today = Dates.today();
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return (d, totalOn(Dates.key(d)));
        }(),
    ];
  }

  /// Consecutive days with at least one count, ending today (or yesterday).
  int get streak {
    var d = Dates.today();
    if (totalOn(Dates.key(d)) == 0) d = Dates.previousDay(d);
    var n = 0;
    while (totalOn(Dates.key(d)) > 0) {
      n++;
      d = Dates.previousDay(d);
    }
    return n;
  }

  Dhikr _unknown(String id) => Dhikr(id: id, latin: 'Removed dhikr');

  // -------------------------------------------------------------- counter --

  TasbihTap increment() {
    _count++;
    _log1(1);
    var result = TasbihTap.counted;
    if (_target > 0 && _count >= _target) {
      final seq = Dhikr.sequenceIds.indexOf(_dhikrId);
      if (_sequence && seq >= 0 && seq < Dhikr.sequenceIds.length - 1) {
        _dhikrId = Dhikr.sequenceIds[seq + 1];
        _target = current.target;
        _count = 0;
        result = TasbihTap.nextInSequence;
      } else {
        _rounds++;
        _count = 0;
        result = _sequence && seq == Dhikr.sequenceIds.length - 1
            ? TasbihTap.sequenceComplete
            : TasbihTap.roundComplete;
        if (result == TasbihTap.sequenceComplete) {
          _dhikrId = Dhikr.sequenceIds.first;
          _target = current.target;
        }
      }
    }
    _changed();
    return result;
  }

  /// Takes back the last tap of this round.
  void decrement() {
    if (_count == 0) return;
    _count--;
    _log1(-1);
    _changed();
  }

  /// Starts the round over (today's log keeps what was counted).
  void reset() {
    _count = 0;
    _rounds = 0;
    _changed();
  }

  void select(String dhikrId) {
    final d = dhikrById(dhikrId);
    if (d == null || (d.id == _dhikrId)) return;
    _dhikrId = d.id;
    _target = d.target;
    _count = 0;
    _rounds = 0;
    _changed();
  }

  void setTarget(int target) {
    _target = target < 0 ? 0 : target;
    if (_target > 0 && _count >= _target) _count = 0;
    _changed();
  }

  void setSequence(bool value) {
    _sequence = value;
    if (value && !Dhikr.sequenceIds.contains(_dhikrId)) {
      _dhikrId = Dhikr.sequenceIds.first;
      _target = current.target;
      _count = 0;
      _rounds = 0;
    }
    _changed();
  }

  Future<Dhikr> addDhikr({
    required String latin,
    String arabic = '',
    String meaning = '',
    int target = 33,
  }) async {
    final d = Dhikr(
      id: 'custom-${_uuid.v4()}',
      latin: latin.trim(),
      arabic: arabic.trim(),
      meaning: meaning.trim(),
      target: target,
      custom: true,
    );
    _custom.add(d);
    notifyListeners();
    onLocalChange?.call();
    await _db?.insert('dhikr', d.toRow());
    return d;
  }

  Future<void> deleteDhikr(String id) async {
    _custom.removeWhere((d) => d.id == id);
    if (_dhikrId == id) {
      _dhikrId = Dhikr.presets.first.id;
      _target = current.target;
      _count = 0;
      _rounds = 0;
      _scheduleSave();
    }
    notifyListeners();
    await _db?.delete('dhikr', where: 'id = ?', whereArgs: [id]);
    onLocalChange?.call();
  }

  void _log1(int delta) {
    final day = Dates.todayKey();
    final counts = _log[day] ??= {};
    final next = ((counts[_dhikrId] ?? 0) + delta).clamp(0, 1 << 31);
    counts[_dhikrId] = next;
    onLocalChange?.call();
    _db?.insert('tasbih_log', {
      'day': day,
      'dhikr': _dhikrId,
      'count': next,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _changed() {
    notifyListeners();
    _scheduleSave();
  }

  // -------------------------------------------------------------- backup --

  Map<String, Object?> toBackup() => {
    'dhikr': [for (final d in _custom) d.toRow()],
    'log': {
      for (final e in _log.entries)
        if (e.value.values.any((n) => n > 0)) e.key: e.value,
    },
  };

  /// Adds phrases from a backup and keeps the higher count for each day.
  Future<void> mergeBackup(Map<String, Object?> json) async {
    final batch = _db?.batch();
    for (final r in (json['dhikr'] as List? ?? const [])) {
      final d = Dhikr.fromRow((r as Map).cast<String, Object?>());
      if (dhikrById(d.id) != null) continue;
      _custom.add(d);
      batch?.insert(
        'dhikr',
        d.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    final log = (json['log'] as Map?) ?? const {};
    for (final MapEntry(key: day, value: counts) in log.entries) {
      if (day is! String || counts is! Map) continue;
      final local = _log[day] ??= {};
      for (final MapEntry(key: id, value: n) in counts.entries) {
        if (id is! String || n is! int || n <= (local[id] ?? 0)) continue;
        local[id] = n;
        batch?.insert('tasbih_log', {
          'day': day,
          'dhikr': id,
          'count': n,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch?.commit(noResult: true);
    notifyListeners();
  }

  void _scheduleSave() {
    if (_db == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  /// Writes the session right away (called when the app goes to background).
  Future<void> flush() async {
    _saveTimer?.cancel();
    await _db?.insert('kv', {
      'key': _sessionKey,
      'value': jsonEncode({
        'dhikr': _dhikrId,
        'count': _count,
        'target': _target,
        'rounds': _rounds,
        'sequence': _sequence,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
