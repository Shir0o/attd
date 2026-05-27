import 'dart:async';

import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/family_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAttendanceRepository extends AttendanceRepository {
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

  String? movedMemberId;
  String? movedTargetFamilyId;

  @override
  Future<Family> moveMemberToFamily(
    String memberId,
    String targetFamilyId,
  ) async {
    movedMemberId = memberId;
    movedTargetFamilyId = targetFamilyId;
    return _families.first;
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
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
    expect(find.text('1 member'), findsOneWidget);
    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('0 members'), findsOneWidget);
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

    expect(find.text('MEMBERS'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Manage Families'), findsOneWidget);
    expect(mockRepo.fetchCount, 2);
  });

  testWidgets(
    'FamilyListPage surfaces suggestion banner when auto-singletons exist',
    (tester) async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.setFamilies([
        Family(
          id: 'auto-1',
          displayName: 'Alice Smith',
          isAutoSingleton: true,
          members: [Member(id: 'm1', displayName: 'Alice Smith')],
        ),
        Family(
          id: 'auto-2',
          displayName: 'Bob Smith',
          isAutoSingleton: true,
          members: [Member(id: 'm2', displayName: 'Bob Smith')],
        ),
        Family(
          id: 'auto-3',
          displayName: 'Carol Smith',
          isAutoSingleton: true,
          members: [Member(id: 'm3', displayName: 'Carol Smith')],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyListPage(
            repository: mockRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('possible families spotted'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      // 800ms delay inside suggest page bypassed via disableAnimations on
      // the suggest page too, but FamilyListPage doesn't forward the flag.
      // Pump enough to settle the delay.
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pumpAndSettle();
      expect(find.textContaining('Smith Family'), findsOneWidget);
    },
  );

  testWidgets('FamilyListPage refreshes after suggest screen creates families',
      (tester) async {
    final mockRepo = MockAttendanceRepository();
    mockRepo.setFamilies([
      Family(
        id: 'auto-1',
        displayName: 'Alice Smith',
        isAutoSingleton: true,
        members: [Member(id: 'm1', displayName: 'Alice Smith')],
      ),
      Family(
        id: 'auto-2',
        displayName: 'Bob Smith',
        isAutoSingleton: true,
        members: [Member(id: 'm2', displayName: 'Bob Smith')],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: FamilyListPage(
          repository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Create 1'));
    await tester.pumpAndSettle();
    // Initial fetch + reload after pop with created:true.
    expect(mockRepo.fetchCount, greaterThanOrEqualTo(2));
    expect(mockRepo.addedFamilyName, 'Smith');
  });

  testWidgets(
    'FamilyListPage surfaces suggestion banner for single-member families where isAutoSingleton is false',
    (tester) async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.setFamilies([
        Family(
          id: 'manual-1',
          displayName: 'Alice Smith',
          isAutoSingleton: false,
          members: [Member(id: 'm1', displayName: 'Alice Smith')],
        ),
        Family(
          id: 'manual-2',
          displayName: 'Bob Smith',
          isAutoSingleton: false,
          members: [Member(id: 'm2', displayName: 'Bob Smith')],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyListPage(
            repository: mockRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('possible families spotted'), findsOneWidget);
    },
  );

  testWidgets(
    'FamilyListPage filters out auto-singleton families but displays Solo Members banner',
    (tester) async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.setFamilies([
        Family(
          id: 'manual-1',
          displayName: 'Smith Family',
          isAutoSingleton: false,
          members: [
            Member(id: 'm1', displayName: 'Alice Smith'),
            Member(id: 'm3', displayName: 'Charlie Smith'),
          ],
        ),
        Family(
          id: 'auto-1',
          displayName: 'Bob Jones',
          isAutoSingleton: true,
          members: [Member(id: 'm2', displayName: 'Bob Jones')],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyListPage(
            repository: mockRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Smith Family should be shown
      expect(find.text('Smith Family'), findsOneWidget);

      // Solo Members banner should be shown with Bob Jones listed
      expect(find.textContaining('Solo Members (1)'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
    },
  );

  testWidgets(
    'FamilyListPage displays Duplicate Members banner when a member is in multiple real families',
    (tester) async {
      final mockRepo = MockAttendanceRepository();
      mockRepo.setFamilies([
        Family(
          id: '1',
          displayName: 'Smith Family',
          members: [Member(id: 'm1', displayName: 'Alice Smith')],
        ),
        Family(
          id: '2',
          displayName: 'Doe Family',
          members: [Member(id: 'm1', displayName: 'Alice Smith')],
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyListPage(
            repository: mockRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Duplicate Members Detected banner should be shown
      expect(find.text('Duplicate Members Detected'), findsOneWidget);
      expect(find.textContaining('Alice Smith is in: Smith Family and Doe Family'), findsOneWidget);
    },
  );
}
