import 'dart:async';
import 'dart:ui' as ui;

import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/marking_mode.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/attendance/models/roster_grouping.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';

class MockAttendanceRepository extends AttendanceRepository {
  List<Family> _families = [];
  final List<Family> addedFamilies = [];
  final List<Member> addedMembers = [];

  void seed(List<Family> families) {
    _families = List<Family>.from(families);
  }

  @override
  Future<List<Family>> fetchFamilies() async => _families;
  @override
  Future<void> saveFamilies(List<Family> families) async {
    _families = families;
  }
  @override
  Future<Family> addMember(String familyId, Member member) async {
    addedMembers.add(member);
    final i = _families.indexWhere((f) => f.id == familyId);
    if (i >= 0) {
      final updated = _families[i].copyWith(
        members: [..._families[i].members, member],
      );
      _families[i] = updated;
      return updated;
    }
    return _families.first;
  }
  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    final f = Family(
      id: 'f-${addedFamilies.length}',
      displayName: displayName,
      members: const [],
    );
    addedFamilies.add(f);
    _families.add(f);
    return f;
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value(_families);
  }
}

class MockEventRepository extends EventRepository {
  final List<Event> _events = [];
  final List<Event> updateCalls = [];

  void seed(Event event) {
    _events.add(event);
  }

