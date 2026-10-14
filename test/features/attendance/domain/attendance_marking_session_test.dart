import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/domain/attendance_marking_session.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepository implements SessionRepository {
  List<Session> savedSnapshots = [];
  final List<String> deletedSessionIds = [];
  final List<Completer<void>> pendingSaveCompleters = [];
  bool simulateSlowSaves = false;
  Object? errorToThrow;

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (simulateSlowSaves) {
      final completer = Completer<void>();
      pendingSaveCompleters.add(completer);
      await completer.future;
    }
    savedSnapshots.add(session);
    return session.copyWith(
      currentVersion: session.currentVersion + 1,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    deletedSessionIds.add(sessionId);
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) =>
      throw UnimplementedError();

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) =>
      throw UnimplementedError();

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Session>> streamSessions() => Stream.value([]);
}

class _FakeAttendanceRepository extends AttendanceRepository {
  List<Family> families = [];
  final List<Family> addedFamilies = [];
  final List<({String familyId, Member member})> addedMembers = [];

  @override
  Future<List<Family>> fetchFamilies() async => families;

  @override
  Future<void> saveFamilies(List<Family> updated) async {
    families = updated;
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    final family = Family(
      id: 'fam-${addedFamilies.length + 1}',
      displayName: displayName,
      isAutoSingleton: isAutoSingleton,
      members: const [],
    );
    addedFamilies.add(family);
    families.add(family);
    return family;
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    addedMembers.add((familyId: familyId, member: member));
    final index = families.indexWhere((f) => f.id == familyId);
    if (index >= 0) {
      final updated = families[index].copyWith(
        members: [...families[index].members, member],
      );
      families[index] = updated;
      return updated;
    }
    return Family(id: familyId, displayName: member.displayName, members: [member]);
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
}

class _FakeEventRepository implements EventRepository {
  List<Event> events = [];
  final List<Event> updatedEvents = [];

