import 'package:googleapis/drive/v3.dart' as drive;

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/member.dart';
import '../domain/event.dart';
import '../domain/shared_event_sync.dart';
import 'event_repository.dart';
import 'google_drive_shared_event_transport.dart';

export '../domain/shared_event_sync.dart' show SharedSlice, SharedEventSync;
export '../domain/shared_event_transport.dart';

class _NoOpEventRepository implements EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Stream<List<Event>> streamEvents() => const Stream.empty();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
  @override
  Future<List<Event>> fetchAllEvents() async => [];
  @override
  Future<void> saveEvents(List<Event> events) async {}
}

class EventSharingService {
  EventSharingService({
    required drive.DriveApi? Function() driveApiProvider,
  })  : _driveApiProvider = driveApiProvider,
        _transport = GoogleDriveSharedEventTransport(driveApiProvider: driveApiProvider);

  final drive.DriveApi? Function() _driveApiProvider;
  final GoogleDriveSharedEventTransport _transport;

  static const String rootSharedFolderName = GoogleDriveSharedEventTransport.rootSharedFolderName;
  static const String sharedEventFileName = SharedSlice.sharedEventFileName;
  static const String sharedRosterFileName = SharedSlice.sharedRosterFileName;
  static const String sharedSessionsFileName = SharedSlice.sharedSessionsFileName;

  drive.DriveApi? get driveApi => _driveApiProvider();

  static SharedSlice generateSharedSlice({
    required Event event,
    required List<Member> allMembers,
    required List<Session> sessions,
  }) =>
      SharedSlice.generate(
        event: event,
        allMembers: allMembers,
        sessions: sessions,
      );

  static SessionRecord mergeRecords(SessionRecord a, SessionRecord b) =>
      SharedSlice.mergeRecords(a, b);

  static List<Session> mergeSessionLists(
    List<Session> localSessions,
    List<Session> remoteSessions,
  ) =>
      SharedSlice.mergeSessionLists(localSessions, remoteSessions);

  Future<String> createSharedEventFolder(Event event) async {
    return _transport.createSharedFolder(event.id);
  }

  Future<drive.Permission> inviteCollaborator(String folderId, String email) async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    final permission = drive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = email;

    return await api.permissions.create(
      permission,
      folderId,
      sendNotificationEmail: true,
    );
  }

  Future<void> revokeCollaborator(String folderId, String permissionId) async {
    await _transport.revokeCollaborator(folderId, permissionId);
  }

  Future<List<drive.Permission>> listCollaborators(String folderId) async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    final list = await api.permissions.list(
      folderId,
      $fields: 'permissions(id, type, role, emailAddress, displayName)',
    );
    return list.permissions ?? [];
  }

  Future<void> unshareEvent(String folderId) async {
    await _transport.unshareFolder(folderId);
  }

  Future<void> uploadSharedSlice(String folderId, SharedSlice slice) async {
    await _transport.writeFile(folderId, sharedEventFileName, slice.sharedEventJson);
    await _transport.writeFile(folderId, sharedRosterFileName, slice.sharedRosterJson);
    await _transport.writeFile(folderId, sharedSessionsFileName, slice.sharedSessionsJson);
  }

  Future<List<drive.File>> discoverSharedEventFolders() async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    final q = "mimeType = 'application/vnd.google-apps.folder' and sharedWithMe = true and trashed = false";
    final list = await api.files.list(
      q: q,
      $fields: 'files(id, name, owners)',
    );
    return list.files ?? [];
  }

  Future<SharedSlice?> downloadSharedSlice(String folderId) async {
    final eventJson = await _transport.readFile(folderId, sharedEventFileName);
    final rosterJson = await _transport.readFile(folderId, sharedRosterFileName);
    final sessionsJson = await _transport.readFile(folderId, sharedSessionsFileName);

    if (eventJson == null || rosterJson == null) {
      return null;
    }

    return SharedSlice(
      sharedEventJson: eventJson,
      sharedRosterJson: rosterJson,
      sharedSessionsJson: sessionsJson ?? '[]',
    );
  }

  /// Discovers folders shared with current user and ingests them into the local repository as read-only events.
  Future<void> discoverAndIngestSharedEvents({
    required EventRepository eventRepo,
    required AttendanceRepository attendanceRepo,
    required SessionRepository sessionRepo,
  }) async {
    if (driveApi == null) return;
    final sync = SharedEventSync(
      transport: _transport,
      eventRepository: eventRepo,
      attendanceRepository: attendanceRepo,
      sessionRepository: sessionRepo,
    );
    await sync.syncSharedEvents();
  }

  /// Syncs an individual shared event between local repository and Google Drive.
  Future<void> syncSharedEvent({
    required Event event,
    required AttendanceRepository attendanceRepo,
    required SessionRepository sessionRepo,
    EventRepository? eventRepo,
  }) async {
    final sync = SharedEventSync(
      transport: _transport,
      eventRepository: eventRepo ?? _NoOpEventRepository(),
      attendanceRepository: attendanceRepo,
      sessionRepository: sessionRepo,
    );
    await sync.syncSharedEvent(event);
  }
}
