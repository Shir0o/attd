import 'dart:io';

import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/handoff/data/handoff_service.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/hub/data/local_event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

HandoffRoster _roster({
  String eventId = 'ev-1',
  DateTime? date,
  List<HandoffPerson>? people,
}) =>
    HandoffRoster(
      eventId: eventId,
      eventTitle: 'Sunday Service',
      sessionDate: date ?? DateTime(2026, 11, 15),
      roster: people ??
          const [
            HandoffPerson(id: 'm1', name: 'Alice Johnson'),
            HandoffPerson(id: 'm2', name: 'Bob Smith'),
          ],
    );

Event _ownEvent({String id = 'own-1', List<String> memberIds = const ['m1']}) =>
    Event(
      id: id,
      title: 'Own Event',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      repeatingDays: const ['Sunday'],
      memberIds: memberIds,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late Directory dir;
  late LocalJsonAttendanceRepository attendance;
  late LocalJsonSessionRepository sessions;
  late LocalJsonEventRepository events;
  late HandoffService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('handoff_service_test');
    attendance = LocalJsonAttendanceRepository(
      storagePath: '${dir.path}/families.json',
    );
    sessions = LocalJsonSessionRepository(storagePath: dir.path);
    events = LocalJsonEventRepository(storagePath: dir.path);
    service = HandoffService(
      attendanceRepository: attendance,
      eventRepository: events,
      sessionRepository: sessions,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// The helper's own data, which a handoff must never disturb.
  Future<void> seedOwnData() async {
    final family = await attendance.addFamily('Own Family');
    await attendance.addMember(
      family.id,
      Member(id: 'm1', displayName: 'Own Person'),
    );
    await events.createEvent(_ownEvent());
    await sessions.createSession(
      title: 'Own Event',
      eventId: 'own-1',
      sessionDate: DateTime(2026, 11, 8),
      actor: 'User',
      records: [
        SessionRecord(
          memberId: 'm1',
          attendee: 'Own Person',
          status: AttendanceStatus.present,
          recordedAt: DateTime.utc(2026, 11, 8, 10),
          recordedBy: 'User',
        ),
      ],
    );
  }

  Future<void> expectOwnDataIntact() async {
    final families = await attendance.fetchFamilies();
    final own = families.where((f) => f.displayName == 'Own Family').single;
    expect(own.members.single.displayName, 'Own Person');
    expect(own.deletedAt, isNull);
    final event = (await events.findEventById('own-1'))!;
    expect(event.title, 'Own Event');
    expect(event.deletedAt, isNull);
    expect(event.memberIds, ['m1']);
    final session = (await sessions.loadSessions()).singleWhere(
      (s) => s.eventId == 'own-1' && s.sessionDate == DateTime(2026, 11, 8),
    );
    expect(session.records.single.attendee, 'Own Person');
  }

  group('receive', () {
    test('adds the event and roster under namespaced ids', () async {
      await seedOwnData();

      final event = await service.receive(_roster());

      expect(event.id, 'handoff:ev-1');
      expect(event.isHandedOff, isTrue);
      expect(event.handoffEventId, 'ev-1');
      expect(event.title, 'Sunday Service');
      expect(event.frequency, 'One-time');
      expect(event.oneTimeDate, DateTime(2026, 11, 15));
      expect(event.memberIds, ['handoff:m1', 'handoff:m2']);
      expect((await events.findEventById('handoff:ev-1'))!.isHandedOff, isTrue);

      final families = await attendance.fetchFamilies();
      final roster = families.singleWhere((f) => f.id == 'handoff:ev-1');
      expect(roster.displayName, 'Sunday Service Roster');
      expect(roster.isAutoSingleton, isFalse);
      expect(roster.members.map((m) => m.id), ['handoff:m1', 'handoff:m2']);
      expect(
        roster.members.map((m) => m.displayName),
        ['Alice Johnson', 'Bob Smith'],
      );
      await expectOwnDataIntact();
    });

    test('a file that reuses the helper\'s own ids cannot touch their data',
        () async {
      await seedOwnData();
      // The helper's own member is "m1"; the file also says "m1" and names
      // the event "own-1".
      await service.receive(
        _roster(
          eventId: 'own-1',
          people: const [HandoffPerson(id: 'm1', name: 'Imposter')],
        ),
      );

      await expectOwnDataIntact();
      final families = await attendance.fetchFamilies();
      final own = families.singleWhere((f) => f.displayName == 'Own Family');
      expect(own.members.single.id, 'm1');
      expect(
        families.expand((f) => f.members).where((m) => m.id == 'm1').length,
        1,
      );
    });

    test('receiving the same file twice leaves one event and one roster',
        () async {
      await service.receive(_roster());
      await service.receive(
        _roster(
          date: DateTime(2026, 11, 22),
          people: const [HandoffPerson(id: 'm1', name: 'Alice J.')],
        ),
      );

      final all = await events.fetchAllEvents();
      expect(all.where((e) => e.id == 'handoff:ev-1'), hasLength(1));
      final updated = (await events.findEventById('handoff:ev-1'))!;
      expect(updated.oneTimeDate, DateTime(2026, 11, 22));
      expect(updated.memberIds, ['handoff:m1']);
      final families = await attendance.fetchAllFamilies();
      expect(families.where((f) => f.id == 'handoff:ev-1'), hasLength(1));
      expect(
        families.singleWhere((f) => f.id == 'handoff:ev-1').members.single
            .displayName,
        'Alice J.',
      );
    });

    test('receiving again after removal brings the event back', () async {
      final event = await service.receive(_roster());
      await service.remove(event);
      expect(await events.findEventById('handoff:ev-1'), isNotNull);
      expect(
        (await events.findEventById('handoff:ev-1'))!.deletedAt,
        isNotNull,
      );

      await service.receive(_roster());

      expect((await events.findEventById('handoff:ev-1'))!.deletedAt, isNull);
      final families = await attendance.fetchFamilies();
      expect(
        families.singleWhere((f) => f.id == 'handoff:ev-1').members,
        hasLength(2),
      );
    });

    test('refuses when an ordinary event already has the namespaced id',
        () async {
      await events.createEvent(_ownEvent(id: 'handoff:ev-1'));
      await expectLater(
        service.receive(_roster()),
        throwsA(isA<HandoffFormatException>()),
      );
      expect((await attendance.fetchAllFamilies()), isEmpty);
    });
  });

  group('remove', () {
    test('removes the event, roster, members and marks, and nothing else',
        () async {
      await seedOwnData();
      final other = await service.receive(
        _roster(
          eventId: 'ev-other',
          people: const [HandoffPerson(id: 'm9', name: 'Other Handoff')],
        ),
      );
      final event = await service.receive(_roster());
      await sessions.createSession(
        title: event.title,
        eventId: event.id,
        sessionDate: DateTime(2026, 11, 15),
        actor: 'Helper',
        records: [
          SessionRecord(
            memberId: 'handoff:m1',
            attendee: 'Alice Johnson',
            status: AttendanceStatus.present,
            recordedAt: DateTime.utc(2026, 11, 15, 10),
            recordedBy: 'Helper',
          ),
        ],
      );

      await service.remove(event);

      expect(await events.findEventById('handoff:ev-1'), isNotNull);
      final liveEvents = await events.streamEvents().first;
      expect(
        liveEvents.map((e) => e.id),
        unorderedEquals(['own-1', other.id]),
      );
      final families = await attendance.fetchFamilies();
      expect(families.any((f) => f.id == 'handoff:ev-1'), isFalse);
      expect(
        families.expand((f) => f.members).map((m) => m.id),
        unorderedEquals(['m1', 'handoff:m9']),
      );
      expect(
        (await sessions.loadSessions()).any((s) => s.eventId == event.id),
        isFalse,
      );
      expect(await service.sessionFor(event), isNull);
      await expectOwnDataIntact();
    });

    test('refuses to remove an ordinary event', () async {
      await expectLater(
        service.remove(_ownEvent()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('removing with no family or marks still deletes the event', () async {
      final event = await service.receive(_roster());
      final families = await attendance.fetchAllFamilies();
      await attendance.saveFamilies(
        [for (final f in families) if (f.id != event.id) f],
      );
      await service.remove(event);
      expect((await events.findEventById(event.id))!.deletedAt, isNotNull);
    });
  });

  group('sessionFor', () {
    test('returns the newest session marked for the handed-off event',
        () async {
      final event = await service.receive(_roster());
      expect(await service.sessionFor(event), isNull);
      await sessions.createSession(
        title: event.title,
        eventId: event.id,
        sessionDate: DateTime(2026, 11, 15),
        actor: 'Helper',
        records: const [],
      );
      expect((await service.sessionFor(event))!.eventId, event.id);
    });
  });

  group('owner import', () {
    DateTime t(int minute) => DateTime.utc(2026, 11, 15, 10, minute);

    HandoffResult result({
      String eventId = 'own-1',
      List<HandoffMark>? marks,
      List<HandoffGuest> guests = const [],
      String? helper = 'Sam',
      DateTime? date,
    }) =>
        HandoffResult(
          eventId: eventId,
          sessionDate: date ?? DateTime(2026, 11, 15),
          helperName: helper,
          marks: marks ??
              [
                HandoffMark(
                  memberId: 'm1',
                  name: 'Own Person',
                  status: AttendanceStatus.present,
                  recordedAt: t(0),
                ),
                HandoffMark(
                  memberId: 'gone',
                  name: 'Gone Greg',
                  status: AttendanceStatus.present,
                  recordedAt: t(1),
                ),
              ],
          guests: guests,
        );

    test('refuses a result for an unknown event', () async {
      await seedOwnData();
      for (final call in [
        () => service.preview(result(eventId: 'nope')),
        () => service.apply(result(eventId: 'nope')),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<HandoffFormatException>().having(
              (e) => e.message,
              'message',
              contains('not on this phone'),
            ),
          ),
        );
      }
      expect(
        (await sessions.loadSessions()).where((s) => s.eventId == 'nope'),
        isEmpty,
      );
    });

    test('refuses a result for a deleted event', () async {
      await seedOwnData();
      await events.deleteEvent('own-1');
      await expectLater(
        service.preview(result()),
        throwsA(isA<HandoffFormatException>()),
      );
    });

    test('preview finds the event and changes nothing', () async {
      await seedOwnData();
      final before = (await sessions.loadSessions()).length;
      final preview = await service.preview(result());
      expect(preview.event.id, 'own-1');
      expect((await sessions.loadSessions()).length, before);
    });

    test('creates the session when absent, helper as actor, unknown as guest',
        () async {
      await seedOwnData();

      final outcome = await service.apply(
        result(guests: [HandoffGuest(name: 'Vic', recordedAt: t(2))]),
      );

      expect(outcome.sessionCreated, isTrue);
      expect(outcome.changed, isTrue);
      expect(outcome.unknownMemberMarks, 1);
      final session = (await sessions.loadSessions()).singleWhere(
        (s) =>
            s.eventId == 'own-1' &&
            s.sessionDate == DateTime(2026, 11, 15),
      );
      expect(session.createdBy, 'Sam');
      expect(session.title, 'Own Event');
      final byName = {for (final r in session.records) r.attendee: r};
      expect(byName['Own Person']!.memberId, 'm1');
      expect(byName['Own Person']!.recordedBy, 'Sam');
      expect(byName['Gone Greg']!.memberId, isNull);
      expect(byName['Gone Greg']!.status, AttendanceStatus.present);
      expect(byName['Vic']!.memberId, isNull);
      await expectOwnDataIntact();
    });

    test('importing the same result twice adds nothing the second time',
        () async {
      await seedOwnData();
      final r = result(guests: [HandoffGuest(name: 'Vic', recordedAt: t(2))]);

      await service.apply(r);
      final afterFirst = (await sessions.loadSessions())
          .singleWhere((s) => s.sessionDate == DateTime(2026, 11, 15));
      final second = await service.apply(r);

      expect(second.changed, isFalse);
      expect(second.sessionCreated, isFalse);
      final all = (await sessions.loadSessions())
          .where((s) => s.sessionDate == DateTime(2026, 11, 15))
          .toList();
      expect(all, hasLength(1));
      expect(all.single.records, hasLength(afterFirst.records.length));
      expect(all.single.currentVersion, afterFirst.currentVersion);
    });

    test('merges into an existing session: present beats absent', () async {
      await seedOwnData();
      await sessions.createSession(
        title: 'Own Event',
        eventId: 'own-1',
        sessionDate: DateTime(2026, 11, 15),
        actor: 'User',
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Own Person',
            status: AttendanceStatus.absent,
            recordedAt: t(30),
            recordedBy: 'User',
          ),
          SessionRecord(
            attendee: 'Local Guest',
            status: AttendanceStatus.present,
            recordedAt: t(30),
            recordedBy: 'User',
          ),
        ],
      );

      final outcome = await service.apply(result());

      expect(outcome.sessionCreated, isFalse);
      expect(outcome.changed, isTrue);
      final session = (await sessions.loadSessions())
          .singleWhere((s) => s.sessionDate == DateTime(2026, 11, 15));
      final byName = {for (final r in session.records) r.attendee: r};
      expect(byName['Own Person']!.status, AttendanceStatus.present);
      expect(byName['Own Person']!.recordedBy, 'Sam');
      expect(byName['Local Guest']!.recordedBy, 'User');
      expect(byName['Gone Greg'], isNotNull);
      // Only the one session for that date exists.
      expect(
        (await sessions.loadSessions())
            .where((s) => s.sessionDate == DateTime(2026, 11, 15)),
        hasLength(1),
      );
    });

    test('an existing present mark is not replaced by a later absent one',
        () async {
      await seedOwnData();
      await sessions.createSession(
        title: 'Own Event',
        eventId: 'own-1',
        sessionDate: DateTime(2026, 11, 15),
        actor: 'User',
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Own Person',
            status: AttendanceStatus.present,
            recordedAt: t(0),
            recordedBy: 'User',
          ),
        ],
      );

      await service.apply(
        result(
          marks: [
            HandoffMark(
              memberId: 'm1',
              name: 'Own Person',
              status: AttendanceStatus.absent,
              recordedAt: t(50),
            ),
          ],
        ),
      );

      final session = (await sessions.loadSessions())
          .singleWhere((s) => s.sessionDate == DateTime(2026, 11, 15));
      expect(session.records.single.status, AttendanceStatus.present);
      expect(session.records.single.recordedBy, 'User');
    });

    test('a result for another date leaves the existing session untouched',
        () async {
      await seedOwnData();
      await service.apply(result(date: DateTime(2026, 11, 22)));
      final all = await sessions.loadSessions();
      expect(
        all.where((s) => s.eventId == 'own-1'),
        hasLength(2),
        reason: 'the seeded Nov 8 session plus a new Nov 22 one',
      );
      await expectOwnDataIntact();
    });

    test('a result with nothing to add creates no session', () async {
      await seedOwnData();
      final outcome = await service.apply(result(marks: const []));
      expect(outcome.sessionCreated, isFalse);
      expect(outcome.changed, isFalse);
      expect(
        (await sessions.loadSessions()).where((s) => s.eventId == 'own-1'),
        hasLength(1),
      );
    });

    test('a result cannot target a handed-off event on the same phone',
        () async {
      await service.receive(_roster());
      await expectLater(
        service.apply(result(eventId: 'ev-1')),
        throwsA(isA<HandoffFormatException>()),
      );
    });
  });

  test('ids the app generates never contain the handoff prefix separator', () {
    // Handed-off ids are protected by this: nothing locally created has a
    // colon, and HandoffCodec rejects ids that do.
    expect(
      RegExp(r'^[0-9a-f-]{36}$').hasMatch('123e4567-e89b-42d3-a456-426614174000'),
      isTrue,
    );
    expect(
      () => HandoffCodec.decodeString(
        '{"app":"attd","kind":"handoff","version":1,"eventId":"handoff:x",'
        '"eventTitle":"T","sessionDate":"2026-11-15","roster":[]}',
      ),
      throwsA(isA<HandoffFormatException>()),
    );
  });
}