  @override
  Future<void> createEvent(Event event) async {
    events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    updatedEvents.add(event);
    final index = events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<Event?> findEventById(String eventId) async {
    try {
      return events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Event>> streamEvents() => Stream.value(events);
}

void main() {
  group('AttendanceMarkingSession', () {
    late _FakeSessionRepository sessionRepo;
    late _FakeAttendanceRepository attendanceRepo;
    late _FakeEventRepository eventRepo;
    late Member memberA;
    late Member memberB;
    late Member memberC;
    late Session baseSession;
    late Event baseEvent;
    late List<Family> baseFamilies;

    setUp(() {
      sessionRepo = _FakeSessionRepository();
      attendanceRepo = _FakeAttendanceRepository();
      eventRepo = _FakeEventRepository();

      memberA = Member(id: 'm1', displayName: 'Alice Adams');
      memberB = Member(id: 'm2', displayName: 'Bob Brown');
      memberC = Member(id: 'm3', displayName: 'Charlie Clark');

      baseEvent = Event(
        id: 'event-1',
        title: 'Sunday Service',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        memberIds: ['m1', 'm2'],
        createdAt: DateTime(2026, 1, 1),
      );
      eventRepo.events.add(baseEvent);

      baseFamilies = [
        Family(id: 'fam-a', displayName: 'Adams Family', members: [memberA]),
        Family(id: 'fam-b', displayName: 'Brown Family', members: [memberB]),
      ];
      attendanceRepo.families.addAll(baseFamilies);

      baseSession = Session(
        id: 'session-100',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: DateTime(2026, 10, 14),
        createdBy: 'User',
        createdAt: DateTime(2026, 10, 14, 9, 0),
        updatedAt: DateTime(2026, 10, 14, 9, 0),
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Alice Adams',
            status: AttendanceStatus.present,
            recordedAt: DateTime(2026, 10, 14, 9, 0),
            recordedBy: 'System (Preseed)',
          ),
          SessionRecord(
            memberId: 'm2',
            attendee: 'Bob Brown',
            status: AttendanceStatus.absent,
            recordedAt: DateTime(2026, 10, 14, 9, 0),
            recordedBy: 'System (Preseed)',
          ),
        ],
      );
    });

    test('initializes baseline status and preseed records correctly', () {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        families: baseFamilies,
        event: baseEvent,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );

      expect(markingSession.session.id, 'session-100');
      expect(markingSession.sessionMembers.length, 2);
      expect(markingSession.sessionFamilies.length, 2);
      expect(markingSession.baselineStatus['m1'], AttendanceStatus.present);
      expect(markingSession.baselineStatus['m2'], AttendanceStatus.absent);
      expect(markingSession.baselineFor(memberA), AttendanceStatus.present);
      expect(markingSession.baselineFor(memberB), AttendanceStatus.absent);

      // Preseeded records do not count as user edits
      expect(markingSession.isTouched(memberA), isFalse);
      expect(markingSession.isTouched(memberB), isFalse);
      expect(markingSession.hasUserEdits, isFalse);
      expect(markingSession.canUndo, isFalse);
      expect(markingSession.changedCount, 0);
    });

    test('optimistic marking updates state immediately and enqueues background save', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        families: baseFamilies,
        event: baseEvent,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );

      var notified = false;
      markingSession.addListener(() => notified = true);

      // Optimistic mark
      markingSession.markMember(memberB, AttendanceStatus.present);

      expect(notified, isTrue);
      expect(markingSession.getStatus(memberB), AttendanceStatus.present);
      expect(markingSession.isTouched(memberB), isTrue);
      expect(markingSession.hasUserEdits, isTrue);
      expect(markingSession.isChanged(memberB), isTrue);
      expect(markingSession.changedCount, 1);
      expect(markingSession.canUndo, isTrue);

      // Await pending saves
      await markingSession.drain();
      expect(sessionRepo.savedSnapshots.length, 1);
      expect(
        sessionRepo.savedSnapshots.first.records
            .firstWhere((r) => r.memberId == 'm2')
            .status,
        AttendanceStatus.present,
      );
    });

    test('consecutive marks are serialized strictly in FIFO order', () async {
      sessionRepo.simulateSlowSaves = true;
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      // Rapid swipes without awaiting
      final f1 = markingSession.markMember(memberA, AttendanceStatus.absent);
      final f2 = markingSession.markMember(memberB, AttendanceStatus.present);
      final f3 = markingSession.markMember(memberA, AttendanceStatus.present);

      // Session state is immediately optimistic
      expect(markingSession.getStatus(memberA), AttendanceStatus.present);
      expect(markingSession.getStatus(memberB), AttendanceStatus.present);

      // Yield event loop so the first queued save runs
      await Future<void>.delayed(Duration.zero);
      expect(sessionRepo.pendingSaveCompleters.length, 1);
      sessionRepo.pendingSaveCompleters[0].complete();
      await Future<void>.delayed(Duration.zero);

      expect(sessionRepo.pendingSaveCompleters.length, 2);
      sessionRepo.pendingSaveCompleters[1].complete();
      await Future<void>.delayed(Duration.zero);

      expect(sessionRepo.pendingSaveCompleters.length, 3);
      sessionRepo.pendingSaveCompleters[2].complete();
      await Future<void>.delayed(Duration.zero);

      await Future.wait([f1, f2, f3]);
      expect(sessionRepo.savedSnapshots.length, 3);

      // Verify sequence of saved snapshots
      expect(
        sessionRepo.savedSnapshots[0].records
            .firstWhere((r) => r.memberId == 'm1')
            .status,
        AttendanceStatus.absent,
      );
      expect(
        sessionRepo.savedSnapshots[1].records
            .firstWhere((r) => r.memberId == 'm2')
            .status,
        AttendanceStatus.present,
      );
      expect(
        sessionRepo.savedSnapshots[2].records
            .firstWhere((r) => r.memberId == 'm1')
            .status,
        AttendanceStatus.present,
      );
    });

