import 'dart:async';

import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/family_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAttendanceRepository implements AttendanceRepository {
  List<Family> _families = [];
  Completer<void>? _fetchCompleter;
  int fetchCount = 0;
  String? addedFamilyName;

  void setFamilies(List<Family> families) {
    _families = families;
  }

  void pauseFetch() {
    _fetchCompleter = Completer<void>();
  }

  void resumeFetch() {
    _fetchCompleter?.complete();
    _fetchCompleter = null;
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    fetchCount++;
    if (_fetchCompleter != null) {
      await _fetchCompleter!.future;
    }
    if (fetchError != null) throw fetchError!;
    return _families;
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _families = families;
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName) async {
    addedFamilyName = displayName;
    final family = Family(
      id: 'family-${_families.length + 1}',
      displayName: displayName,
      members: const [],
    );
    _families = [..._families, family];
    return family;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  Object? fetchError;

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value(_families);
  }
}

void main() {
  testWidgets('FamilyListPage shows loading indicator initially', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.pauseFetch();

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyListPage(
          repository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump(); // Start the future

    expect(find.byType(AppShimmer), findsWidgets);

    mockRepo.resumeFetch();
    await tester.pumpAndSettle();

    expect(find.byType(AppShimmer), findsNothing);
  });

  testWidgets('FamilyListPage shows error message when fetching fails',
      (WidgetTester tester) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.fetchError = Exception('disk unavailable');

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('FamilyListPage shows empty message when no families', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.setFamilies([]);

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No families found. Add one!'), findsOneWidget);
  });

  testWidgets('FamilyListPage shows list of families', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    final family1 = Family(
      id: '1',
      displayName: 'Doe Family',
      members: [Member(id: 'm1', displayName: 'John Doe')],
    );
    final family2 = Family(
      id: '2',
      displayName: 'Smith Family',
      members: [],
    );

    mockRepo.setFamilies([family1, family2]);

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Doe Family'), findsOneWidget);
    expect(find.text('1 members'), findsOneWidget);
    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('0 members'), findsOneWidget);

    // Accessibility check
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('FamilyListPage opens add flow and reloads after save', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.setFamilies([]);

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add Family'));
    await tester.pumpAndSettle();

    expect(find.text('Add Family'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '  Parker Family  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(mockRepo.addedFamilyName, 'Parker Family');
    expect(mockRepo.fetchCount, 2);
    expect(find.text('Parker Family'), findsOneWidget);
  });

  testWidgets('FamilyListPage opens details and reloads when returning', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.setFamilies([
      Family(
        id: '1',
        displayName: 'Doe Family',
        members: [Member(id: 'm1', displayName: 'John Doe')],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Doe Family'));
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Manage Families'), findsOneWidget);
    expect(mockRepo.fetchCount, 2);
  });
}
