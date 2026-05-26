import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'dart:async';

class MockAttendanceRepository extends AttendanceRepository {
  List<Family> families = [];
  List<List<Family>> savedFamilies = [];
  List<String> addedFamilyNames = [];
  List<({String familyId, Member member})> addedMembers = [];
  Object? fetchError;
  Object? addFamilyError;
  Object? saveFamiliesError;

  @override
  Future<List<Family>> fetchFamilies() async {
    if (fetchError != null) throw fetchError!;
    return families;
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    if (saveFamiliesError != null) throw saveFamiliesError!;
    savedFamilies.add(families);
    this.families = families;
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    addedMembers.add((familyId: familyId, member: member));
    final index = families.indexWhere((f) => f.id == familyId);
    final updatedMembers = [...families[index].members, member];
    families[index] = families[index].copyWith(members: updatedMembers);
    return families[index];
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    if (addFamilyError != null) throw addFamilyError!;
    addedFamilyNames.add(displayName);
    final family = Family(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      displayName: displayName,
      members: [],
      updatedAt: DateTime.now(),
    );
    families.add(family);
    return family;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value(families);
  }
}

class MockEventRepository implements EventRepository {
  Event? event;
  final List<Event> updatedEvents = [];
  Object? updateError;

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {
    if (updateError != null) throw updateError!;
    updatedEvents.add(event);
    this.event = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Future<Event?> findEventById(String eventId) async => event;

  @override
  Stream<List<Event>> streamEvents() {
    return Stream.value(event != null ? [event!] : []);
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  late MockAttendanceRepository mockAttendanceRepo;
  late MockEventRepository mockEventRepo;

  setUp(() {
    mockAttendanceRepo = MockAttendanceRepository();
    mockEventRepo = MockEventRepository();
  });

  testWidgets('MembersPage renders ConvToggle in event mode', (
    WidgetTester tester,
  ) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      )
    ];

    final event = Event(
      id: 'e1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      memberIds: ['1'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.event = event;

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ConvToggle is present and selected
    expect(find.byType(ConvToggle), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    final toggle = tester.widget<ConvToggle>(find.byType(ConvToggle));
    expect(toggle.value, isTrue);
  });

  testWidgets('MembersPage opens edit dialog from the row edit icon', (
    WidgetTester tester,
  ) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      )
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit Member'), findsOneWidget);
  });

  testWidgets('MembersPage handles swipe left to delete', (
    WidgetTester tester,
  ) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      )
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Swipe Left to Delete
    await tester.drag(find.text('Alice'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify Delete dialog
    expect(find.text('Remove Member'), findsOneWidget);
  });

  testWidgets('adds a family and member from the add field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('member_search_field')),
      'Ada Lovelace',
    );
    await tester.tap(find.byKey(const ValueKey('member_add_fab')));
    await tester.pumpAndSettle();

    expect(mockAttendanceRepo.addedFamilyNames, ['Ada Lovelace']);
    expect(mockAttendanceRepo.addedMembers.single.member.displayName,
        'Ada Lovelace');
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('Added Ada Lovelace'), findsOneWidget);
  });

  testWidgets('editing a member persists the renamed family list',
      (tester) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Alice Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(mockAttendanceRepo.savedFamilies, hasLength(1));
    expect(
      mockAttendanceRepo.savedFamilies.single.single.members.single.displayName,
      'Alice Smith',
    );
    expect(find.text('Updated Alice to Alice Smith'), findsOneWidget);
  });

  testWidgets('deleting a member soft-deletes it in persisted families',
      (tester) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(find.text('Alice'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(mockAttendanceRepo.savedFamilies, hasLength(1));
    expect(
      mockAttendanceRepo.savedFamilies.single.single.members.single.deletedAt,
      isNotNull,
    );
    expect(find.text('Removed Alice'), findsOneWidget);
  });

  testWidgets('toggling event membership updates the event repository', (
    tester,
  ) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      ),
    ];

    final event = Event(
      id: 'e1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.event = event;

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(ConvToggle));
    await tester.pumpAndSettle();

    expect(mockEventRepo.updatedEvents, hasLength(1));
    expect(mockEventRepo.updatedEvents.single.memberIds, ['1']);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('shows a snackbar when event membership update fails', (
    tester,
  ) async {
    final member = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.families = [
      Family(
        id: 'f1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: DateTime.now(),
      ),
    ];

    final event = Event(
      id: 'e1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );
    mockEventRepo
      ..event = event
      ..updateError = Exception('network unavailable');

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(ConvToggle));
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to update event: Exception: network unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('adding a member in event mode assigns them to the event', (
    tester,
  ) async {
    final event = Event(
      id: 'e1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.event = event;

    await tester.pumpWidget(
      MaterialApp(
        home: MembersPage(
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('member_search_field')),
      'Grace Hopper',
    );
    await tester.tap(find.byKey(const ValueKey('member_add_fab')));
    await tester.pumpAndSettle();

    expect(mockAttendanceRepo.addedMembers.single.member.displayName,
        'Grace Hopper');
    expect(mockEventRepo.updatedEvents, hasLength(1));
    expect(
      mockEventRepo.updatedEvents.single.memberIds,
      [mockAttendanceRepo.addedMembers.single.member.id],
    );
  });

  group('uncovered paths', () {
    Family familyWith(List<Member> members, {String id = 'f1'}) => Family(
          id: id,
          displayName: 'Family $id',
          members: members,
          updatedAt: DateTime.now(),
        );

    Widget host({
      required AttendanceRepository attendance,
      SessionRepository? sessions,
      EventRepository? events,
      Event? event,
    }) {
      return MaterialApp(
        home: MembersPage(
          attendanceRepository: attendance,
          sessionRepository: sessions,
          eventRepository: events,
          event: event,
          disableAnimations: true,
        ),
      );
    }

    testWidgets('renders error state when fetchFamilies throws',
        (tester) async {
      mockAttendanceRepo.fetchError = Exception('boom');
      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('tapping the info icon opens the rename info dialog',
        (tester) async {
      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Historical Accuracy'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Historical Accuracy'), findsNothing);
    });

    // While the duplicate dialog is open, the FAB shows a
    // CircularProgressIndicator (indefinite animation), so pumpAndSettle
    // would never settle. Use pump steps instead.

    testWidgets('add duplicate member: Cancel aborts the add', (tester) async {
      mockAttendanceRepo.families = [
        familyWith([Member(id: 'm1', displayName: 'Alice')]),
      ];

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('member_search_field')),
        'Alice',
      );
      await tester.tap(find.byKey(const ValueKey('member_add_fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Duplicate Member'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockAttendanceRepo.addedFamilyNames, isEmpty);
    });

    testWidgets('add duplicate member: Add Duplicate proceeds', (tester) async {
      mockAttendanceRepo.families = [
        familyWith([Member(id: 'm1', displayName: 'Alice')]),
      ];

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('member_search_field')),
        'Alice',
      );
      await tester.tap(find.byKey(const ValueKey('member_add_fab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Add Duplicate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockAttendanceRepo.addedFamilyNames, ['Alice']);
    });

    testWidgets('add member failure shows error snackbar', (tester) async {
      mockAttendanceRepo.addFamilyError = Exception('offline');
      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('member_search_field')),
        'Bob',
      );
      await tester.tap(find.byKey(const ValueKey('member_add_fab')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to add member'), findsOneWidget);
    });

    testWidgets('editing a member with linked sessions surfaces the '
        'historical alert and Cancel aborts the rename', (tester) async {
      final member = Member(id: 'm1', displayName: 'Alice');
      mockAttendanceRepo.families = [familyWith([member])];

      final sessions = _StubSessionRepository(sessions: [
        Session(
          id: 's1',
          title: 'Sunday Service',
          sessionDate: DateTime(2025, 1, 1),
          records: [
            SessionRecord(
              memberId: 'm1',
              attendee: 'Alice',
              status: AttendanceStatus.present,
              recordedAt: DateTime(2025, 1, 1),
              recordedBy: 'tester',
            ),
          ],
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
          createdBy: 'tester',
        ),
      ]);

      await tester.pumpWidget(host(
        attendance: mockAttendanceRepo,
        sessions: sessions,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Historical Data Alert'), findsOneWidget);
      expect(find.textContaining('Sunday Service'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(mockAttendanceRepo.savedFamilies, isEmpty);
    });

    testWidgets('historical alert >5 sessions shows the overflow row',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final member = Member(id: 'm1', displayName: 'Alice');
      mockAttendanceRepo.families = [familyWith([member])];

      final sessions = _StubSessionRepository(sessions: List.generate(7, (i) {
        return Session(
          id: 's$i',
          title: 'Session $i',
          sessionDate: DateTime(2025, 1, i + 1),
          records: [
            SessionRecord(
              memberId: 'm1',
              attendee: 'Alice',
              status: AttendanceStatus.present,
              recordedAt: DateTime(2025, 1, i + 1),
              recordedBy: 'tester',
            ),
          ],
          createdAt: DateTime(2025, 1, i + 1),
          updatedAt: DateTime(2025, 1, i + 1),
          createdBy: 'tester',
        );
      }));

      await tester.pumpWidget(host(
        attendance: mockAttendanceRepo,
        sessions: sessions,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('... and 2 more'), findsOneWidget);
    });

    testWidgets('editing to a duplicate name shows confirmation and '
        'cancelling aborts', (tester) async {
      mockAttendanceRepo.families = [
        familyWith([
          Member(id: 'm1', displayName: 'Alice'),
          Member(id: 'm2', displayName: 'Bob'),
        ]),
      ];

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Bob');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate Member'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(mockAttendanceRepo.savedFamilies, isEmpty);
    });

    testWidgets('editing to a duplicate name with Save Anyway proceeds',
        (tester) async {
      mockAttendanceRepo.families = [
        familyWith([
          Member(id: 'm1', displayName: 'Alice'),
          Member(id: 'm2', displayName: 'Bob'),
        ]),
      ];

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Bob');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Anyway'));
      await tester.pumpAndSettle();

      expect(mockAttendanceRepo.savedFamilies, hasLength(1));
    });

    testWidgets('save failure during edit reverts state and shows error',
        (tester) async {
      mockAttendanceRepo.families = [
        familyWith([Member(id: 'm1', displayName: 'Alice')]),
      ];
      mockAttendanceRepo.saveFamiliesError = Exception('disk full');

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Alice Smith');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to update member'), findsOneWidget);
    });

    testWidgets('deleting a member with linked sessions shows the session '
        'list and the "more" overflow', (tester) async {
      final member = Member(id: 'm1', displayName: 'Alice');
      mockAttendanceRepo.families = [familyWith([member])];

      final sessions = _StubSessionRepository(sessions: List.generate(5, (i) {
        return Session(
          id: 's$i',
          title: 'Session $i',
          sessionDate: DateTime(2025, 1, i + 1),
          records: [
            SessionRecord(
              memberId: 'm1',
              attendee: 'Alice',
              status: AttendanceStatus.present,
              recordedAt: DateTime(2025, 1, i + 1),
              recordedBy: 'tester',
            ),
          ],
          createdAt: DateTime(2025, 1, i + 1),
          updatedAt: DateTime(2025, 1, i + 1),
          createdBy: 'tester',
        );
      }));

      await tester.pumpWidget(host(
        attendance: mockAttendanceRepo,
        sessions: sessions,
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Alice'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('linked to 5 past session reports'),
          findsOneWidget);
      expect(find.text('... and 2 more'), findsOneWidget);

      // Confirm delete to also cover the persistence branch.
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(mockAttendanceRepo.savedFamilies, hasLength(1));
    });

    testWidgets('delete failure reverts state and shows error snackbar',
        (tester) async {
      mockAttendanceRepo.families = [
        familyWith([Member(id: 'm1', displayName: 'Alice')]),
      ];
      mockAttendanceRepo.saveFamiliesError = Exception('disk full');

      await tester.pumpWidget(host(attendance: mockAttendanceRepo));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Alice'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to remove member'), findsOneWidget);
    });
  });
}

class _StubSessionRepository implements SessionRepository {
  _StubSessionRepository({this.sessions = const []});

  final List<Session> sessions;

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);

  @override
  Future<Session?> findSessionById(String id) async {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
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
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId,
      {required String actor}) async {}

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

