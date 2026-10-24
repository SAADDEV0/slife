import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences and small bits of sync state.
class SettingsService extends ChangeNotifier {
  SettingsService._(this._prefs);

  /// In-memory settings for tests and previews.
  @visibleForTesting
  SettingsService.memory({bool onboarded = true, String userName = ''})
    : _prefs = null {
    _memory['onboarded'] = onboarded;
    _memory['userName'] = userName;
  }

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return SettingsService._(prefs);
  }

  final SharedPreferencesWithCache? _prefs;
  final Map<String, Object?> _memory = {};

  T? _get<T>(String key) {
    final prefs = _prefs;
    if (prefs == null) return _memory[key] as T?;
    return prefs.get(key) as T?;
  }

  Future<void> _set(String key, Object? value) async {
    final prefs = _prefs;
    if (prefs == null) {
      _memory[key] = value;
    } else if (value == null) {
      await prefs.remove(key);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
    notifyListeners();
  }

  // Appearance
  ThemeMode get themeMode =>
      ThemeMode.values[_get<int>('themeMode') ?? ThemeMode.system.index];
  Future<void> setThemeMode(ThemeMode mode) => _set('themeMode', mode.index);

  // Onboarding & profile
  bool get onboarded => _get<bool>('onboarded') ?? false;
  Future<void> setOnboarded(bool value) => _set('onboarded', value);

  String get userName => _get<String>('userName') ?? '';
  Future<void> setUserName(String value) => _set('userName', value.trim());

  // Reminders (times are minutes since midnight)
  bool get journalReminder => _get<bool>('journalReminder') ?? false;
  Future<void> setJournalReminder(bool value) => _set('journalReminder', value);

  int get journalReminderMin => _get<int>('journalReminderMin') ?? 21 * 60;
  Future<void> setJournalReminderMin(int value) =>
      _set('journalReminderMin', value);

  bool get blockReminder => _get<bool>('blockReminder') ?? false;
  Future<void> setBlockReminder(bool value) => _set('blockReminder', value);

  /// How many minutes before a planner block starts.
  int get blockReminderLead => _get<int>('blockReminderLead') ?? 10;
  Future<void> setBlockReminderLead(int value) =>
      _set('blockReminderLead', value);

  bool get taskReminder => _get<bool>('taskReminder') ?? false;
  Future<void> setTaskReminder(bool value) => _set('taskReminder', value);

  int get taskReminderMin => _get<int>('taskReminderMin') ?? 8 * 60;
  Future<void> setTaskReminderMin(int value) => _set('taskReminderMin', value);

  /// Notify at each prayer time (needs [prayerLat]/[prayerLng]).
  bool get prayerReminder => _get<bool>('prayerReminder') ?? false;
  Future<void> setPrayerReminder(bool value) => _set('prayerReminder', value);

  /// Prayers the user silenced, e.g. `{'sunrise'}` (a `Salah` name each).
  Set<String> get prayerMuted {
    final raw = _get<String>('prayerMuted') ?? '';
    return raw.isEmpty ? {} : raw.split(',').toSet();
  }

  Future<void> setPrayerMuted(Set<String> value) =>
      _set('prayerMuted', value.join(','));

  bool get morningAdhkar => _get<bool>('morningAdhkar') ?? false;
  Future<void> setMorningAdhkar(bool value) => _set('morningAdhkar', value);

  int get morningAdhkarMin => _get<int>('morningAdhkarMin') ?? 7 * 60;
  Future<void> setMorningAdhkarMin(int value) =>
      _set('morningAdhkarMin', value);

  bool get eveningAdhkar => _get<bool>('eveningAdhkar') ?? false;
  Future<void> setEveningAdhkar(bool value) => _set('eveningAdhkar', value);

  int get eveningAdhkarMin => _get<int>('eveningAdhkarMin') ?? 17 * 60 + 30;
  Future<void> setEveningAdhkarMin(int value) =>
      _set('eveningAdhkarMin', value);

  bool get anyReminder =>
      journalReminder ||
      blockReminder ||
      taskReminder ||
      prayerReminder ||
      morningAdhkar ||
      eveningAdhkar;

  // Prayer times
  double? get prayerLat => _get<double>('prayerLat');
  double? get prayerLng => _get<double>('prayerLng');

  /// "Rabat, Morocco", or empty when the place could not be named.
  String get prayerPlace => _get<String>('prayerPlace') ?? '';

  Future<void> setPrayerLocation(double lat, double lng, String place) async {
    await _set('prayerLat', lat);
    await _set('prayerLng', lng);
    await _set('prayerPlace', place);
  }

  /// A `PrayerMethod` name, or null until the user (or their location)
  /// picks one.
  String? get prayerMethod => _get<String>('prayerMethod');
  Future<void> setPrayerMethod(String value) => _set('prayerMethod', value);

  /// Hanafi Asr (shadow twice the length) instead of the standard one.
  bool get prayerHanafi => _get<bool>('prayerHanafi') ?? false;
  Future<void> setPrayerHanafi(bool value) => _set('prayerHanafi', value);

  // Sync preferences
  bool get autoSync => _get<bool>('autoSync') ?? true;
  Future<void> setAutoSync(bool value) => _set('autoSync', value);

  bool get wifiOnly => _get<bool>('wifiOnly') ?? false;
  Future<void> setWifiOnly(bool value) => _set('wifiOnly', value);

  /// Whether the user connected Google Drive (so we try silent sign-in).
  bool get driveLinked => _get<bool>('driveLinked') ?? false;
  Future<void> setDriveLinked(bool value) => _set('driveLinked', value);

  /// Cached id of the `SLife` folder in Drive.
  String? get driveRootId => _get<String>('driveRootId');
  Future<void> setDriveRootId(String? id) => _set('driveRootId', id);

  DateTime? get lastSyncAt {
    final ms = _get<int>('lastSyncAt');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastSyncAt(DateTime at) =>
      _set('lastSyncAt', at.millisecondsSinceEpoch);

  /// Planner, tasks, tasbih and Quran data changed since the last backup.
  bool get lifeDirty => _get<bool>('lifeDirty') ?? false;
  Future<void> setLifeDirty(bool value) => _set('lifeDirty', value);

  /// Drive id of `slife-data.json`.
  String? get lifeFileId => _get<String>('lifeFileId');
  Future<void> setLifeFileId(String? id) => _set('lifeFileId', id);
}
