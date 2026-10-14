import 'dart:convert';
import 'package:googleapis/drive/v3.dart' as drive;

import '../domain/shared_event_transport.dart';

/// Production Google Drive adapter implementing [SharedEventRemoteTransport].
class GoogleDriveSharedEventTransport implements SharedEventRemoteTransport {
  final drive.DriveApi? Function() _driveApiProvider;

  static const String rootSharedFolderName = 'Attendance Tracker - Shared Events';

  GoogleDriveSharedEventTransport({
    required drive.DriveApi? Function() driveApiProvider,
  }) : _driveApiProvider = driveApiProvider;

  drive.DriveApi? get _driveApi => _driveApiProvider();

  drive.DriveApi _requireApi() {
    final api = _driveApi;
    if (api == null) throw StateError('DriveApi not initialized');
    return api;
  }

  Future<String> _getOrCreateRootSharedFolder() async {
    final api = _requireApi();
    final q = "name = '$rootSharedFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final list = await api.files.list(q: q, $fields: 'files(id, name)');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = drive.File()
      ..name = rootSharedFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  @override
  Future<List<RemoteSharedFolder>> discoverSharedFolders() async {
    final api = _requireApi();
    final q = "mimeType = 'application/vnd.google-apps.folder' and sharedWithMe = true and trashed = false";
    final list = await api.files.list(
      q: q,
      $fields: 'files(id, name, owners)',
    );
    final files = list.files ?? [];
    return files
        .where((f) => f.id != null)
        .map((f) => RemoteSharedFolder(id: f.id!, name: f.name ?? ''))
        .toList();
  }

  @override
  Future<String?> readFile(String folderId, String fileName) async {
    final api = _requireApi();
    final q = "name = '$fileName' and '$folderId' in parents and trashed = false";
    final list = await api.files.list(q: q, $fields: 'files(id)');
    if (list.files == null || list.files!.isEmpty) return null;

    final fileId = list.files!.first.id!;
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> bytes = [];
    await media.stream.forEach((chunk) => bytes.addAll(chunk));
    return utf8.decode(bytes);
  }

  @override
  Future<void> writeFile(String folderId, String fileName, String content) async {
    final api = _requireApi();
    final q = "name = '$fileName' and '$folderId' in parents and trashed = false";
    final list = await api.files.list(q: q, $fields: 'files(id)');
    final bytes = utf8.encode(content);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
    );

    if (list.files != null && list.files!.isNotEmpty) {
      await api.files.update(
        drive.File(),
        list.files!.first.id!,
        uploadMedia: media,
      );
    } else {
      final newFile = drive.File()
        ..name = fileName
        ..parents = [folderId];
      await api.files.create(newFile, uploadMedia: media);
    }
  }

  @override
  Future<String> createSharedFolder(String eventId) async {
    final api = _requireApi();
    final rootId = await _getOrCreateRootSharedFolder();

    final q = "name = '$eventId' and '$rootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final list = await api.files.list(q: q, $fields: 'files(id)');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = drive.File()
      ..name = eventId
      ..parents = [rootId]
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  @override
  Future<RemotePermission> inviteCollaborator(String folderId, String email) async {
    final api = _requireApi();
    final permission = drive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = email;

    final created = await api.permissions.create(
      permission,
      folderId,
      sendNotificationEmail: true,
    );
    return RemotePermission(
      id: created.id ?? '',
      emailAddress: created.emailAddress ?? email,
      displayName: created.displayName,
      role: created.role ?? 'writer',
    );
  }

  @override
  Future<void> revokeCollaborator(String folderId, String permissionId) async {
    final api = _requireApi();
    await api.permissions.delete(folderId, permissionId);
  }

  @override
  Future<List<RemotePermission>> listCollaborators(String folderId) async {
    final api = _requireApi();
    final list = await api.permissions.list(
      folderId,
      $fields: 'permissions(id, type, role, emailAddress, displayName)',
    );
    return (list.permissions ?? [])
        .map((p) => RemotePermission(
              id: p.id ?? '',
              emailAddress: p.emailAddress,
              displayName: p.displayName,
              role: p.role ?? 'writer',
            ))
        .toList();
  }

  @override
  Future<void> unshareFolder(String folderId) async {
    final api = _requireApi();
    final file = drive.File()..trashed = true;
    await api.files.update(file, folderId);
  }
}