  @override
  Future<void> createEvent(Event event) async {
    _events.add(event);
  }
  @override
  Future<void> updateEvent(Event event) async {
    updateCalls.add(event);
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i >= 0) {
      _events[i] = event;
    } else {
      _events.add(event);
    }
  }
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async {
    try {
      return _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }
  @override
  Stream<List<Event>> streamEvents() => Stream.value(List<Event>.from(_events));
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository extends SessionRepository {
  List<Session> savedSessions = [];
  final List<String> deleteCalls = [];

  @override
  Stream<List<Session>> streamSessions() {
    return Stream.value([]);
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<List<Session>> loadSessions() async {
    return [];
  }

  @override
  Future<Session?> findSessionById(String id) async {
    try {
      return savedSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    deleteCalls.add(sessionId);
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    savedSessions.add(session);
    return session;
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

/// [MockSessionRepository] whose saveSnapshot blocks until [saveGate] fires,
/// letting tests observe the page while a write is still in flight.
class DelayedSessionRepository extends MockSessionRepository {
  final Completer<void> saveGate = Completer<void>();

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    await saveGate.future;
    return super.saveSnapshot(session, actor: actor);
  }
}

Session _session({
  List<SessionRecord> records = const [],
  String title = 'Test Session',
}) {
  final now = DateTime(2026, 5, 24);
  return Session(
    id: 's1',
    title: title,
    sessionDate: now,
    createdAt: now,
    updatedAt: now,
    createdBy: 'User',
    currentVersion: 1,
    records: records,
  );
}

SessionRecord _record(
  Member m,
  AttendanceStatus status, {
  String by = 'User',
}) =>
    SessionRecord(
      memberId: m.id,
      attendee: m.displayName,
      status: status,
      recordedAt: DateTime(2026, 5, 24),
      recordedBy: by,
    );

Future<void> _pumpPage(
  WidgetTester tester, {
  required Session session,
  required List<Member> members,
  required MockSessionRepository sessions,
  List<Family>? families,
  MarkingMode? markingMode,
  AttendanceStartMode? startMode,
  bool initialListMode = false,
  RosterGrouping? rosterGrouping,
  MockAttendanceRepository? attendance,
  MockEventRepository? events,
  Event? event,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AttendanceDeckPage(
        session: session,
        members: members,
        families: families,
        sessionRepository: sessions,
        attendanceRepository: attendance ?? MockAttendanceRepository(),
        eventRepository: events ?? MockEventRepository(),
        event: event,
        markingMode: markingMode,
        startMode: startMode,
        initialListMode: initialListMode,
        rosterGrouping: rosterGrouping,
        disableAnimations: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chip(String id) => find.byKey(Key('likelyHereChip_$id'));

/// The header tally's present number.
Finder _headerPresent(String text) => find.descendant(
      of: find.byKey(const Key('headerTallyPresent')),
      matching: find.text(text),
    );

/// The header tally's "N left".
Finder _headerLeft(String text) => find.descendant(
      of: find.byKey(const Key('headerTallyTail')),
      matching: find.text(text),
    );

/// Whether the tile reads as marked present to a screen reader.
bool _isMarked(WidgetTester tester, Finder tile) {
  final data = tester.getSemantics(tile).getSemanticsData();
  return data.flagsCollection.isSelected == ui.Tristate.isTrue;
}

void main() {
  final alice = Member(id: 'a', displayName: 'Alice');
  final bob = Member(id: 'b', displayName: 'Bob');
  final charlie = Member(id: 'c', displayName: 'Charlie');

  group('marking on the grid', () {
    testWidgets('tapping a name marks them present and saves', (tester) async {
      final repo = MockSessionRepository();
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice],
        sessions: repo,
      );

      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();

      expect(repo.savedSessions.length, 1);
      final saved = repo.savedSessions.first.records;
      expect(saved.single.attendee, 'Alice');
      expect(saved.single.status, AttendanceStatus.present);
      expect(_headerPresent('1'), findsOneWidget);
      expect(_headerLeft('0 left'), findsOneWidget);
    });

    testWidgets('tapping a marked name unmarks them', (tester) async {
      final repo = MockSessionRepository();
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice],
        sessions: repo,
      );

      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();

      expect(repo.savedSessions.last.records.single.status,
          AttendanceStatus.absent);
      expect(_headerPresent('0'), findsOneWidget);
      expect(_headerLeft('1 left'), findsOneWidget);
    });

    testWidgets(
        'toggling one member does not affect another member sharing the same '
        'name', (tester) async {
      final repo = MockSessionRepository();
      // Two distinct members that happen to share a display name.
      final aliceOne = Member(id: 'a', displayName: 'Alice');
      final aliceTwo = Member(id: 'b', displayName: 'Alice');
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(aliceOne, AttendanceStatus.present),
          _record(aliceTwo, AttendanceStatus.present),
        ]),
        members: [aliceOne, aliceTwo],
        families: [
          Family(id: 'fam', displayName: 'Smiths', members: [aliceOne, aliceTwo]),
        ],
        sessions: repo,
      );

      // Toggle only the first Alice (id 'a') off.
      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();

      final saved = repo.savedSessions.last;
      // Both members still have exactly one record each: the second Alice's
      // record must not be wiped by the name collision.
      expect(saved.records.where((r) => r.memberId == 'a'), hasLength(1));
      expect(saved.records.where((r) => r.memberId == 'b'), hasLength(1));
      expect(saved.records.firstWhere((r) => r.memberId == 'a').status,
          AttendanceStatus.absent);
      expect(saved.records.firstWhere((r) => r.memberId == 'b').status,
          AttendanceStatus.present);
    });
  });

  group('the page is always the grid', () {
    testWidgets('whatever mode, start mode or list flag the caller passes',
        (tester) async {
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice, bob],
        sessions: MockSessionRepository(),
        markingMode: MarkingMode.rapidEntry,
        startMode: AttendanceStartMode.allPresent,
        initialListMode: true,
        rosterGrouping: RosterGrouping.byFamily,
      );

      expect(_chip('a'), findsOneWidget);
      expect(_chip('b'), findsOneWidget);
      expect(find.byKey(const Key('rapidEntryField')), findsNothing);
      expect(find.byKey(const Key('deckListModeToggle')), findsNothing);
      expect(find.byKey(const Key('rosterMarkAllPresent')), findsNothing);
      expect(find.textContaining('Confirm'), findsNothing);
      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('a session with an empty roster still shows the grid page',
        (tester) async {
      await _pumpPage(
        tester,
        session: _session(),
        members: const [],
        sessions: MockSessionRepository(),
        markingMode: MarkingMode.none,
      );

      expect(find.text('Nobody on this roster yet.'), findsOneWidget);
      expect(find.byKey(const Key('finishSessionButton')), findsOneWidget);
    });
  });

  group('pre-marked sessions', () {
    testWidgets('a preseeded session shows its present people as marked',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(alice, AttendanceStatus.present,
              by: 'System (Preseed - Smart)'),
          // Bob is left blank (no record).
          _record(charlie, AttendanceStatus.absent,
              by: 'System (Preseed - Smart)'),
        ]),
        members: [alice, bob, charlie],
        sessions: MockSessionRepository(),
        startMode: AttendanceStartMode.perMemberDefault,
        initialListMode: true,
      );

      expect(_isMarked(tester, _chip('a')), isTrue);
      expect(_isMarked(tester, _chip('b')), isFalse);
      expect(_isMarked(tester, _chip('c')), isFalse);
      expect(_headerPresent('1'), findsOneWidget);
      expect(_headerLeft('2 left'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a past session reopened shows what was recorded',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(alice, AttendanceStatus.present),
          _record(bob, AttendanceStatus.absent),
          _record(charlie, AttendanceStatus.present),
        ]),
        members: [alice, bob, charlie],
        sessions: MockSessionRepository(),
      );

      expect(_isMarked(tester, _chip('a')), isTrue);
      expect(_isMarked(tester, _chip('b')), isFalse);
      expect(_isMarked(tester, _chip('c')), isTrue);
      expect(_headerPresent('2'), findsOneWidget);
      expect(_headerLeft('1 left'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('marking on top of the preseed keeps the others untouched',
        (tester) async {
      final repo = MockSessionRepository();
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(alice, AttendanceStatus.present, by: 'System (Preseed)'),
          _record(charlie, AttendanceStatus.absent, by: 'System (Preseed)'),
        ]),
        members: [alice, bob, charlie],
        sessions: repo,
      );

      await tester.tap(_chip('b'));
      await tester.pumpAndSettle();

      final saved = repo.savedSessions.last;
      expect(saved.records, hasLength(3));
      expect(saved.records.firstWhere((r) => r.memberId == 'a').status,
          AttendanceStatus.present);
      expect(saved.records.firstWhere((r) => r.memberId == 'b').status,
          AttendanceStatus.present);
      expect(saved.records.firstWhere((r) => r.memberId == 'c').status,
          AttendanceStatus.absent);
    });
  });

  group('the header tally', () {
    final kevin = Member(id: 'k', displayName: 'Kevin Garrido');
    final tony = Member(id: 't', displayName: 'Tony Wang');
    final fely = Member(id: 'f', displayName: 'Fely Keh');

    testWidgets('a member listed under two families counts once',
        (tester) async {
      final families = [
        Family(id: 'f1', displayName: 'Garrido', members: [kevin, fely]),
        Family(id: 'f2', displayName: 'Wang', members: [tony, kevin]),
      ];
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(kevin, AttendanceStatus.present, by: 'System (Preseed)'),
          _record(tony, AttendanceStatus.present, by: 'System (Preseed)'),
        ]),
        // Mirrors the hub, which flattens the event's families.
        members: families.expand((f) => f.members).toList(),
        families: families,
        sessions: MockSessionRepository(),
      );

      expect(_headerPresent('2'), findsOneWidget);
      expect(_headerLeft('1 left'), findsOneWidget);
    });

    testWidgets("a namesake's record doesn't mark another member present",
        (tester) async {
      final tony2 = Member(id: 't2', displayName: 'Tony Wang');
      final families = [
        Family(id: 'f1', displayName: 'Garrido', members: [kevin, fely]),
        Family(id: 'f2', displayName: 'Wang', members: [tony, tony2]),
      ];
      await _pumpPage(
        tester,
        session: _session(records: [
          _record(kevin, AttendanceStatus.present, by: 'System (Preseed)'),
          _record(tony, AttendanceStatus.present, by: 'System (Preseed)'),
        ]),
        members: families.expand((f) => f.members).toList(),
        families: families,
        sessions: MockSessionRepository(),
      );

      expect(_headerPresent('2'), findsOneWidget);
      expect(_headerLeft('2 left'), findsOneWidget);
    });
  });

  group('finishing', () {
    testWidgets('Done saves and opens the summary', (tester) async {
      final repo = MockSessionRepository();
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice, bob],
        sessions: repo,
      );

      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finishSessionButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryPage), findsOneWidget);
      expect(find.text('Test Session'), findsOneWidget);
      expect(repo.savedSessions.last.records.single.status,
          AttendanceStatus.present);
    });

    testWidgets('Done waits for pending saves before showing the summary',
        (tester) async {
      final repo = DelayedSessionRepository();
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice],
        sessions: repo,
      );

      // Mark the only member present; the write is still in flight.
      await tester.tap(_chip('a'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('finishSessionButton')));
      await tester.pump();

      expect(find.byType(SessionSummaryPage), findsNothing);
      expect(repo.savedSessions, isEmpty);

      repo.saveGate.complete();
      await tester.pumpAndSettle();

      expect(repo.savedSessions, hasLength(1));
      expect(find.byType(SessionSummaryPage), findsOneWidget);
    });

    testWidgets('the grid does not finish by itself when everyone is marked',
        (tester) async {
      await _pumpPage(
        tester,
        session: _session(),
        members: [alice],
        sessions: MockSessionRepository(),
      );

      await tester.tap(_chip('a'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryPage), findsNothing);
      expect(_headerLeft('0 left'), findsOneWidget);
    });
  });

  group('adding someone', () {
    testWidgets('picking a global member appends to event.memberIds',
        (tester) async {
      final fakeRepo = MockSessionRepository();
      final attendanceRepo = MockAttendanceRepository();
      final eventRepo = MockEventRepository();

      final inEvent = Member(id: '1', displayName: 'Alice');
      final globalOnly = Member(id: '2', displayName: 'Bob');
      attendanceRepo.seed([
        Family(id: 'f', displayName: 'F', members: [inEvent, globalOnly]),
      ]);

      final event = Event(
        id: 'e1',
        title: 'Test Session',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        memberIds: const ['1'],
        createdAt: DateTime.now(),
      );
      eventRepo.seed(event);

      await _pumpPage(
        tester,
        session: _session().copyWith(eventId: 'e1'),
        members: [inEvent],
        sessions: fakeRepo,
        attendance: attendanceRepo,
        events: eventRepo,
        event: event,
      );

      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob').last);
      await tester.pumpAndSettle();

      expect(eventRepo.updateCalls.length, 1);
      expect(eventRepo.updateCalls.last.memberIds, containsAll(['1', '2']));
      expect(fakeRepo.savedSessions, isNotEmpty);
      expect(
        fakeRepo.savedSessions.last.records.any((r) => r.memberId == '2'),
        isTrue,
      );
    });

    testWidgets('a new name without Guest creates a global member',
        (tester) async {
      final fakeRepo = MockSessionRepository();
      final attendanceRepo = MockAttendanceRepository();
      final eventRepo = MockEventRepository();

      final m = Member(id: '1', displayName: 'Alice');
      attendanceRepo.seed([
        Family(id: 'f0', displayName: 'F', members: [m]),
      ]);

      final event = Event(
        id: 'e1',
        title: 'Test Session',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        memberIds: const ['1'],
        createdAt: DateTime.now(),
      );
      eventRepo.seed(event);

      await _pumpPage(
        tester,
        session: _session().copyWith(eventId: 'e1'),
        members: [m],
        sessions: fakeRepo,
        attendance: attendanceRepo,
        events: eventRepo,
        event: event,
      );

      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Charlie');
      await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
      await tester.pumpAndSettle();

      expect(attendanceRepo.addedFamilies.length, 1);
      expect(attendanceRepo.addedMembers.length, 1);
      final newId = attendanceRepo.addedMembers.first.id;
      expect(eventRepo.updateCalls.last.memberIds, contains(newId));
      expect(
        fakeRepo.savedSessions.last.records
            .firstWhere((r) => r.attendee == 'Charlie')
            .memberId,
        equals(newId),
      );
    });
  });

  group('keep-vs-discard on exit', () {
    // A session as it exists when the page opens from a bulk default: every
    // member is pre-marked present by the preseed, none touched by the user.
    Session allPresentSession(List<Member> members) => Session(
          id: 'keep-1',
          eventId: 'e1',
          title: 'Sunday Service',
          sessionDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'User',
          currentVersion: 1,
          records: [
            for (final m in members)
              SessionRecord(
                memberId: m.id,
                attendee: m.displayName,
                status: AttendanceStatus.present,
                recordedAt: DateTime.now(),
                recordedBy: 'System (Preseed)',
              ),
          ],
        );

    // Pushes the page on top of a base route so that popping it actually pops
    // (a page mounted as `home:` has nothing to pop back to, so PopScope would
    // never fire).
    Future<void> pumpPagePushed(
      WidgetTester tester, {
      required MockSessionRepository repo,
      required List<Member> members,
      bool deleteOnCancel = true,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceDeckPage(
                        session: allPresentSession(members),
                        deleteOnCancel: deleteOnCancel,
                        members: members,
                        sessionRepository: repo,
                        attendanceRepository: MockAttendanceRepository(),
                        eventRepository: MockEventRepository(),
                        disableAnimations: true,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final members = [
      Member(id: '1', displayName: 'Dan'),
      Member(id: '2', displayName: 'Eve'),
    ];

    testWidgets('cancelling the page (X) discards the session',
        (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(tester, repo: repo, members: members);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, contains('keep-1'));
    });

    testWidgets('cancelling a resumed session (deleteOnCancel: false) keeps it',
        (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(
        tester,
        repo: repo,
        members: members,
        deleteOnCancel: false,
      );

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      // Resuming an existing session must never delete it on back-out.
      expect(repo.deleteCalls, isEmpty);
    });

    testWidgets(
        'cancelling after an edit prompts, and Discard deletes the session',
        (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(tester, repo: repo, members: members);

      // Make a real edit: toggle Dan off.
      await tester.tap(_chip('1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      // Edits exist, so a confirmation dialog replaces the silent discard.
      expect(find.text('Save as is'), findsOneWidget);
      expect(repo.deleteCalls, isEmpty);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, contains('keep-1'));
    });

    testWidgets('dismissing the prompt stays on the grid', (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(tester, repo: repo, members: members);

      await tester.tap(_chip('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      // Tap the scrim outside the dialog.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.text('Save as is'), findsNothing);
      expect(_chip('1'), findsOneWidget);
      expect(repo.deleteCalls, isEmpty);
    });

    testWidgets('cancelling after an edit then Save-as-is keeps the session',
        (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(tester, repo: repo, members: members);

      await tester.tap(_chip('1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save as is'));
      await tester.pumpAndSettle();

      // Saving keeps the edited session: no cleanup delete.
      expect(repo.deleteCalls, isEmpty);
    });

    testWidgets('finishing a pre-marked session keeps it', (tester) async {
      final repo = MockSessionRepository();
      await pumpPagePushed(tester, repo: repo, members: members);

      await tester.tap(find.byKey(const Key('finishSessionButton')));
      await tester.pumpAndSettle();

      expect(find.byType(SessionSummaryPage), findsOneWidget);
      // Finishing replaces the page rather than popping it, so the session
      // must survive: no cleanup delete.
      expect(repo.deleteCalls, isEmpty);
    });
  });
}
