import 'dart:async';
import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/assign_solo_members_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository extends AttendanceRepository {
  List<Family> families = [];
  final List<String> addedFamilyNames = [];
  final List<(String memberId, String familyId)> moved = [];
  int nextId = 0;

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    addedFamilyNames.add(displayName);
    nextId++;
    final newFamily = Family(
      id: 'f$nextId',
      displayName: displayName,
      members: const [],
      isAutoSingleton: isAutoSingleton,
    );
    families.add(newFamily);
    return newFamily;
  }

  @override
  Future<Family> moveMemberToFamily(String memberId, String targetFamilyId) async {
    moved.add((memberId, targetFamilyId));
    return Family(
      id: targetFamilyId,
      displayName: '',
      members: const [],
    );
  }

  @override
  Future<List<Family>> fetchFamilies() async => families;

  @override
  Future<Family> addMember(String familyId, Member member) => throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {
    this.families = families;
  }

  @override
  Stream<List<Family>> streamFamilies() => const Stream.empty();
}

Member _m(String id, String name) => Member(id: id, displayName: name);

void main() {
  testWidgets('AssignSoloMembersPage shows skeleton initially', (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AssignSoloMembersPage(
          repository: repo,
          soloMembers: [
            _m('1', 'Alice Smith'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppShimmer), findsWidgets);
    await tester.pump(const Duration(milliseconds: 850));
  });

  testWidgets('AssignSoloMembersPage lists solo members and allows quick assignment', (tester) async {
    final repo = _FakeRepository();
    repo.families = [
      Family(
        id: 'f-existing',
        displayName: 'Smith Family',
        members: [_m('9', 'Bob Smith')], // Not singleton since > 1 will be fetched/filtered
      )
    ];

    bool? popResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AssignSoloMembersPage(
                      repository: repo,
                      soloMembers: [
                        _m('1', 'Alice Smith'),
                      ],
                      disableAnimations: true,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Stay Solo'), findsOneWidget);

    // Tap Stay Solo dropdown button
    await tester.tap(find.text('Stay Solo'));
    await tester.pumpAndSettle();

    // Select Smith Family
    expect(find.text('Smith Family'), findsOneWidget);
    await tester.tap(find.text('Smith Family'));
    await tester.pumpAndSettle();

    expect(find.text('Smith Family'), findsWidgets); // One in list, one in selected

    // Confirm
    await tester.tap(find.text('Confirm Assignments'));
    await tester.pumpAndSettle();

    expect(repo.moved.length, 1);
    expect(repo.moved.first, ('1', 'f-existing'));
    expect(popResult, true);
  });

  testWidgets('AssignSoloMembersPage allows creating and assigning to a new family', (tester) async {
    final repo = _FakeRepository();
    bool? popResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AssignSoloMembersPage(
                      repository: repo,
                      soloMembers: [
                        _m('1', 'Alice Parker'),
                      ],
                      disableAnimations: true,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap Stay Solo dropdown
    await tester.tap(find.text('Stay Solo'));
    await tester.pumpAndSettle();

    // Select Create new family...
    await tester.tap(find.text('Create new family...'));
    await tester.pumpAndSettle();

    // The prompt shows up, prefilled with 'Parker'. Let's tap 'Create'.
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('New: Parker'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Confirm Assignments'));
    await tester.pumpAndSettle();

    expect(repo.addedFamilyNames, ['Parker']);
    expect(repo.moved.length, 1);
    expect(popResult, true);
  });
}
