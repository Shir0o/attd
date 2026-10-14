/// Represents a collaborator permission on a remote shared event folder.
class RemotePermission {
  final String id;
  final String? emailAddress;
  final String? displayName;
  final String role;

  const RemotePermission({
    required this.id,
    this.emailAddress,
    this.displayName,
    this.role = 'writer',
  });
}

/// Represents a remote shared event folder discovered from cloud storage.
class RemoteSharedFolder {
  final String id;
  final String name;

  const RemoteSharedFolder({
    required this.id,
    required this.name,
  });
}

/// Port defining remote transport operations for shared events.
/// Decouples event synchronization domain logic from specific cloud storage APIs.
abstract class SharedEventRemoteTransport {
  /// Discovers remote folders representing shared events shared with the current user.
  Future<List<RemoteSharedFolder>> discoverSharedFolders();

  /// Reads a file from a shared event folder. Returns null if not found.
  Future<String?> readFile(String folderId, String fileName);

  /// Writes a file into a shared event folder (creating or updating it).
  Future<void> writeFile(String folderId, String fileName, String content);

  /// Creates a dedicated folder for the shared event and returns its folder ID.
  Future<String> createSharedFolder(String eventId);

  /// Invites a collaborator by email with writer permissions.
  Future<RemotePermission> inviteCollaborator(String folderId, String email);

  /// Revokes a collaborator permission by permission ID.
  Future<void> revokeCollaborator(String folderId, String permissionId);

  /// Lists collaborator permissions for a shared event folder.
  Future<List<RemotePermission>> listCollaborators(String folderId);

  /// Unshares/trashes the shared event folder.
  Future<void> unshareFolder(String folderId);
}
