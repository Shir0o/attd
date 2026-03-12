import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

class MockAttendanceRepository implements AttendanceRepository {
  List<Family> families = [];
  bool saveCalled = false;

  @override
  Future<List<Family>> fetchFamilies() async => families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
    this.families = families;
    saveCalled = true;
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {}
}

class MockEventRepository implements EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}
}

void main() {
  late MockAttendanceRepository mockAttendanceRepo;
  late MockEventRepository mockEventRepo;

  setUp(() {
    mockAttendanceRepo = MockAttendanceRepository();
    mockEventRepo = MockEventRepository();
  });

  Widget buildMembersPage({Event? event}) {
    return MaterialApp(
      home: MembersPage(
        attendanceRepository: mockAttendanceRepo,
        event: event,
        eventRepository: mockEventRepo,
      ),
    );
  }

  testWidgets('Swipe to delete member works', (WidgetTester tester) async {
    final member = Member(id: 'm1', displayName: 'John Doe');
    final family = Family(id: 'f1', displayName: 'Doe Family', members: [member]);
    mockAttendanceRepo.families = [family];

    await tester.pumpWidget(buildMembersPage());
    await tester.pump(const Duration(milliseconds: 700)); // Wait for 600ms loading delay
    await tester.pump(); // Final rebuild after loading finishes

    expect(find.text('John Doe'), findsOneWidget);

    // Swipe from right to left
    await tester.drag(find.text('John Doe'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('Remove Member'), findsOneWidget);
    expect(find.text('Are you sure you want to remove "John Doe"? This will not delete their historical attendance records.'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    // Verify member is gone from UI
    expect(find.text('John Doe'), findsNothing);
    expect(mockAttendanceRepo.saveCalled, isTrue);
    expect(mockAttendanceRepo.families.isEmpty || mockAttendanceRepo.families.first.members.isEmpty, isTrue);
  });

  testWidgets('Cancel swipe to delete does not delete member', (WidgetTester tester) async {
    final member = Member(id: 'm1', displayName: 'John Doe');
    final family = Family(id: 'f1', displayName: 'Doe Family', members: [member]);
    mockAttendanceRepo.families = [family];

    await tester.pumpWidget(buildMembersPage());
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('John Doe'), findsOneWidget);

    // Swipe from right to left
    await tester.drag(find.text('John Doe'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Cancel delete
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify member is still there
    expect(find.text('John Doe'), findsOneWidget);
    expect(mockAttendanceRepo.saveCalled, isFalse);
  });
}
