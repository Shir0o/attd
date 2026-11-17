import 'dart:convert';
import 'dart:io';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The Families screens are gone, but families.json is still where members
// live. These tests pin that stored family groupings are left exactly as they
// are and that every person in them still shows up once.

Map<String, dynamic> _member(
  String id,
  String name, {
  String? deletedAt,
}) =>
    {
      'id': id,
      'displayName': name,
      'canonicalName': name,
      'mergedIntoMemberId': null,
      'isVisitor': false,
      'labels': {'autoLabels': <String>[], 'manualLabels': <String>[]},
      'updatedAt': '2026-03-01T10:00:00.123456',
      if (deletedAt != null) 'deletedAt': deletedAt,
    };

Map<String, dynamic> _family(
  String id,
  String name,
  List<Map<String, dynamic>> members, {
  bool isAutoSingleton = false,
  String? mergedIntoFamilyId,
  List<String> manualLabels = const [],
  String? deletedAt,
}) =>
    {
      'id': id,
      'displayName': name,
      'canonicalName': name,
      'mergedIntoFamilyId': mergedIntoFamilyId,
      'members': members,
      'labels': {'autoLabels': <String>[], 'manualLabels': manualLabels},
      'updatedAt': '2026-03-02T09:30:00.000',
      if (deletedAt != null) 'deletedAt': deletedAt,
      'isAutoSingleton': isAutoSingleton,
    };

/// families.json as an existing install holds it: households with several
/// members, a person listed under two households, a person listed under a
/// household and a leftover auto-singleton, people with no household, and
/// tombstones.
final String _storedJson = jsonEncode([
  _family('fam-garcia', 'Garcia', [
    _member('m-ana', 'Ana Garcia'),
    _member('m-ben', 'Ben Garcia'),
    _member('m-old', 'Old Garcia', deletedAt: '2026-02-01T08:00:00.000'),
  ]),
  _family(
    'fam-wang',
    'Wang Household',
    [_member('m-tony', 'Tony Wang'), _member('m-ana', 'Ana Garcia')],
    manualLabels: ['follow-up'],
  ),
  _family(
    'solo-ben',
    'Ben Garcia',
    [_member('m-ben', 'Ben Garcia')],
    isAutoSingleton: true,
  ),
  _family(
    'solo-dee',
    'Dee Solo',
    [_member('m-dee', 'Dee Solo')],
    isAutoSingleton: true,
  ),
  _family(
    'fam-park',
    'Park',
    [_member('m-eve', 'Eve Park')],
    mergedIntoFamilyId: 'fam-garcia',
  ),
  _family(
    'fam-gone',
    'Gone',
    [_member('m-gone', 'Gone Person')],
    deletedAt: '2026-01-15T12:00:00.000',
  ),
]);

const _livePeople = [
  'Ana Garcia',
  'Ben Garcia',
  'Dee Solo',
  'Eve Park',
  'Tony Wang',
];

