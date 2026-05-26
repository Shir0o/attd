import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';
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

class MockEventRepository implements EventRepository {
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

class MockSessionRepository implements SessionRepository {
  List<Session> savedSessions = [];

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
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

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

void main() {
  testWidgets('AttendanceDeckPage swipes right to mark present', (
    WidgetTester tester,
  ) async {
    final fakeRepo = MockSessionRepository();
    final member = Member(id: '1', displayName: 'Test User');
    final members = [member];
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: fakeRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Find the card (SwipeableCard)
    final cardFinder = find.byType(SwipeableCard);
    expect(cardFinder, findsOneWidget);

    // Swipe Right
    await tester.drag(cardFinder, const Offset(300, 0));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle(); // Wait for animation

    // Verify repository was called
    expect(fakeRepo.savedSessions.length, 1);
    final savedRecords = fakeRepo.savedSessions.first.records;
    expect(savedRecords.length, 1);
    expect(savedRecords.first.attendee, 'Test User');
    expect(savedRecords.first.status, AttendanceStatus.present);

    // Verify we are at the summary page (it shows the session title)
    // Summary page has an 800ms skeleton
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('Test Session'), findsOneWidget);
    expect(find.text('PRESENT'), findsOneWidget);
  });

  testWidgets('AttendanceDeckPage swipes left to mark absent', (
    WidgetTester tester,
  ) async {
    final fakeRepo = MockSessionRepository();
    final member = Member(id: '1', displayName: 'Test User');
    final members = [member];
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: fakeRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Tap Absent button (instead of drag for more reliable transition test)
    await tester.tap(find.byKey(const Key('absentButton')));
    await tester.pump(); // Start transition
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(fakeRepo.savedSessions.length, 1);
    expect(
      fakeRepo.savedSessions.first.records.first.status,
      AttendanceStatus.absent,
    );

    // Verify Summary Screen
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('Test Session'), findsOneWidget);
    expect(find.text('PRESENT'), findsOneWidget);
  });

  testWidgets('AttendanceDeckPage add-sheet picking a global member appends to event.memberIds', (
    WidgetTester tester,
  ) async {
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

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      records: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [inEvent],
          sessionRepository: fakeRepo,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Existing'));
    await tester.pumpAndSettle();

    expect(eventRepo.updateCalls.length, 1);
    expect(eventRepo.updateCalls.last.memberIds, containsAll(['1', '2']));
    expect(fakeRepo.savedSessions, isNotEmpty);
    expect(
      fakeRepo.savedSessions.last.records.any((r) => r.memberId == '2'),
      isTrue,
    );
  });

  testWidgets('AttendanceDeckPage add-sheet new name without Guest creates global member', (
    WidgetTester tester,
  ) async {
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

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      records: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [m],
          sessionRepository: fakeRepo,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Charlie');
    await tester.tap(find.text('Add & Continue'));
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

  testWidgets('AttendanceDeckPage toggles to list mode and back preserves state',
      (WidgetTester tester) async {
    final fakeRepo = MockSessionRepository();
    final alice = Member(id: 'a', displayName: 'Alice');
    final bob = Member(id: 'b', displayName: 'Bob');
    final family = Family(
      id: 'fam',
      displayName: 'The Family',
      members: [alice, bob],
    );

    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [alice, bob],
          families: [family],
          sessionRepository: fakeRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Deck mode: SwipeableCard present.
    expect(find.byType(SwipeableCard), findsOneWidget);

    // Switch to list mode.
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.byType(SwipeableCard), findsNothing);
    expect(find.text('The Family'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Tap "all present" on the family — should save attendance for both.
    await tester.tap(find.byKey(const ValueKey('familyAllPresent_fam')));
    await tester.pumpAndSettle();

    final saved = fakeRepo.savedSessions.last;
    expect(saved.records.length, 2);
    expect(
      saved.records.every((r) => r.status == AttendanceStatus.present),
      isTrue,
    );

    // Switch back to deck mode — first member still queued.
    await tester.tap(find.text('Deck'));
    await tester.pumpAndSettle();
    expect(find.byType(SwipeableCard), findsOneWidget);
  });

  testWidgets(
      'AttendanceDeckPage shows family label and "mark family present" button',
      (WidgetTester tester) async {
    final fakeRepo = MockSessionRepository();
    final alice = Member(id: 'a', displayName: 'Alice');
    final bob = Member(id: 'b', displayName: 'Bob');
    final family = Family(
      id: 'fam',
      displayName: 'The Family',
      members: [alice, bob],
    );

    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [alice, bob],
          families: [family],
          sessionRepository: fakeRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Family name visible on the card.
    expect(find.text('The Family'), findsOneWidget);

    // The "mark family present" button is shown for multi-member families.
    expect(find.byKey(const Key('markFamilyPresentButton')), findsOneWidget);

    // Tapping it records all family members present and advances past them.
    await tester.tap(find.byKey(const Key('markFamilyPresentButton')));
    await tester.pumpAndSettle();

    expect(fakeRepo.savedSessions.last.records.length, 2);
    expect(
      fakeRepo.savedSessions.last.records
          .every((r) => r.status == AttendanceStatus.present),
      isTrue,
    );

    // Since we advanced past all members, we land on the summary page.
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets(
      'AttendanceDeckPage list-mode mark-all writes bulk records and Undo restores',
      (WidgetTester tester) async {
    final fakeRepo = MockSessionRepository();
    final alice = Member(id: 'a', displayName: 'Alice');
    final bob = Member(id: 'b', displayName: 'Bob');
    final family = Family(
      id: 'fam',
      displayName: 'Smiths',
      members: [alice, bob],
    );
    final now = DateTime(2026, 5, 24);
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: now,
      createdAt: now,
      updatedAt: now,
      createdBy: 'User',
      records: [
        SessionRecord(
          memberId: 'a',
          attendee: 'Alice',
          status: AttendanceStatus.absent,
          recordedAt: now,
          recordedBy: 'User',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [alice, bob],
          families: [family],
          sessionRepository: fakeRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rosterMarkAllMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markEveryonePresent')));
    await tester.pumpAndSettle();

    final saved = fakeRepo.savedSessions.last;
    expect(saved.records.length, 2);
    expect(
      saved.records.every((r) => r.status == AttendanceStatus.present),
      isTrue,
    );
    expect(saved.records.first.recordedBy, 'User (Bulk)');

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    final restored = fakeRepo.savedSessions.last;
    expect(restored.records.length, 1);
    expect(restored.records.single.memberId, 'a');
    expect(restored.records.single.status, AttendanceStatus.absent);
  });
}
