import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/family_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttendanceRepository extends AttendanceRepository {
  FakeAttendanceRepository(this.family, {this.others = const []});

  Family family;
  List<Family> others;
  Object? addMemberError;
  Object? moveError;
  Object? detachError;
  Member? addedMember;
  String? addedFamilyId;
  String? movedMemberId;
  String? movedToFamilyId;
  String? detachedMemberId;

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
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> moveMemberToFamily(
    String memberId,
    String targetFamilyId,
  ) async {
    final err = moveError;
    if (err != null) throw err;
    movedMemberId = memberId;
    movedToFamilyId = targetFamilyId;
    Member? moved;
    others = [
      for (final f in others)
        if (f.members.any((m) => m.id == memberId))
          () {
            moved = f.members.firstWhere((m) => m.id == memberId);
            return f.copyWith(
              members: f.members.where((m) => m.id != memberId).toList(),
            );
          }()
        else
          f,
    ];
    if (moved != null) {
      family = family.copyWith(members: [...family.members, moved!]);
    }
    return family;
  }

  @override
  Future<Family> detachMember(String memberId) async {
    final err = detachError;
    if (err != null) throw err;
    detachedMemberId = memberId;
    family = family.copyWith(
      members: family.members.where((m) => m.id != memberId).toList(),
    );
    return family;
  }

  @override
  Future<List<Family>> fetchFamilies() async => [family, ...others];

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Stream<List<Family>> streamFamilies() =>
      Stream.value([family, ...others]);
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
    expect(find.text('MEMBERS'), findsOneWidget);
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
    await tester.tap(find.text('Create New Member'));
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
    await tester.tap(find.text('Create New Member'));
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
    await tester.tap(find.text('Create New Member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alice Smith');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.textContaining('Error adding member'), findsOneWidget);
    expect(find.text('No members yet.'), findsOneWidget);
  });

  testWidgets('suggests unaffiliated members with a matching last name',
      (tester) async {
    final family = Family(
      id: 'family-smith',
      displayName: 'Smith',
      members: [Member(id: 'm-bob', displayName: 'Bob Smith')],
    );
    final aliceSingleton = Family(
      id: 'singleton-alice',
      displayName: 'Alice Smith',
      members: [Member(id: 'm-alice', displayName: 'Alice Smith')],
      isAutoSingleton: true,
    );
    final unrelated = Family(
      id: 'singleton-other',
      displayName: 'Charlie Jones',
      members: [Member(id: 'm-charlie', displayName: 'Charlie Jones')],
      isAutoSingleton: true,
    );
    final repo = FakeAttendanceRepository(
      family,
      others: [aliceSingleton, unrelated],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suggested'), findsOneWidget);
    expect(find.byKey(const Key('suggestion_m-alice')), findsOneWidget);
    expect(find.byKey(const Key('suggestion_m-charlie')), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('suggestion_m-alice')),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.movedMemberId, 'm-alice');
    expect(repo.movedToFamilyId, 'family-smith');
  });

  testWidgets('suggestion tap shows an error snackbar when the move fails',
      (tester) async {
    final family = Family(
      id: 'family-smith',
      displayName: 'Smith',
      members: [Member(id: 'm-bob', displayName: 'Bob Smith')],
    );
    final aliceSingleton = Family(
      id: 'singleton-alice',
      displayName: 'Alice Smith',
      members: [Member(id: 'm-alice', displayName: 'Alice Smith')],
      isAutoSingleton: true,
    );
    final repo = FakeAttendanceRepository(family, others: [aliceSingleton])
      ..moveError = Exception('move boom');
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('suggestion_m-alice')),
        matching: find.text('Add'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Error adding suggestion'), findsOneWidget);
  });

  testWidgets('detach cancel does not call repository', (tester) async {
    final family = Family(
      id: 'family-smith',
      displayName: 'Smith',
      members: [Member(id: 'm-alice', displayName: 'Alice Smith')],
    );
    final repo = FakeAttendanceRepository(family);
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detachMember_m-alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.detachedMemberId, isNull);
  });

  testWidgets('detach error path shows a snackbar', (tester) async {
    final family = Family(
      id: 'family-smith',
      displayName: 'Smith',
      members: [Member(id: 'm-alice', displayName: 'Alice Smith')],
    );
    final repo = FakeAttendanceRepository(family)
      ..detachError = Exception('detach boom');
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detachMember_m-alice')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pump();
    expect(find.textContaining('Error removing member'), findsOneWidget);
  });

  testWidgets('detach removes a member after confirmation', (tester) async {
    final family = Family(
      id: 'family-smith',
      displayName: 'Smith',
      members: [
        Member(id: 'm-alice', displayName: 'Alice Smith'),
        Member(id: 'm-bob', displayName: 'Bob Smith'),
      ],
    );
    final repo = FakeAttendanceRepository(family);
    await tester.pumpWidget(
      MaterialApp(
        home: FamilyDetailsPage(family: family, repository: repo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detachMember_m-alice')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove Alice Smith'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(repo.detachedMemberId, 'm-alice');
  });
}