    test('toggleLate flips isLate without dropping status and resolves both members and guests', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      expect(markingSession.isLate(memberA), isFalse);
      await markingSession.toggleLate(memberA);
      expect(markingSession.isLate(memberA), isTrue);
      expect(markingSession.getStatus(memberA), AttendanceStatus.present);

      await markingSession.toggleLate(memberA);
      expect(markingSession.isLate(memberA), isFalse);

      // Now add a guest and toggle late
      final guest = await markingSession.addGuest('Visitor Dave');
      expect(markingSession.isLate(guest), isFalse);
      await markingSession.toggleLate(guest);
      expect(markingSession.isLate(guest), isTrue);
    });

    test('addGuest records mark with null memberId without modifying Event or Directory', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        event: baseEvent,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );

      final guest = await markingSession.addGuest('Walkin Wendy');
      await markingSession.drain();

      expect(guest.isVisitor, isTrue);
      expect(guest.displayName, 'Walkin Wendy');
      expect(guest.id, isEmpty);

      // Guest added to sessionMembers
      expect(
        markingSession.sessionMembers.any((m) => m.displayName == 'Walkin Wendy'),
        isTrue,
      );

      // Record in session has null memberId
      final guestRecord = markingSession.session.records.firstWhere(
        (r) => r.attendee == 'Walkin Wendy',
      );
      expect(guestRecord.memberId, isNull);
      expect(guestRecord.status, AttendanceStatus.present);

