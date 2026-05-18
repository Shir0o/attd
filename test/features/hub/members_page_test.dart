import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'dart:async';

class MockAttendanceRepository implements AttendanceRepository {
  List<Family> families = [];
  List<List<Family>> savedFamilies = [];
  List<String> addedFamilyNames = [];
  List<({String familyId, Member member})> addedMembers = [];

  @override
  Future<List<Family>> fetchFamilies() async => families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
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
  Future<Family> addFamily(String displayName) async {
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

  testWidgets('MembersPage renders Switch instead of Checkbox in event mode', (
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

    // Verify Switch is present
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    // Verify Alice is selected
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets('MembersPage handles swipe right to edit', (
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

    // Swipe Right to Edit
    await tester.drag(find.text('Alice'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify Edit dialog
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

    await tester.tap(find.byType(Switch));
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

    await tester.tap(find.byType(Switch));
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
}
