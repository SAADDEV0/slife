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
