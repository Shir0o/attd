import 'dart:async';
import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/resolve_duplicates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository extends AttendanceRepository {
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
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) => throw UnimplementedError();

  @override
  Future<Family> moveMemberToFamily(String memberId, String targetFamilyId) => throw UnimplementedError();

  @override
  Future<Family> addMember(String familyId, Member member) => throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Family>> streamFamilies() => const Stream.empty();
}

Member _m(String id, String name) => Member(id: id, displayName: name);

void main() {
  testWidgets('ResolveDuplicatesPage shows skeleton initially', (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ResolveDuplicatesPage(
          repository: repo,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppShimmer), findsWidgets);
    await tester.pump(const Duration(milliseconds: 850));
  });

  testWidgets('ResolveDuplicatesPage shows fallback if no duplicates', (tester) async {
    final repo = _FakeRepository();
    repo.families = [
      Family(
        id: 'f1',
        displayName: 'Smith Family',
        members: [_m('m1', 'Alice Smith')],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ResolveDuplicatesPage(
          repository: repo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No duplicate display names found!'), findsOneWidget);
  });

  testWidgets('ResolveDuplicatesPage allows quick resolution of duplicate members', (tester) async {
    final repo = _FakeRepository();
    repo.families = [
      Family(
        id: 'f1',
        displayName: 'Smith Family',
        members: [_m('m1', 'Alice Smith')],
      ),
      Family(
        id: 'f2',
        displayName: 'Doe Family',
        members: [_m('m2', 'Alice Smith')], // Same display name = duplicate
      ),
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
                    builder: (_) => ResolveDuplicatesPage(
                      repository: repo,
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
    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('Doe Family'), findsOneWidget);

    // Tap more option on Smith Family
    final popMenuFinder = find.byIcon(Icons.more_vert).first;
    await tester.tap(popMenuFinder);
    await tester.pumpAndSettle();

    // Select "Keep only here"
    await tester.tap(find.text('Keep only here'));
    await tester.pumpAndSettle();

    expect(find.text('Keep only in Smith Family'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Apply 1 Resolution'));
    await tester.pumpAndSettle();

    expect(repo.saveCalled, true);
    expect(popResult, true);

    // Verify it was removed from f2 (Doe Family) but kept in f1 (Smith Family)
    final savedF1 = repo.families.firstWhere((f) => f.id == 'f1');
    final savedF2 = repo.families.firstWhere((f) => f.id == 'f2');
    expect(savedF1.members.any((m) => m.displayName == 'Alice Smith'), true);
    expect(savedF2.members.any((m) => m.displayName == 'Alice Smith'), false);
  });
}
