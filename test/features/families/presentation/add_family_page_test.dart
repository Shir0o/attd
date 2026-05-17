import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/families/presentation/add_family_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  String? addedFamilyName;
  Object? addFamilyError;

  @override
  Future<Family> addFamily(String displayName) async {
    addedFamilyName = displayName;
    final error = addFamilyError;
    if (error != null) throw error;
    return Family(id: 'family-1', displayName: displayName, members: const []);
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Family>> fetchFamilies() async => [];

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Stream<List<Family>> streamFamilies() => Stream.value([]);
}

void main() {
  testWidgets('validates required family name before saving', (tester) async {
    final repository = FakeAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(home: AddFamilyPage(repository: repository)),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(repository.addedFamilyName, isNull);
  });

  testWidgets('trims family name and pops created family', (tester) async {
    final repository = FakeAttendanceRepository();
    Family? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Family>(
                  MaterialPageRoute(
                    builder: (_) => AddFamilyPage(repository: repository),
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Smith Family  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.addedFamilyName, 'Smith Family');
    expect(result?.displayName, 'Smith Family');
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('shows an error when adding a family fails', (tester) async {
    final repository = FakeAttendanceRepository()
      ..addFamilyError = Exception('disk full');

    await tester.pumpWidget(
      MaterialApp(home: AddFamilyPage(repository: repository)),
    );

    await tester.enterText(find.byType(TextFormField), 'Smith Family');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Error adding family'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
