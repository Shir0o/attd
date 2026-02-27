import 'dart:async';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/family_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAttendanceRepository implements AttendanceRepository {
  List<Family> _families = [];
  Completer<void>? _fetchCompleter;

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
    if (_fetchCompleter != null) {
      await _fetchCompleter!.future;
    }
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
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('FamilyListPage shows loading indicator initially', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.pauseFetch();

    await tester.pumpWidget(
      MaterialApp(home: FamilyListPage(repository: mockRepo)),
    );

    await tester.pump(); // Start the future

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    mockRepo.resumeFetch();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
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
    final family1 = const Family(
      id: '1',
      displayName: 'Doe Family',
      members: [Member(id: 'm1', displayName: 'John Doe')],
    );
    final family2 = const Family(
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
}
