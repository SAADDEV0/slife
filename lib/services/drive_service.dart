import 'dart:convert';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Thin wrapper around the Drive v3 API with the operations SLife needs.
class DriveService {
  DriveService(http.Client client) : _api = drive.DriveApi(client);

  final drive.DriveApi _api;

  static const folderMime = 'application/vnd.google-apps.folder';
  static const _resumableThreshold = 5 * 1024 * 1024;

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  Future<String?> findFolder(String name, {required String parentId}) async {
    final res = await _api.files.list(
      q:
          "name = '${_escape(name)}' and mimeType = '$folderMime' "
          "and '$parentId' in parents and trashed = false",
      spaces: 'drive',
      pageSize: 10,
      $fields: 'files(id, name)',
    );
    final files = res.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  Future<String> createFolder(String name, {required String parentId}) async {
    final folder = await _api.files.create(
      drive.File()
        ..name = name
        ..mimeType = folderMime
        ..parents = [parentId],
      $fields: 'id',
    );
    return folder.id!;
  }

  Future<String> ensureFolder(String name, {required String parentId}) async {
    return await findFolder(name, parentId: parentId) ??
        await createFolder(name, parentId: parentId);
  }

  /// False when the file was deleted or moved to the trash.
  Future<bool> isAlive(String fileId) async {
    try {
      final file =
          await _api.files.get(fileId, $fields: 'id, trashed') as drive.File;
      return file.trashed != true;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) return false;
      rethrow;
    }
  }

  Future<String> uploadFile(
    File file, {
    required String name,
    required String parentId,
    required String mimeType,
  }) async {
    final length = await file.length();
    final created = await _api.files.create(
      drive.File()
        ..name = name
        ..parents = [parentId],
      uploadMedia: drive.Media(file.openRead(), length, contentType: mimeType),
      uploadOptions: length > _resumableThreshold
          ? drive.UploadOptions.resumable
          : drive.UploadOptions.defaultOptions,
      $fields: 'id',
    );
    return created.id!;
  }

  /// Updates the content of [fileId], or creates the file when it does not
  /// exist (any more). Returns the file id.
  Future<String> upsertText({
    required String? fileId,
    required String name,
    required String parentId,
    required String content,
    required String mimeType,
  }) async {
    final bytes = utf8.encode(content);
    drive.Media media() =>
        drive.Media(Stream.value(bytes), bytes.length, contentType: mimeType);

    if (fileId != null) {
      try {
        final updated = await _api.files.update(
          drive.File(),
          fileId,
          uploadMedia: media(),
          $fields: 'id, trashed',
        );
        if (updated.trashed != true) return updated.id!;
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow;
      }
    }
    final created = await _api.files.create(
      drive.File()
        ..name = name
        ..mimeType = mimeType
        ..parents = [parentId],
      uploadMedia: media(),
      $fields: 'id',
    );
    return created.id!;
  }

  /// Moves a file or folder to the Drive trash (recoverable for 30 days).
  Future<void> trash(String fileId) async {
    try {
      await _api.files.update(
        drive.File()..trashed = true,
        fileId,
        $fields: 'id',
      );
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  /// Lists the children of a folder. [foldersOnly] filters by type.
  Future<List<drive.File>> listChildren(
    String parentId, {
    bool? foldersOnly,
  }) async {
    final typeFilter = switch (foldersOnly) {
      true => " and mimeType = '$folderMime'",
      false => " and mimeType != '$folderMime'",
      null => '',
    };
    final out = <drive.File>[];
    String? pageToken;
    do {
      final res = await _api.files.list(
        q: "'$parentId' in parents and trashed = false$typeFilter",
        spaces: 'drive',
        pageSize: 1000,
        pageToken: pageToken,
        $fields: 'nextPageToken, files(id, name, mimeType, size, createdTime)',
      );
      out.addAll(res.files ?? const []);
      pageToken = res.nextPageToken;
    } while (pageToken != null);
    return out;
  }

  Future<void> download(String fileId, File target) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    await target.parent.create(recursive: true);
    final sink = target.openWrite();
    try {
      await sink.addStream(media.stream);
    } finally {
      await sink.close();
    }
  }

  Future<String> readText(String fileId) async {
    final media = await _api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