void main() {
  late Directory tempDir;
  late File file;

  LocalJsonAttendanceRepository openRepo() =>
      LocalJsonAttendanceRepository(storagePath: file.path);

  Future<void> writeStored() async {
    tempDir = await Directory.systemTemp.createTemp('attd-stored-families');
    file = File('${tempDir.path}/families.json');
    await file.writeAsString(_storedJson);
  }

  Future<void> removeStored() => tempDir.delete(recursive: true);

  group('stored family groupings', () {
    setUp(writeStored);
    tearDown(removeStored);

    test('load with every live person present, whatever family holds them',
        () async {
      final families = await openRepo().fetchFamilies();

      // Groupings are still there, untouched.
      expect(families.map((f) => f.id), [
        'fam-garcia',
        'fam-wang',
        'solo-ben',
        'solo-dee',
        'fam-park',
      ]);
      expect(
        families.firstWhere((f) => f.id == 'fam-garcia').members.length,
        2,
      );

      // Listed under two families is still one person.
      final byId = <String, Member>{
        for (final f in families)
          for (final m in f.members) m.id: m,
      };
      expect(
        byId.values.map((m) => m.displayName).toList()..sort(),
        _livePeople,
      );
    });

    test('reading never rewrites the file', () async {
      final repo = openRepo();
      await repo.fetchFamilies();
      await repo.fetchAllFamilies();
      await repo.streamFamilies().first;
      await repo.refresh();

      expect(await file.readAsString(), _storedJson);
      expect(await File('${file.path}.bak').exists(), isFalse);
    });

    test('round-trip through the repository byte for byte', () async {
      final repo = openRepo();
      await repo.saveFamilies(await repo.fetchAllFamilies());
      expect(await file.readAsString(), _storedJson);

      // And again from a cold start.
      final reopened = openRepo();
      await reopened.saveFamilies(await reopened.fetchAllFamilies());
      expect(await file.readAsString(), _storedJson);
    });

    test('adding a member keeps every existing record and reloads', () async {
      final repo = openRepo();
      // How every add in the app stores a new person.
      final holder = await repo.addFamily('Nia New', isAutoSingleton: true);
      await repo.addMember(
        holder.id,
        Member(id: 'm-nia', displayName: 'Nia New'),
      );

      final stored = jsonDecode(await file.readAsString()) as List<dynamic>;
      final before = jsonDecode(_storedJson) as List<dynamic>;
      expect(stored.sublist(0, before.length), before);
      expect(stored.length, before.length + 1);
      final added = stored.last as Map<String, dynamic>;
      expect(added['isAutoSingleton'], isTrue);
      expect(added['displayName'], 'Nia New');
      expect((added['members'] as List).single['id'], 'm-nia');

      final reloaded = await openRepo().fetchFamilies();
      expect(
        reloaded.expand((f) => f.members).map((m) => m.id).toSet(),
        {'m-ana', 'm-ben', 'm-tony', 'm-dee', 'm-eve', 'm-nia'},
      );
    });
  });

  group('Manage Members over stored family groupings', () {
    late LocalJsonAttendanceRepository repo;

    // File IO needs the real event loop; warming the repository's cache lets
    // the page load under the test's fake clock.
    Future<void> pumpMembersPage(WidgetTester tester) async {
      await tester.runAsync(() async {
        await writeStored();
        repo = openRepo();
        await repo.fetchFamilies();
      });
      addTearDown(() => tester.runAsync(removeStored));

      await tester.pumpWidget(
        MaterialApp(
          home: MembersPage(
            attendanceRepository: repo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists each person once with no family labels', (tester) async {
      await pumpMembersPage(tester);

      expect(find.text('5 people'), findsOneWidget);
      for (final name in _livePeople) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Old Garcia'), findsNothing);
      expect(find.text('Gone Person'), findsNothing);
      expect(find.textContaining('GARCIA ·'), findsNothing);
      expect(find.textContaining('Wang Household'), findsNothing);
      expect(find.textContaining('LONERS'), findsNothing);
      expect(
        find.textContaining(RegExp('famil', caseSensitive: false)),
        findsNothing,
      );

      // Showing them changed nothing on disk.
      expect(await tester.runAsync(file.readAsString), _storedJson);
    });

    testWidgets('adding someone persists and survives a reload',
        (tester) async {
      await pumpMembersPage(tester);

      await tester.enterText(
        find.byKey(const ValueKey('member_search_field')),
        'Nia New',
      );
      await tester.runAsync(() async {
        // The save is real file IO; the repository emits once it has landed.
        final saved = repo.streamFamilies().firstWhere(
              (families) => families.any(
                (f) => f.members.any((m) => m.displayName == 'Nia New'),
              ),
            );
        await tester.tap(find.byKey(const ValueKey('member_add_fab')));
        await saved;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('6 people'), findsOneWidget);
      expect(find.text('Nia New'), findsWidgets);

      final stored = (await tester.runAsync(
        () async => jsonDecode(await file.readAsString()) as List<dynamic>,
      ))!;
      final before = jsonDecode(_storedJson) as List<dynamic>;
      expect(stored.sublist(0, before.length), before);
      expect(stored.length, before.length + 1);
      final added = stored.last as Map<String, dynamic>;
      expect(added['isAutoSingleton'], isTrue);
      expect((added['members'] as List).single['displayName'], 'Nia New');

      final reloaded =
          (await tester.runAsync(() => openRepo().fetchFamilies()))!;
      expect(
        reloaded.expand((f) => f.members).map((m) => m.displayName),
        contains('Nia New'),
      );
    });
  });
}
