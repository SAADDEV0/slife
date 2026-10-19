import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../data/quran_repository.dart';
import '../data/tasbih_repository.dart';
import 'settings_service.dart';

/// Backs up everything that is not the journal (planner, tasks, tasbih,
/// Quran bookmarks) as one JSON file in the `SLife` Drive folder:
///
/// ```
/// My Drive/SLife/slife-data.json
/// ```
///
/// Restoring merges: nothing already on the phone is overwritten.
class LifeBackup {
  LifeBackup({
    required this.planner,
    required this.tasbih,
    required this.quran,
    required this.settings,
  }) {
    planner.onLocalChange = _markDirty;
    tasbih.onLocalChange = _markDirty;
    quran.onLocalChange = _markDirty;
  }

  final PlannerRepository planner;
  final TasbihRepository tasbih;
  final QuranRepository quran;
  final SettingsService settings;

  static const fileName = 'slife-data.json';
  static const _version = 1;

  /// Asks the sync engine to run soon.
  VoidCallback? onDirty;

  /// Bumped on every change, so an upload that raced with an edit does not
  /// mark the data as backed up.
  int _generation = 0;
  int get generation => _generation;

  bool get dirty => settings.lifeDirty;

  void _markDirty() {
    _generation++;
    if (!settings.lifeDirty) settings.setLifeDirty(true);
    onDirty?.call();
  }

  /// Forces a fresh upload (the Drive folder was recreated).
  Future<void> forgetDrive() async {
    await settings.setLifeFileId(null);
    _markDirty();
  }

  String encode() => const JsonEncoder.withIndent(' ').convert({
    'app': 'SLife',
    'version': _version,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'planner': planner.toBackup(),
    'tasbih': tasbih.toBackup(),
    'quran': quran.toBackup(),
  });

  Future<void> markUploaded(String fileId, int generation) async {
    await settings.setLifeFileId(fileId);
    if (generation == _generation) await settings.setLifeDirty(false);
  }

  /// Merges a downloaded backup into the phone. Returns false if the file
  /// could not be read.
  Future<bool> merge(String text) async {
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      Map<String, Object?> part(String key) =>
          (json[key] as Map?)?.cast<String, Object?>() ?? const {};
      await planner.mergeBackup(part('planner'));
      await tasbih.mergeBackup(part('tasbih'));
      await quran.mergeBackup(part('quran'));
      _markDirty(); // upload the merged result
      return true;
    } catch (e) {
      debugPrint('SLife: could not read $fileName: $e');
      return false;
    }
  }
}
