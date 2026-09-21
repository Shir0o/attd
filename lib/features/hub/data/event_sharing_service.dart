import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../domain/event.dart';
import 'event_repository.dart';

class SharedSlice {
  final String sharedEventJson;
  final String sharedRosterJson;
  final String sharedSessionsJson;

  const SharedSlice({
    required this.sharedEventJson,
    required this.sharedRosterJson,
    required this.sharedSessionsJson,
  });
}

class EventSharingService {
  EventSharingService({
    required drive.DriveApi? Function() driveApiProvider,
  }) : _driveApiProvider = driveApiProvider;

  final drive.DriveApi? Function() _driveApiProvider;

  static const String rootSharedFolderName = 'Attendance Tracker - Shared Events';
  static const String sharedEventFileName = 'shared_event.json';
  static const String sharedRosterFileName = 'shared_roster.json';
  static const String sharedSessionsFileName = 'shared_sessions.json';

  drive.DriveApi? get driveApi => _driveApiProvider();

  static SharedSlice generateSharedSlice({
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
    final eventSessions = sessions.where((s) {
      if (s.eventId != null && s.eventId!.isNotEmpty) {
        return s.eventId == event.id;
      }
      return s.title.trim() == event.title.trim();
    }).map((s) => s.toJson()).toList();

    return SharedSlice(
      sharedEventJson: jsonEncode(eventMap),
      sharedRosterJson: jsonEncode(rosterList),
      sharedSessionsJson: jsonEncode(eventSessions),
    );
  }

  /// Merges two records according to presence precedence semantics:
  /// - Present/Late takes precedence over Absent regardless of timestamp.
  /// - If both are Present/Late, conflicts are resolved using the latest recordedAt.
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
        String recordKey(SessionRecord r) => r.memberId ?? 'guest:${r.attendee}';

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

  Future<String> _getOrCreateRootSharedFolder() async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

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

  Future<String> createSharedEventFolder(Event event) async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    final rootId = await _getOrCreateRootSharedFolder();

    final q = "name = '${event.id}' and '$rootId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final list = await api.files.list(q: q, $fields: 'files(id)');
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    final folder = drive.File()
      ..name = event.id
      ..parents = [rootId]
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
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
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    await api.permissions.delete(folderId, permissionId);
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
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    final file = drive.File()..trashed = true;
    await api.files.update(file, folderId);
  }

