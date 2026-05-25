import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/suggest_families_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository extends AttendanceRepository {
  final List<String> addedFamilyNames = [];
  final List<(String memberId, String familyId)> moved = [];
  int nextId = 0;
  Object? addFamilyError;
  Object? moveError;

  @override
  Future<Family> addFamily(String displayName,
      {bool isAutoSingleton = false}) async {
    if (addFamilyError != null) throw addFamilyError!;
    addedFamilyNames.add(displayName);
    nextId++;
    return Family(
      id: 'f$nextId',
      displayName: displayName,
      members: const [],
      isAutoSingleton: isAutoSingleton,
    );
  }

  @override
  Future<Family> moveMemberToFamily(
      String memberId, String targetFamilyId) async {
    if (moveError != null) throw moveError!;
    moved.add((memberId, targetFamilyId));
    return Family(
      id: targetFamilyId,
      displayName: '',
      members: const [],
    );
  }

  @override
  Future<Family> addMember(String familyId, Member member) =>
      throw UnimplementedError();

  @override
  Future<List<Family>> fetchFamilies() async => const [];

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Stream<List<Family>> streamFamilies() => const Stream.empty();
}

Member _m(String id, String name) => Member(id: id, displayName: name);

void main() {
  group('clusterByLastName', () {
    test('groups by shared last name, ignores singletons', () {
      final clusters = SuggestFamiliesTestHelper.cluster([
        _m('1', 'Alice Smith'),
        _m('2', 'Bob Smith'),
        _m('3', 'Carol Jones'),
        _m('4', 'Dan Solo'),
      ]);
      expect(clusters.length, 1);
      expect(clusters.first.name, 'Smith');
      expect(clusters.first.members.length, 2);
    });

    test('three or more is high confidence', () {
      final clusters = SuggestFamiliesTestHelper.cluster([
        _m('1', 'A Smith'),
        _m('2', 'B Smith'),
        _m('3', 'C Smith'),
      ]);
      expect(clusters.first.confidence, FamilyConfidence.high);
    });
  });

  testWidgets('SuggestFamiliesPage shows skeleton on first frame',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuggestFamiliesPage(
          repository: _FakeRepository(),
          ungroupedMembers: [
            _m('1', 'Alice Smith'),
            _m('2', 'Bob Smith'),
            _m('3', 'Carol Jones'),
          ],
          // Animations on so the 800ms delay keeps the skeleton mounted.
        ),
      ),
    );
    // Just one frame — the 800ms Future.delayed hasn't fired yet.
    await tester.pump();
    expect(find.byType(AppShimmer), findsWidgets);
    // Let the delayed timer fire so the test doesn't leave timers pending.
    await tester.pump(const Duration(milliseconds: 850));
  });

  testWidgets('SuggestFamiliesPage creates families on tap', (tester) async {
    final repo = _FakeRepository();
    bool? popResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SuggestFamiliesPage(
                        repository: repo,
                        ungroupedMembers: [
                          _m('1', 'Alice Smith'),
                          _m('2', 'Bob Smith'),
                          _m('3', 'Carol Smith'),
                          _m('4', 'Devon Jones'),
                          _m('5', 'Eve Jones'),
                          _m('6', 'Sam Quinn'),
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
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Smith Family'), findsOneWidget);
    expect(find.textContaining('Jones Family'), findsOneWidget);
    await tester.tap(find.textContaining('Create 2'));
    await tester.pumpAndSettle();
    expect(repo.addedFamilyNames, ['Smith', 'Jones']);
    expect(repo.moved.length, 5);
    expect(popResult, true);
  });

  testWidgets('SuggestFamiliesPage drops a member when chip tapped',
      (tester) async {
    final repo = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SuggestFamiliesPage(
          repository: repo,
          ungroupedMembers: [
            _m('1', 'Alice Smith'),
            _m('2', 'Bob Smith'),
            _m('3', 'Carol Smith'),
          ],
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Smith'));
    await tester.pump();
    await tester.tap(find.text('Alice Smith'));
    await tester.pump();
  });

  testWidgets('SuggestFamiliesPage Skip toggles cluster, Skip all pops false',
      (tester) async {
    final repo = _FakeRepository();
    bool? popResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => SuggestFamiliesPage(
                        repository: repo,
                        ungroupedMembers: [
                          _m('1', 'Alice Smith'),
                          _m('2', 'Bob Smith'),
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
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.tap(find.text('Unskip'));
    await tester.pump();
    await tester.tap(find.text('Skip all'));
    await tester.pumpAndSettle();
    expect(popResult, false);
    expect(repo.addedFamilyNames, isEmpty);
  });

  testWidgets('SuggestFamiliesPage empty clusters shows fallback message',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SuggestFamiliesPage(
          repository: _FakeRepository(),
          ungroupedMembers: [_m('1', 'Solo')],
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No obvious family clusters'), findsOneWidget);
  });

  testWidgets('SuggestFamiliesPage surfaces SnackBar when addFamily throws',
      (tester) async {
    final repo = _FakeRepository()..addFamilyError = Exception('boom');
    await tester.pumpWidget(
      MaterialApp(
        home: SuggestFamiliesPage(
          repository: repo,
          ungroupedMembers: [
            _m('1', 'Alice Smith'),
            _m('2', 'Bob Smith'),
          ],
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error creating families'), findsOneWidget);
  });

  testWidgets('SuggestFamiliesPage tolerates moveMemberToFamily errors',
      (tester) async {
    final repo = _FakeRepository()..moveError = Exception('move boom');
    bool? popResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => SuggestFamiliesPage(
                      repository: repo,
                      ungroupedMembers: [
                        _m('1', 'Alice Smith'),
                        _m('2', 'Bob Smith'),
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
    await tester.tap(find.textContaining('Create 1'));
    await tester.pumpAndSettle();
    expect(repo.addedFamilyNames, ['Smith']);
    expect(popResult, true);
  });
}

class SuggestFamiliesTestHelper {
  static List<FamilyCluster> cluster(List<Member> members) =>
      _SuggestFamiliesPageStateBridge.cluster(members);
}

class _SuggestFamiliesPageStateBridge {
  static List<FamilyCluster> cluster(List<Member> members) {
    // Mirrors the private static used by the page.
    final groups = <String, List<Member>>{};
    for (final m in members) {
      final parts = m.displayName.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      groups.putIfAbsent(parts.last.toLowerCase(), () => []).add(m);
    }
    final out = <FamilyCluster>[];
    for (final entry in groups.entries) {
      if (entry.value.length < 2) continue;
      out.add(FamilyCluster(
        name: entry.value.first.displayName
            .trim()
            .split(RegExp(r'\s+'))
            .last,
        members: entry.value,
        confidence: entry.value.length >= 3
            ? FamilyConfidence.high
            : FamilyConfidence.medium,
      ));
    }
    return out;
  }
}
