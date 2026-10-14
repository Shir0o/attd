import '../domain/shared_event_transport.dart';

/// An in-memory fake transport adapter for shared event synchronization.
/// Enables deterministic unit tests without network or Drive API mocks.
class InMemorySharedEventTransport implements SharedEventRemoteTransport {
  final Map<String, Map<String, String>> _folderFiles = {};
  final Map<String, String> _folderNames = {};
  final Map<String, List<RemotePermission>> _permissions = {};
  final Set<String> _sharedWithMeFolders = {};
  final Set<String> _trashedFolders = {};

  int _permIdCounter = 1;

  /// Seeds a folder and optional files/permissions for testing scenarios.
  void seedFolder({
    required String folderId,
    required String name,
    bool isSharedWithMe = true,
    Map<String, String>? files,
    List<RemotePermission>? permissions,
  }) {
    _folderNames[folderId] = name;
    if (isSharedWithMe) {
      _sharedWithMeFolders.add(folderId);
    }
    if (files != null) {
      _folderFiles[folderId] = Map<String, String>.from(files);
    }
    if (permissions != null) {
      _permissions[folderId] = List<RemotePermission>.from(permissions);
    }
  }

  /// Returns the files for a given folder, or null if folder doesn't exist.
  Map<String, String>? getFolderFiles(String folderId) {
    if (_trashedFolders.contains(folderId)) return null;
    return _folderFiles[folderId];
  }

  /// Returns true if the folder has been marked trashed.
  bool isFolderTrashed(String folderId) => _trashedFolders.contains(folderId);

  @override
  Future<List<RemoteSharedFolder>> discoverSharedFolders() async {
    return _sharedWithMeFolders
        .where((id) => !_trashedFolders.contains(id))
        .map((id) => RemoteSharedFolder(id: id, name: _folderNames[id] ?? id))
        .toList();
  }

  @override
  Future<String?> readFile(String folderId, String fileName) async {
    if (_trashedFolders.contains(folderId)) return null;
    return _folderFiles[folderId]?[fileName];
  }

  @override
  Future<void> writeFile(String folderId, String fileName, String content) async {
    if (_trashedFolders.contains(folderId)) return;
    final files = _folderFiles.putIfAbsent(folderId, () => <String, String>{});
    files[fileName] = content;
  }

  @override
  Future<String> createSharedFolder(String eventId) async {
    final folderId = 'folder-$eventId';
    _folderNames[folderId] = eventId;
    _folderFiles.putIfAbsent(folderId, () => <String, String>{});
    return folderId;
  }

  @override
  Future<RemotePermission> inviteCollaborator(String folderId, String email) async {
    final perm = RemotePermission(
      id: 'perm-${_permIdCounter++}',
      emailAddress: email,
      displayName: email.split('@').first,
      role: 'writer',
    );
    final perms = _permissions.putIfAbsent(folderId, () => <RemotePermission>[]);
    perms.add(perm);
    return perm;
  }

  @override
  Future<void> revokeCollaborator(String folderId, String permissionId) async {
    _permissions[folderId]?.removeWhere((p) => p.id == permissionId);
  }

  @override
  Future<List<RemotePermission>> listCollaborators(String folderId) async {
    return List<RemotePermission>.unmodifiable(
      _permissions[folderId] ?? const <RemotePermission>[],
    );
  }

  @override
  Future<void> unshareFolder(String folderId) async {
    _trashedFolders.add(folderId);
  }
}
