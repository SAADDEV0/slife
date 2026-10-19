import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../data/journal_repository.dart';
import '../data/media_storage.dart';
import '../models/journal_entry.dart';
import '../models/media_item.dart';
import '../utils/dates.dart';
import 'auth_service.dart';
import 'drive_format.dart';
import 'drive_service.dart';
import 'life_backup.dart';
import 'settings_service.dart';

enum SyncState {
  idle,
  syncing,
  upToDate,
  pending,
  offline,
  waitingForWifi,
  paused,
  signedOut,
  needsAuth,
  error,
}

class RestoreResult {
  const RestoreResult({required this.days, required this.files});
  final int days;
  final int files;
}

/// Uploads the local journal to Google Drive.
///
/// Everything is saved on the device first. Sync runs automatically when
/// something changes, when the app returns to the foreground, when the
/// network comes back, and every 15 minutes while the app is open.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService({
    required this.journal,
    required this.auth,
    required this.settings,
    required this.storage,
    this.life,
  }) {
    life?.onDirty = () => schedule(const Duration(seconds: 4));
  }

  final JournalRepository journal;
  final AuthService auth;
  final SettingsService settings;
  final MediaStorage storage;

  /// Planner, tasks, tasbih and Quran backup (`slife-data.json`).
  final LifeBackup? life;
  static const _uuid = Uuid();

  SyncState _state = SyncState.idle;
  int _total = 0;
  int _done = 0;
  String? _label;
  String? _lastError;
  int _failures = 0;
  bool _running = false;
  bool _again = false;
  bool _restoring = false;
  int _restoreTotal = 0;
  int _restoreDone = 0;
  String? _restoreLabel;

  bool _started = false;
  bool _wasSignedIn = false;
  bool _lastAutoSync = true;
  bool _lastWifiOnly = false;
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  SyncState get state => _state;
  bool get isSyncing => _running;
  int get total => _total;
  int get done => _done;
  String? get currentLabel => _label;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => settings.lastSyncAt;
  bool get isRestoring => _restoring;
  int get restoreTotal => _restoreTotal;
  int get restoreDone => _restoreDone;
  String? get restoreLabel => _restoreLabel;

  /// Things waiting to be uploaded: journal days, media and the life data.
  int get pendingCount =>
      journal.pendingUploads + ((life?.dirty ?? false) ? 1 : 0);

  double? get progress =>
      _total == 0 ? null : (_done / _total).clamp(0, 1).toDouble();

  String get statusTitle {
    final pending = pendingCount;
    return switch (_state) {
      SyncState.syncing =>
        _total == 0 ? 'Backing up…' : 'Backing up $_done of $_total',
      SyncState.upToDate => 'Everything is backed up',
      SyncState.pending || SyncState.idle =>
        !auth.isSignedIn
            ? 'Saved on this device only'
            : (pending == 0
                  ? 'Everything is backed up'
                  : '$pending waiting to upload'),
      SyncState.offline => 'Offline — will upload later',
      SyncState.waitingForWifi => 'Waiting for Wi‑Fi',
      SyncState.paused => 'Auto-upload is paused',
      SyncState.signedOut => 'Saved on this device only',
      SyncState.needsAuth => 'Drive access needs your OK',
      SyncState.error => 'Backup failed — retrying soon',
    };
  }

  // ----------------------------------------------------------- triggers --

  void start() {
    if (_started) return;
    _started = true;
    journal.onLocalChange = () => schedule(const Duration(seconds: 4));
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (_isOnline(results)) {
        schedule(const Duration(seconds: 2));
      } else if (!_running) {
        _setState(SyncState.offline);
      }
    });
    _periodic = Timer.periodic(
      const Duration(minutes: 15),
      (_) => schedule(Duration.zero),
    );
    _wasSignedIn = auth.isSignedIn;
    _lastAutoSync = settings.autoSync;
    _lastWifiOnly = settings.wifiOnly;
    auth.addListener(_onAuthChanged);
    settings.addListener(_onSettingsChanged);
    _settle();
    schedule(const Duration(seconds: 2));
  }

  void _onAuthChanged() {
    final signedIn = auth.isSignedIn;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    if (signedIn) {
      schedule(const Duration(seconds: 1));
    } else {
      _settle();
    }
  }

  void _onSettingsChanged() {
    if (settings.autoSync == _lastAutoSync &&
        settings.wifiOnly == _lastWifiOnly) {
      return;
    }
    _lastAutoSync = settings.autoSync;
    _lastWifiOnly = settings.wifiOnly;
    schedule(const Duration(milliseconds: 300));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      schedule(const Duration(seconds: 1));
    } else if (state == AppLifecycleState.paused && pendingCount > 0) {
      // Best effort: start uploading before the OS suspends us.
      schedule(Duration.zero);
    }
  }

  /// Runs a sync after [delay], collapsing bursts of changes into one run.
  void schedule([Duration delay = const Duration(seconds: 3)]) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
    _settle();
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

  bool _isUnmetered(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);

  /// Picks a resting state when no sync is running.
  void _settle() {
    if (_running || _restoring) return;
    final pending = pendingCount;
    final SyncState next;
    if (!auth.isSignedIn) {
      next = SyncState.signedOut;
    } else if (pending == 0) {
      next = SyncState.upToDate;
    } else if (const {
      SyncState.offline,
      SyncState.waitingForWifi,
      SyncState.error,
      SyncState.needsAuth,
    }.contains(_state)) {
      next = _state;
    } else if (!settings.autoSync) {
      next = SyncState.paused;
    } else {
      next = SyncState.pending;
    }
    _setState(next);
  }

  void _setState(SyncState next) {
    if (_state == next) {
      notifyListeners();
      return;
    }
    _state = next;
    notifyListeners();
  }

  // --------------------------------------------------------------- sync --

  /// Uploads everything that changed. [manual] ignores the auto-upload and
  /// Wi‑Fi-only preferences and may show the Drive permission prompt.
  Future<void> syncNow({bool manual = false}) async {
    if (_restoring) return;
    if (_running) {
      _again = true;
      return;
    }
    _debounce?.cancel();

    if (!auth.isSignedIn) return _setState(SyncState.signedOut);
    if (pendingCount == 0) return _setState(SyncState.upToDate);
    if (!manual && !settings.autoSync) return _setState(SyncState.paused);

    final connectivity = await Connectivity().checkConnectivity();
    if (!_isOnline(connectivity)) return _setState(SyncState.offline);
    if (!manual && settings.wifiOnly && !_isUnmetered(connectivity)) {
      return _setState(SyncState.waitingForWifi);
    }

    _running = true;
    _lastError = null;
    _total = 0;
    _done = 0;
    _label = null;
    _setState(SyncState.syncing);

    http.Client? client;
    try {
      client = await auth.driveClient(interactive: manual);
      if (client == null) {
        _running = false;
        _setState(SyncState.needsAuth);
        return;
      }
      await _upload(DriveService(client));
      _failures = 0;
      await settings.setLastSyncAt(DateTime.now());
      _running = false;
      _setState(pendingCount == 0 ? SyncState.upToDate : SyncState.pending);
    } catch (e, st) {
      debugPrint('SLife: sync failed: $e\n$st');
      _running = false;
      if (e is gd.DetailedApiRequestError && e.status == 401) {
        await auth.invalidateToken();
      }
      _failures++;
      _lastError = _describe(e);
      _setState(SyncState.error);
      final backoff = math.min(900, 15 * math.pow(2, _failures - 1).toInt());
      _debounce?.cancel();
      _debounce = Timer(Duration(seconds: backoff), syncNow);
    } finally {
      client?.close();
      _running = false;
      _label = null;
      notifyListeners();
      if (_again) {
        _again = false;
        schedule(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _upload(DriveService drive) async {
    final rootId = await _ensureRoot(drive);

    final trash = await journal.trashQueue();
    final days = await journal.daysNeedingSync();
    final plan = <String, List<MediaItem>>{};
    var total = trash.length;
    final life = this.life;
    final lifeDirty = life != null && life.dirty;
    if (lifeDirty) total++;
    for (final day in days) {
      final media = (await journal.readMedia(day))
          .where((m) => !m.isSynced)
          .toList();
      plan[day] = media;
      total += media.length + 1;
    }
    _total = total;
    notifyListeners();

    for (final id in trash) {
      _label = 'Cleaning up deleted items';
      await drive.trash(id);
      await journal.removeFromTrashQueue(id);
      _step();
    }
    for (final day in days) {
      await _uploadDay(drive, rootId, day, plan[day]!);
    }
    if (lifeDirty) {
      _label = 'Planner, tasbih and Quran';
      notifyListeners();
      final generation = life.generation;
      final id = await drive.upsertText(
        fileId: settings.lifeFileId,
        name: LifeBackup.fileName,
        parentId: rootId,
        content: life.encode(),
        mimeType: 'application/json',
      );
      await life.markUploaded(id, generation);
      _step();
    }
  }

  Future<String> _ensureRoot(DriveService drive) async {
    final cached = settings.driveRootId;
    if (cached != null && await drive.isAlive(cached)) return cached;
    final id = await drive.ensureFolder(
      AppConfig.driveRootFolder,
      parentId: 'root',
    );
    await settings.setDriveRootId(id);
    if (cached != null && cached != id) {
      // The SLife folder was deleted from Drive: back up everything again.
      await journal.forgetAllDriveIds();
      await life?.forgetDrive();
    }
    return id;
  }

  Future<void> _uploadDay(
    DriveService drive,
    String rootId,
    String day,
    List<MediaItem> pendingMedia,
  ) async {
    var entry = await journal.readEntry(day);
    if (entry == null) {
      _step(pendingMedia.length + 1);
      return;
    }
    _label = Dates.compact(entry.date);
    notifyListeners();

    var folderId = entry.driveFolderId;
    if (folderId != null && !await drive.isAlive(folderId)) {
      // The day folder was removed in Drive by hand: upload it again.
      await journal.forgetDriveIds(day);
      folderId = null;
      final all = await journal.readMedia(day);
      _total += all.length - pendingMedia.length;
      pendingMedia = all;
    }
    if (folderId == null) {
      folderId = await drive.ensureFolder(day, parentId: rootId);
      if (!await journal.setDriveFolder(day, folderId)) {
        await drive.trash(folderId); // Deleted while we were uploading.
        return;
      }
    }

    final typeFolders = <MediaType, String>{};
    for (final item in pendingMedia) {
      final file = storage.fileFor(item);
      if (!await file.exists()) {
        await journal.deleteMedia(item); // The file is gone; drop the record.
        _step();
        continue;
      }
      final parentId = typeFolders[item.type] ??= await drive.ensureFolder(
        item.type.folder,
        parentId: folderId,
      );
      final driveId = await drive.uploadFile(
        file,
        name: item.fileName,
        parentId: parentId,
        mimeType: _mimeFor(item),
      );
      if (!await journal.setMediaDriveId(item, driveId)) {
        await drive.trash(driveId); // Deleted while uploading.
      }
      _step();
      await journal.refreshDay(day);
    }

    entry = await journal.readEntry(day);
    if (entry != null && entry.dirty) {
      final media = await journal.readMedia(day);
      final jsonId = await drive.upsertText(
        fileId: entry.driveJsonId,
        name: DriveFormat.jsonName,
        parentId: folderId,
        content: DriveFormat.entryJson(entry, media),
        mimeType: 'application/json',
      );
      final textId = await drive.upsertText(
        fileId: entry.driveTextId,
        name: DriveFormat.textName,
        parentId: folderId,
        content: DriveFormat.journalText(entry, media),
        mimeType: 'text/plain',
      );
      await journal.markTextSynced(
        day,
        rev: entry.rev,
        jsonId: jsonId,
        textId: textId,
      );
    }
    _step();
    await journal.refreshDay(day);
  }

  void _step([int count = 1]) {
    _done += count;
    notifyListeners();
  }

  static String _mimeFor(MediaItem item) {
    return lookupMimeType(item.fileName) ??
        switch (item.type) {
          MediaType.image => 'image/jpeg',
          MediaType.video => 'video/mp4',
          MediaType.audio => 'audio/mp4',
        };
  }

  static String _describe(Object e) {
    if (e is gd.DetailedApiRequestError) {
      return switch (e.status) {
        401 => 'Your Google session expired. It will refresh automatically.',
        403 =>
          'Google Drive refused the upload (${e.message ?? 'forbidden'}). '
              'Check that the Drive API is enabled and storage is not full.',
        _ => e.message ?? 'Google Drive error ${e.status}',
      };
    }
    if (e is SocketException || e is http.ClientException) {
      return 'Network problem — will retry.';
    }
    return e.toString();
  }

  // ------------------------------------------------------------ restore --

  /// Number of day folders in Drive that are not on this device yet.
  Future<int> countRestorableDays() async {
    final client = await auth.driveClient(interactive: true);
    if (client == null) return 0;
    try {
      final drive = DriveService(client);
      final rootId = await drive.findFolder(
        AppConfig.driveRootFolder,
        parentId: 'root',
      );
      if (rootId == null) return 0;
      final folders = await drive.listChildren(rootId, foldersOnly: true);
      return folders
          .where((f) => f.name != null && Dates.isDayKey(f.name!))
          .where((f) => journal.entryFor(f.name!) == null)
          .length;
    } finally {
      client.close();
    }
  }

  /// Downloads every day from Drive that does not exist on this device.
  Future<RestoreResult> restoreFromDrive() async {
    if (_restoring) return const RestoreResult(days: 0, files: 0);
    _restoring = true;
    _restoreTotal = 0;
    _restoreDone = 0;
    _restoreLabel = 'Looking for your journal…';
    notifyListeners();
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    http.Client? client;
    try {
      client = await auth.driveClient(interactive: true);
      if (client == null) {
        throw StateError('Google Drive access was not granted.');
      }
      final drive = DriveService(client);
      final rootId = await drive.findFolder(
        AppConfig.driveRootFolder,
        parentId: 'root',
      );
      if (rootId == null) return const RestoreResult(days: 0, files: 0);
      await settings.setDriveRootId(rootId);

      final folders =
          (await drive.listChildren(rootId, foldersOnly: true))
              .where(
                (f) =>
                    f.id != null && f.name != null && Dates.isDayKey(f.name!),
              )
              .toList()
            ..sort((a, b) => b.name!.compareTo(a.name!));
      _restoreTotal = folders.length;
      notifyListeners();

      var days = 0;
      var files = 0;
      for (final folder in folders) {
        final day = folder.name!;
        _restoreLabel = Dates.compact(Dates.parse(day));
        notifyListeners();
        if (!await journal.hasEntry(day)) {
          files += await _restoreDay(drive, day, folder.id!);
          days++;
          await journal.refreshDay(day);
        }
        _restoreDone++;
        notifyListeners();
      }
      await _restoreLife(drive, rootId);
      return RestoreResult(days: days, files: files);
    } finally {
      client?.close();
      _restoring = false;
      _restoreLabel = null;
      notifyListeners();
      schedule();
    }
  }

  /// Merges `slife-data.json` (planner, tasks, tasbih, Quran) if present.
  Future<void> _restoreLife(DriveService drive, String rootId) async {
    final life = this.life;
    if (life == null) return;
    _restoreLabel = 'Planner, tasbih and Quran';
    notifyListeners();
    final files = await drive.listChildren(rootId, foldersOnly: false);
    for (final f in files) {
      if (f.name != LifeBackup.fileName || f.id == null) continue;
      if (await life.merge(await drive.readText(f.id!))) {
        await settings.setLifeFileId(f.id);
      }
      return;
    }
  }

  Future<int> _restoreDay(
    DriveService drive,
    String day,
    String folderId,
  ) async {
    final children = await drive.listChildren(folderId);
    gd.File? jsonFile;
    gd.File? textFile;
    final typeFolders = <MediaType, String>{};
    for (final child in children) {
      if (child.mimeType == DriveService.folderMime) {
        final type = MediaType.fromFolder(child.name ?? '');
        if (type != null && child.id != null) typeFolders[type] = child.id!;
      } else if (child.name == DriveFormat.jsonName) {
        jsonFile = child;
      } else if (child.name == DriveFormat.textName) {
        textFile = child;
      }
    }

    RestoredDay? meta;
    if (jsonFile?.id != null) {
      try {
        meta = DriveFormat.parseEntryJson(await drive.readText(jsonFile!.id!));
      } catch (e) {
        debugPrint('SLife: could not read entry.json for $day: $e');
      }
    }
    var body = meta?.body ?? '';
    if (meta == null && textFile?.id != null) {
      body = await drive.readText(textFile!.id!);
    }

    final date = Dates.parse(day);
    await journal.importEntry(
      JournalEntry(
        day: day,
        title: meta?.title ?? '',
        body: body,
        mood: meta?.mood,
        createdAt: meta?.createdAt ?? date,
        updatedAt: meta?.updatedAt ?? date,
        rev: 0,
        dirty: meta == null,
        driveFolderId: folderId,
        driveJsonId: jsonFile?.id,
        driveTextId: textFile?.id,
      ),
    );

    var count = 0;
    for (final MapEntry(key: type, value: subfolderId) in typeFolders.entries) {
      final files = await drive.listChildren(subfolderId, foldersOnly: false);
      for (final file in files) {
        final id = file.id;
        // Never let a remote name escape the day folder.
        final name = file.name == null ? null : p.basename(file.name!);
        if (name == null ||
            name.isEmpty ||
            name.startsWith('.') ||
            id == null) {
          continue;
        }
        final info = meta?.find(driveFileId: id, fileName: name);
        final target = await storage.prepareTarget(day, type, name);
        await drive.download(id, File(target));
        final thumb = type == MediaType.video
            ? await storage.createVideoThumb(day, name)
            : null;
        await journal.importMedia(
          MediaItem(
            id: info?.id ?? _uuid.v4(),
            day: day,
            type: type,
            fileName: name,
            thumbName: thumb,
            durationMs: info?.durationMs,
            createdAt: info?.createdAt ?? file.createdTime?.toLocal() ?? date,
            driveFileId: id,
          ),
        );
        count++;
      }
    }
    return count;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(_onAuthChanged);
    settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
