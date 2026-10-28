import 'dart:convert';

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../../../core/logging/app_logger.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../data/event_repository.dart';
import 'event.dart';
import 'shared_event_transport.dart';

final _log = AppLogger('SharedEventSync');

/// Representation of an isolated Shared Slice containing only public event definitions,
/// assigned member profiles (id + displayName only), and matching sessions.
class SharedSlice {
  static const String sharedEventFileName = 'shared_event.json';
  static const String sharedRosterFileName = 'shared_roster.json';
  static const String sharedSessionsFileName = 'shared_sessions.json';

  final String sharedEventJson;
  final String sharedRosterJson;
  final String sharedSessionsJson;

  const SharedSlice({
    required this.sharedEventJson,
    required this.sharedRosterJson,
    required this.sharedSessionsJson,
  });

  /// Generates a SharedSlice from domain models.
  static SharedSlice generate({
    required Event event,
    required List<Member> allMembers,
    required List<Session> sessions,
  }) {
    // 1. Shared Event JSON (public fields only)
    final eventMap = {
      'id': event.id,
      'title': event.title,
      'time': '${event.time.hour}:${event.time.minute}',
      'frequency': event.frequency,
      'oneTimeDate': event.oneTimeDate?.toIso8601String(),
      'repeatingDays': event.repeatingDays,
      'memberIds': event.memberIds,
      if (event.defaultAttendanceStartMode != null)
        'defaultAttendanceStartMode': event.defaultAttendanceStartMode!.name,
      if (event.rosterGrouping != null)
        'rosterGrouping': event.rosterGrouping!.name,
      if (event.markingMode != null) 'markingMode': event.markingMode!.name,
      'createdAt': event.createdAt.toIso8601String(),
      'updatedAt': event.updatedAt.toIso8601String(),
    };

    // 2. Shared Roster JSON (only assigned members, stripped of private notes / details)
    final assignedIds = event.memberIds.toSet();
    final rosterList = allMembers
        .where((m) => assignedIds.contains(m.id) && m.deletedAt == null)
        .map((m) => {
              'id': m.id,
              'displayName': m.displayName,
            })
        .toList();

    // 3. Shared Sessions JSON (filtered to event)
    final eventSessions = sessions
        .where((s) {
          if (s.eventId != null && s.eventId!.isNotEmpty) {
            return s.eventId == event.id;
          }
          return s.title.trim() == event.title.trim();
        })
        .map((s) => s.toJson())
        .toList();

    return SharedSlice(
      sharedEventJson: jsonEncode(eventMap),
      sharedRosterJson: jsonEncode(rosterList),
      sharedSessionsJson: jsonEncode(eventSessions),
    );
  }

  /// Merges two records according to presence precedence semantics:
  /// - Present/Late takes precedence over Absent regardless of timestamp.
  /// - If both are Present/Late (or both Absent), conflicts are resolved using the latest recordedAt.
  static SessionRecord mergeRecords(SessionRecord a, SessionRecord b) {
    final aIsPresent = a.status == AttendanceStatus.present;
    final bIsPresent = b.status == AttendanceStatus.present;

    if (aIsPresent && !bIsPresent) return a;
    if (!aIsPresent && bIsPresent) return b;

    // Both are present (or both are absent): latest recordedAt wins
    if (b.recordedAt.isAfter(a.recordedAt)) {
      return b;
    }
    return a;
  }

  /// Merges local and remote session lists by applying presence precedence to records.
  static List<Session> mergeSessionLists(
    List<Session> localSessions,
    List<Session> remoteSessions,
  ) {
    final Map<String, Session> merged = {
      for (final s in localSessions) s.id: s,
    };

    for (final remote in remoteSessions) {
      if (!merged.containsKey(remote.id)) {
        merged[remote.id] = remote;
      } else {
        final local = merged[remote.id]!;
        final recordMap = <String, SessionRecord>{};

        // Key records by memberId, or by attendee name if guest (null memberId)
        String recordKey(SessionRecord r) =>
            r.memberId ?? 'guest:${r.attendee}';

        for (final r in local.records) {
          recordMap[recordKey(r)] = r;
        }

        for (final r in remote.records) {
          final key = recordKey(r);
          if (recordMap.containsKey(key)) {
            recordMap[key] = mergeRecords(recordMap[key]!, r);
          } else {
            recordMap[key] = r;
          }
        }

        final latestUpdatedAt = remote.updatedAt.isAfter(local.updatedAt)
            ? remote.updatedAt
            : local.updatedAt;

        merged[remote.id] = local.copyWith(
          records: recordMap.values.toList(),
          updatedAt: latestUpdatedAt,
          currentVersion: (local.currentVersion > remote.currentVersion
                  ? local.currentVersion
                  : remote.currentVersion) +
              1,
        );
      }
    }

    return merged.values.toList();
  }
}

