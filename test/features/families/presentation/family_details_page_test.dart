import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/family_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository(this.family);

  Family family;
  Object? addMemberError;
  Member? addedMember;
  String? addedFamilyId;

  @override
  Future<Family> addMember(String familyId, Member member) async {
    final error = addMemberError;
    if (error != null) throw error;
    addedFamilyId = familyId;
    addedMember = member;
    family = family.copyWith(members: [...family.members, member]);
    return family;
  }

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Family>> fetchFamilies() async => [family];

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Stream<List<Family>> streamFamilies() => Stream.value([family]);
}

void main() {
  testWidgets('renders members and visitor labels', (tester) async {
    final family = Family(
      id: 'family-1',
      displayName: 'Smith Family',
      members: [
        Member(id: 'member-1', displayName: 'Alice Smith'),
        Member(
          id: 'member-2',
          displayName: 'Bob Guest',
          isVisitor: true,
          defaultStatus: AttendanceStatus.present,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(
          family: family,
          repository: FakeAttendanceRepository(family),
        ),
      ),
    );

    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Guest'), findsOneWidget);
    expect(find.text('Visitor'), findsOneWidget);
  });

  testWidgets('adds a member from the prompt', (tester) async {
    final family = Family(
      id: 'family-1',
      displayName: 'Smith Family',
      members: const [],
    );
    final repository = FakeAttendanceRepository(family);

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repository),
      ),
    );

    expect(find.text('No members yet.'), findsOneWidget);

    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Alice Smith  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(repository.addedFamilyId, 'family-1');
    expect(repository.addedMember?.displayName, 'Alice Smith');
    expect(repository.addedMember?.isVisitor, isFalse);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('No members yet.'), findsNothing);
  });

  testWidgets('does not add a member when the prompt is cancelled', (
    tester,
  ) async {
    final family = Family(
      id: 'family-1',
      displayName: 'Smith Family',
      members: const [],
    );
    final repository = FakeAttendanceRepository(family);

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repository),
      ),
    );

    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.addedMember, isNull);
    expect(find.text('No members yet.'), findsOneWidget);
  });

  testWidgets('shows an error when adding a member fails', (tester) async {
    final family = Family(
      id: 'family-1',
      displayName: 'Smith Family',
      members: const [],
    );
    final repository = FakeAttendanceRepository(family)
      ..addMemberError = Exception('save failed');

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repository),
      ),
    );

    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alice Smith');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.textContaining('Error adding member'), findsOneWidget);
    expect(find.text('No members yet.'), findsOneWidget);
  });
}
