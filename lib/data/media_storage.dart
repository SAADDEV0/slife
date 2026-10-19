import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/media_item.dart';

/// Owns the on-device file layout. It mirrors the Google Drive layout:
///
/// ```
/// <app documents>/slife/days/2026-10-12/images/IMG_....jpg
///                                      /videos/VID_....mp4
///                                      /audios/AUD_....m4a
///                                      /.thumbs/VID_....jpg
/// ```
///
/// Only file *names* are stored in the database, so the journal survives the
/// app container moving (which happens on iOS after updates).
class MediaStorage {
  MediaStorage(this.rootPath);

  final String rootPath;
  static const _uuid = Uuid();
  static final _stamp = DateFormat('yyyyMMdd_HHmmss');

  static Future<MediaStorage> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = p.join(docs.path, 'slife');
    await Directory(root).create(recursive: true);
    return MediaStorage(root);
  }

  String dayDir(String day) => p.join(rootPath, 'days', day);

  String pathFor(MediaItem item) =>
      p.join(dayDir(item.day), item.type.folder, item.fileName);

  File fileFor(MediaItem item) => File(pathFor(item));

  String? thumbPathFor(MediaItem item) {
    final thumb = item.thumbName;
    if (thumb == null) return null;
    return p.join(dayDir(item.day), '.thumbs', thumb);
  }

  /// A unique, sortable file name such as `IMG_20261012_101530_3f9a.jpg`.
  String newFileName(MediaType type, String extension, [DateTime? at]) {
    final ext = extension.isEmpty
        ? _defaultExtension(type)
        : (extension.startsWith('.') ? extension : '.$extension');
    final suffix = _uuid.v4().substring(0, 4);
    return '${type.prefix}_${_stamp.format(at ?? DateTime.now())}_$suffix${ext.toLowerCase()}';
  }

  static String _defaultExtension(MediaType type) => switch (type) {
    MediaType.image => '.jpg',
    MediaType.video => '.mp4',
    MediaType.audio => '.m4a',
  };

  /// Creates the type folder for [day] and returns the full target path.
  Future<String> prepareTarget(
    String day,
    MediaType type,
    String fileName,
  ) async {
    final dir = Directory(p.join(dayDir(day), type.folder));
    await dir.create(recursive: true);
    return p.join(dir.path, fileName);
  }

  /// Copies (or moves) [sourcePath] into the day folder; returns the new name.
  Future<String> importFile(
    String day,
    MediaType type,
    String sourcePath, {
    bool move = false,
  }) async {
    final name = newFileName(type, p.extension(sourcePath));
    final target = await prepareTarget(day, type, name);
    final source = File(sourcePath);
    if (move) {
      try {
        await source.rename(target);
        return name;
      } on FileSystemException {
        // Different volume — fall back to copy + delete.
      }
    }
    await source.copy(target);
    if (move) {
      try {
        await source.delete();
      } catch (_) {}
    }
    return name;
  }

  /// Extracts a JPEG preview frame for a video. Returns the thumbnail name.
  Future<String?> createVideoThumb(String day, String fileName) async {
    try {
      final dir = Directory(p.join(dayDir(day), '.thumbs'));
      await dir.create(recursive: true);
      final thumbName = '${p.basenameWithoutExtension(fileName)}.jpg';
      final ok = await FcNativeVideoThumbnail().saveThumbnailToFile(
        srcFile: p.join(dayDir(day), MediaType.video.folder, fileName),
        destFile: p.join(dir.path, thumbName),
        width: 512,
        height: 512,
        format: 'jpeg',
        quality: 82,
      );
      return ok ? thumbName : null;
    } catch (e) {
      debugPrint('SLife: video thumbnail failed: $e');
      return null;
    }
  }

  Future<void> deleteMediaFiles(MediaItem item) async {
    for (final path in [pathFor(item), thumbPathFor(item)]) {
      if (path == null) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteDay(String day) async {
    final dir = Directory(dayDir(day));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Total bytes used by journal media on this device.
  Future<int> usedBytes() async {
    var total = 0;
    final dir = Directory(p.join(rootPath, 'days'));
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
  }
}