      // Zero calls to attendanceRepository or eventRepository
      expect(attendanceRepo.addedFamilies, isEmpty);
      expect(attendanceRepo.addedMembers, isEmpty);
      expect(eventRepo.updatedEvents, isEmpty);
      expect(baseEvent.memberIds, isNot(contains('')));
    });

    test('addAttendee for regular member creates global directory member and updates event roster', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        event: baseEvent,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );

      final newRegular = await markingSession.addAttendee(
        'David Daniels',
        isPresent: true,
        isGuest: false,
      );
      await markingSession.drain();

      expect(newRegular.isVisitor, isFalse);
      expect(newRegular.displayName, 'David Daniels');
      expect(newRegular.id, isNotEmpty);

      // Created in attendance repo
      expect(attendanceRepo.addedFamilies.length, 1);
      expect(attendanceRepo.addedFamilies.first.displayName, 'David Daniels');
      expect(attendanceRepo.addedMembers.length, 1);
      expect(attendanceRepo.addedMembers.first.member.id, newRegular.id);

      // Added to event roster
      expect(eventRepo.updatedEvents.length, 1);
      expect(eventRepo.updatedEvents.first.memberIds, contains(newRegular.id));
      expect(markingSession.event?.memberIds, contains(newRegular.id));

      // Recorded in session with stable memberId
      final record = markingSession.session.records.firstWhere(
        (r) => r.memberId == newRegular.id,
      );
      expect(record.attendee, 'David Daniels');
      expect(record.status, AttendanceStatus.present);
    });

    test('addAttendee with existingMember ensures member is in event roster', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        event: baseEvent,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );

      // memberC is not yet in baseEvent
      expect(baseEvent.memberIds, isNot(contains(memberC.id)));

      final added = await markingSession.addAttendee(
        memberC.displayName,
        isPresent: true,
        isGuest: false,
        existingMember: memberC,
      );
      await markingSession.drain();

      expect(added.id, memberC.id);
      expect(eventRepo.updatedEvents.length, 1);
      expect(eventRepo.updatedEvents.first.memberIds, contains(memberC.id));

      final record = markingSession.session.records.firstWhere(
        (r) => r.memberId == memberC.id,
      );
      expect(record.status, AttendanceStatus.present);
    });

    test('undo rolls back session to exact prior state and persists restored snapshot', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      expect(markingSession.canUndo, isFalse);
      expect(markingSession.getStatus(memberB), AttendanceStatus.absent);

      // Mark member B present
      await markingSession.markMember(memberB, AttendanceStatus.present);
      expect(markingSession.canUndo, isTrue);
      expect(markingSession.getStatus(memberB), AttendanceStatus.present);

      // Undo
      final restored = await markingSession.undo();
      await markingSession.drain();

      expect(restored, isNotNull);
      expect(markingSession.getStatus(memberB), AttendanceStatus.absent);
      expect(markingSession.canUndo, isFalse);

      // Verifies that a restore snapshot write was persisted
      expect(sessionRepo.savedSnapshots.length, 2);
      expect(
        sessionRepo.savedSnapshots.last.records
            .firstWhere((r) => r.memberId == 'm2')
            .status,
        AttendanceStatus.absent,
      );
    });

    test('markFamily updates all members as a single atomic snapshot', () async {
      final family = Family(
        id: 'fam-ab',
        displayName: 'Test Household',
        members: [memberA, memberB],
      );

      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        families: [family],
        sessionRepository: sessionRepo,
      );

      await markingSession.markFamily(family, true);
      await markingSession.drain();

      expect(sessionRepo.savedSnapshots.length, 1);
      expect(markingSession.getStatus(memberA), AttendanceStatus.present);
      expect(markingSession.getStatus(memberB), AttendanceStatus.present);

      // Undo family mark
      await markingSession.undo();
      await markingSession.drain();

      expect(markingSession.getStatus(memberA), AttendanceStatus.present);
      expect(markingSession.getStatus(memberB), AttendanceStatus.absent);
    });

    test('markAll and resetToBaseline execute atomically', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      await markingSession.markAll([memberA, memberB], present: false);
      expect(markingSession.getStatus(memberA), AttendanceStatus.absent);
      expect(markingSession.getStatus(memberB), AttendanceStatus.absent);
      expect(markingSession.changedCount, 1); // memberA changed from present to absent

      await markingSession.resetToBaseline();
      expect(markingSession.getStatus(memberA), AttendanceStatus.present);
      expect(markingSession.getStatus(memberB), AttendanceStatus.absent);
      expect(markingSession.changedCount, 0);
    });

    test('editMemberName and removeMemberFromSession update records properly', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      await markingSession.editMemberName(memberA, 'Alice Alison');
      expect(
        markingSession.session.records.firstWhere((r) => r.memberId == 'm1').attendee,
        'Alice Alison',
      );

      await markingSession.removeMemberFromSession(memberA);
      expect(
        markingSession.session.records.any((r) => r.memberId == 'm1'),
        isFalse,
      );
      expect(markingSession.session.excludedMemberIds, contains('m1'));
    });

    test('drain and discardSession cleanly drain pending background writes before delete', () async {
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      // Start an un-awaited mark
      markingSession.markMember(memberA, AttendanceStatus.absent);

      // Discard session
      await markingSession.discardSession(actor: 'System (Cleanup)');

      // Verify that save snapshot finished first, and then deleteSession was called
      expect(sessionRepo.savedSnapshots.length, 1);
      expect(sessionRepo.deletedSessionIds, ['session-100']);
    });

    test('save error is captured and broadcast on saveErrors stream without breaking queue', () async {
      sessionRepo.errorToThrow = StateError('Disk full');
      final markingSession = AttendanceMarkingSession(
        session: baseSession,
        baseMembers: [memberA, memberB],
        sessionRepository: sessionRepo,
      );

      Object? receivedError;
      final sub = markingSession.saveErrors.listen((e) => receivedError = e);

      markingSession.markMember(memberA, AttendanceStatus.absent);
      await markingSession.drain();
      await Future<void>.delayed(Duration.zero);

      expect(receivedError, isA<StateError>());
      await sub.cancel();
      markingSession.dispose();
    });
  });
}