  Future<void> uploadSharedSlice(String folderId, SharedSlice slice) async {
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    Future<void> putFile(String name, String content) async {
      final q = "name = '$name' and '$folderId' in parents and trashed = false";
      final list = await api.files.list(q: q, $fields: 'files(id)');
      final media = drive.Media(
        Stream.value(utf8.encode(content)),
        utf8.encode(content).length,
      );

      if (list.files != null && list.files!.isNotEmpty) {
        await api.files.update(
          drive.File(),
          list.files!.first.id!,
          uploadMedia: media,
        );
      } else {
        final newFile = drive.File()
          ..name = name
          ..parents = [folderId];
        await api.files.create(newFile, uploadMedia: media);
      }
    }

    await putFile(sharedEventFileName, slice.sharedEventJson);
    await putFile(sharedRosterFileName, slice.sharedRosterJson);
    await putFile(sharedSessionsFileName, slice.sharedSessionsJson);
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
    final api = driveApi;
    if (api == null) throw StateError('DriveApi not initialized');

    Future<String?> getFileContent(String name) async {
      final q = "name = '$name' and '$folderId' in parents and trashed = false";
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

    final eventJson = await getFileContent(sharedEventFileName);
    final rosterJson = await getFileContent(sharedRosterFileName);
    final sessionsJson = await getFileContent(sharedSessionsFileName);

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
    final api = driveApi;
    if (api == null) return;

    try {
      final sharedFolders = await discoverSharedEventFolders();
      for (final folder in sharedFolders) {
        if (folder.id == null) continue;
        final slice = await downloadSharedSlice(folder.id!);
        if (slice == null) continue;

        final eventMap = jsonDecode(slice.sharedEventJson) as Map<String, dynamic>;
        final rosterList = jsonDecode(slice.sharedRosterJson) as List<dynamic>;
        final sessionsList = jsonDecode(slice.sharedSessionsJson) as List<dynamic>;

        final parsedEvent = Event.fromJson(eventMap).copyWith(
          isShared: true,
          sharedFolderId: folder.id,
          isReadOnly: true,
        );

        // Save or update event
        final existingEvent = await eventRepo.findEventById(parsedEvent.id);
        if (existingEvent == null) {
          await eventRepo.createEvent(parsedEvent);
        } else {
          await eventRepo.updateEvent(parsedEvent);
        }

        // Ingest members into attendance repository
        final families = await attendanceRepo.fetchFamilies();
        final familyName = '${parsedEvent.title} Roster';
        Family? sharedFamily = families.firstWhere(
          (f) => f.displayName == familyName,
          orElse: () => Family(id: '', displayName: familyName, members: []),
        );

        if (sharedFamily.id.isEmpty) {
          sharedFamily = await attendanceRepo.addFamily(familyName);
        }

        for (final mJson in rosterList) {
          final mId = mJson['id'] as String;
          final mName = mJson['displayName'] as String;
          final existingMember = sharedFamily.members.any((m) => m.id == mId);
          if (!existingMember) {
            await attendanceRepo.addMember(
              sharedFamily.id,
              Member(id: mId, displayName: mName),
            );
          }
        }

        // Merge sessions
        final remoteSessions = sessionsList
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList();
        final localSessions = (await sessionRepo.loadSessions())
            .where((s) => s.eventId == parsedEvent.id)
            .toList();

        final mergedSessions = mergeSessionLists(localSessions, remoteSessions);
        for (final session in mergedSessions) {
          final localExisting = await sessionRepo.findSessionById(session.id);
          if (localExisting == null) {
            await sessionRepo.createSession(
              title: session.title,
              eventId: session.eventId,
              sessionDate: session.sessionDate,
              actor: session.createdBy,
              records: session.records,
            );
          } else {
            await sessionRepo.saveSnapshot(session, actor: 'Sync');
          }
        }
      }
    } catch (e) {
      debugPrint('Error discovering shared events: $e');
    }
  }

  /// Syncs an individual shared event between local repository and Google Drive.
  Future<void> syncSharedEvent({
    required Event event,
    required AttendanceRepository attendanceRepo,
    required SessionRepository sessionRepo,
  }) async {
    final folderId = event.sharedFolderId;
    if (folderId == null) return;

    final slice = await downloadSharedSlice(folderId);
    if (slice == null) return;

    final remoteSessions = (jsonDecode(slice.sharedSessionsJson) as List<dynamic>)
        .map((s) => Session.fromJson(s as Map<String, dynamic>))
        .toList();

    final localSessions = (await sessionRepo.loadSessions())
        .where((s) => s.eventId == event.id)
        .toList();

    final mergedSessions = mergeSessionLists(localSessions, remoteSessions);

    // Update local sessions
    for (final session in mergedSessions) {
      final localExisting = await sessionRepo.findSessionById(session.id);
      if (localExisting == null) {
        await sessionRepo.createSession(
          title: session.title,
          eventId: session.eventId,
          sessionDate: session.sessionDate,
          actor: session.createdBy,
          records: session.records,
        );
      } else {
        await sessionRepo.saveSnapshot(session, actor: 'Sync');
      }
    }

    // If owner or writer, push merged sessions back to cloud
    final families = await attendanceRepo.fetchFamilies();
    final allMembers = families.expand((f) => f.members).toList();
    final updatedSlice = generateSharedSlice(
      event: event,
      allMembers: allMembers,
      sessions: mergedSessions,
    );
    await uploadSharedSlice(folderId, updatedSlice);
  }
}