/// Interface for Shared Event Synchronization.
abstract class SharedEventSync {
  factory SharedEventSync({
    required SharedEventRemoteTransport transport,
    required EventRepository eventRepository,
    required AttendanceRepository attendanceRepository,
    required SessionRepository sessionRepository,
  }) = SharedEventSyncCoordinator;

  /// Discovers all shared event folders and ingests/updates them locally.
  Future<void> syncSharedEvents();

  /// Syncs an individual shared event bi-directionally with remote storage.
  Future<void> syncSharedEvent(Event event);

  /// Publishes a local event to remote storage, creating the folder and slice.
  Future<String> publishSharedEvent(Event event);

  /// Unshares an event by trashing its remote folder and marking it unshared.
  Future<void> unshareEvent(Event event);

  /// Invites a collaborator by email.
  Future<RemotePermission> inviteCollaborator(String folderId, String email);

  /// Revokes a collaborator permission.
  Future<void> revokeCollaborator(String folderId, String permissionId);

  /// Lists collaborators for a folder.
  Future<List<RemotePermission>> listCollaborators(String folderId);
}

/// Implementation of [SharedEventSync] coordinating the transport seam and repositories.
class SharedEventSyncCoordinator implements SharedEventSync {
  final SharedEventRemoteTransport _transport;
  final EventRepository _eventRepo;
  final AttendanceRepository _attendanceRepo;
  final SessionRepository _sessionRepo;

  SharedEventSyncCoordinator({
    required SharedEventRemoteTransport transport,
    required EventRepository eventRepository,
    required AttendanceRepository attendanceRepository,
    required SessionRepository sessionRepository,
  })  : _transport = transport,
        _eventRepo = eventRepository,
        _attendanceRepo = attendanceRepository,
        _sessionRepo = sessionRepository;

  @override
  Future<void> syncSharedEvents() async {
    try {
      final sharedFolders = await _transport.discoverSharedFolders();
      final validFolders =
          sharedFolders.where((folder) => folder.id.isNotEmpty);
      await Future.wait(validFolders.map(_ingestSharedFolder));
    } catch (e, st) {
      _log.warning('Error discovering shared events', e, st);
    }
  }

  Future<void> _ingestSharedFolder(RemoteSharedFolder folder) async {
    try {
      final eventJson =
          await _transport.readFile(folder.id, SharedSlice.sharedEventFileName);
      final rosterJson = await _transport.readFile(
          folder.id, SharedSlice.sharedRosterFileName);
      final sessionsJson = await _transport.readFile(
          folder.id, SharedSlice.sharedSessionsFileName);

      if (eventJson == null || rosterJson == null) return;

      final eventMap = jsonDecode(eventJson) as Map<String, dynamic>;
      final rosterList = jsonDecode(rosterJson) as List<dynamic>;
      final sessionsList = (sessionsJson != null
          ? jsonDecode(sessionsJson)
          : <dynamic>[]) as List<dynamic>;

      final parsedEvent = Event.fromJson(eventMap).copyWith(
        isShared: true,
        sharedFolderId: folder.id,
        isReadOnly: true,
      );

      // Save or update event
      final existingEvent = await _eventRepo.findEventById(parsedEvent.id);
      if (existingEvent == null) {
        await _eventRepo.createEvent(parsedEvent);
      } else {
        await _eventRepo.updateEvent(parsedEvent);
      }

      // Ingest members into attendance repository
      final families = await _attendanceRepo.fetchFamilies();
      final familyName = '${parsedEvent.title} Roster';
      Family? sharedFamily = families.firstWhere(
        (f) => f.displayName == familyName,
        orElse: () => Family(id: '', displayName: familyName, members: []),
      );

      if (sharedFamily.id.isEmpty) {
        sharedFamily = await _attendanceRepo.addFamily(familyName);
      }

      for (final mJson in rosterList) {
        final mId = mJson['id'] as String;
        final mName = mJson['displayName'] as String;
        final existingMember = sharedFamily.members.any((m) => m.id == mId);
        if (!existingMember) {
          await _attendanceRepo.addMember(
            sharedFamily.id,
            Member(id: mId, displayName: mName),
          );
        }
      }

      // Merge sessions
      final remoteSessions = sessionsList
          .map((s) => Session.fromJson(s as Map<String, dynamic>))
          .toList();
      final localSessions = (await _sessionRepo.loadSessions())
          .where((s) => s.eventId == parsedEvent.id)
          .toList();

      final mergedSessions =
          SharedSlice.mergeSessionLists(localSessions, remoteSessions);
      for (final session in mergedSessions) {
        final localExisting = await _sessionRepo.findSessionById(session.id);
        if (localExisting == null) {
          await _sessionRepo.createSession(
            title: session.title,
            eventId: session.eventId,
            sessionDate: session.sessionDate,
            actor: session.createdBy,
            records: session.records,
          );
        } else {
          await _sessionRepo.saveSnapshot(session, actor: 'Sync');
        }
      }
    } catch (e, st) {
      _log.warning('Error ingesting shared folder ${folder.id}', e, st);
    }
  }

