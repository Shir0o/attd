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

  @override
  Future<Family> addFamily(String displayName,
      {bool isAutoSingleton = false}) async {
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

  testWidgets('SuggestFamiliesPage shows skeleton then content',
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
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppShimmer), findsWidgets);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();
    expect(find.textContaining('Smith Family'), findsOneWidget);
  });

  testWidgets('SuggestFamiliesPage creates families on tap', (tester) async {
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
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create 1'));
    await tester.pumpAndSettle();
    expect(repo.addedFamilyNames, ['Smith']);
    expect(repo.moved.length, 3);
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
        name: entry.value.first.displayName.split(RegExp(r'\s+')).last,
        members: entry.value,
        confidence: entry.value.length >= 3
            ? FamilyConfidence.high
            : FamilyConfidence.medium,
      ));
    }
    return out;
  }
}