  @override
  Future<void> syncSharedEvent(Event event) async {
    final folderId = event.sharedFolderId;
    if (folderId == null) return;

    final eventJson =
        await _transport.readFile(folderId, SharedSlice.sharedEventFileName);
    final rosterJson =
        await _transport.readFile(folderId, SharedSlice.sharedRosterFileName);
    final sessionsJson =
        await _transport.readFile(folderId, SharedSlice.sharedSessionsFileName);

    if (eventJson == null && rosterJson == null && sessionsJson == null) return;

    final remoteSessions = sessionsJson != null
        ? (jsonDecode(sessionsJson) as List<dynamic>)
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList()
        : <Session>[];

    final localSessions = (await _sessionRepo.loadSessions())
        .where((s) => s.eventId == event.id)
        .toList();

    final mergedSessions =
        SharedSlice.mergeSessionLists(localSessions, remoteSessions);

    // Update local sessions
    for (final session in mergedSessions) {
      final localExisting = await _sessionRepo.findSessionById(session.id);
      if (localExisting == null) {
        await _sessionRepo.createSession(
          title: session.title,
          eventId: session.eventId,
          sessionDate: session.sessionDate,
          actor: session.createdBy,
          records: session.records,
        );
      } else {
        await _sessionRepo.saveSnapshot(session, actor: 'Sync');
      }
    }

    // Push merged sessions back to cloud
    final families = await _attendanceRepo.fetchFamilies();
    final allMembers = families.expand((f) => f.members).toList();
    final updatedSlice = SharedSlice.generate(
      event: event,
      allMembers: allMembers,
      sessions: mergedSessions,
    );

    await _transport.writeFile(folderId, SharedSlice.sharedEventFileName,
        updatedSlice.sharedEventJson);
    await _transport.writeFile(folderId, SharedSlice.sharedRosterFileName,
        updatedSlice.sharedRosterJson);
    await _transport.writeFile(folderId, SharedSlice.sharedSessionsFileName,
        updatedSlice.sharedSessionsJson);
  }

  @override
  Future<String> publishSharedEvent(Event event) async {
    final folderId = await _transport.createSharedFolder(event.id);
    final families = await _attendanceRepo.fetchFamilies();
    final allMembers = families.expand((f) => f.members).toList();
    final sessions = await _sessionRepo.loadSessions();

    final slice = SharedSlice.generate(
      event: event,
      allMembers: allMembers,
      sessions: sessions,
    );

    await _transport.writeFile(
        folderId, SharedSlice.sharedEventFileName, slice.sharedEventJson);
    await _transport.writeFile(
        folderId, SharedSlice.sharedRosterFileName, slice.sharedRosterJson);
    await _transport.writeFile(
        folderId, SharedSlice.sharedSessionsFileName, slice.sharedSessionsJson);

    final updatedEvent = event.copyWith(
      isShared: true,
      sharedFolderId: folderId,
      updatedAt: DateTime.now(),
    );
    await _eventRepo.updateEvent(updatedEvent);

    return folderId;
  }

  @override
  Future<void> unshareEvent(Event event) async {
    if (event.sharedFolderId != null) {
      await _transport.unshareFolder(event.sharedFolderId!);
    }

    final updatedEvent = event.copyWith(
      isShared: false,
      collaborators: [],
      updatedAt: DateTime.now(),
    );
    await _eventRepo.updateEvent(updatedEvent);
  }

  @override
  Future<RemotePermission> inviteCollaborator(String folderId, String email) {
    return _transport.inviteCollaborator(folderId, email);
  }

  @override
  Future<void> revokeCollaborator(String folderId, String permissionId) {
    return _transport.revokeCollaborator(folderId, permissionId);
  }

  @override
  Future<List<RemotePermission>> listCollaborators(String folderId) {
    return _transport.listCollaborators(folderId);
  }
}
