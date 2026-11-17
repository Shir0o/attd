import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/data/handoff_service.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/handoff/presentation/import_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../handoff_test_support.dart';

HandoffResult _result({String? helper = 'Sam'}) => HandoffResult(
      eventId: 'own-1',
      sessionDate: DateTime(2026, 11, 15),
      helperName: helper,
      marks: [
        HandoffMark(
          memberId: 'm1',
          name: 'Alice',
          status: AttendanceStatus.present,
          recordedAt: DateTime.utc(2026, 11, 15, 10),
        ),
        HandoffMark(
          memberId: 'm2',
          name: 'Bob',
          status: AttendanceStatus.present,
          recordedAt: DateTime.utc(2026, 11, 15, 10),
        ),
        HandoffMark(
          memberId: 'm3',
          name: 'Cy',
          status: AttendanceStatus.absent,
          recordedAt: DateTime.utc(2026, 11, 15, 10),
        ),
      ],
      guests: [
        HandoffGuest(name: 'Vic', recordedAt: DateTime.utc(2026, 11, 15, 10)),
      ],
    );

void main() {
  late FakeHandoffService service;

  setUp(() => service = FakeHandoffService());

  Future<void> pump(
    WidgetTester tester, {
    HandoffResult? result,
    bool disableAnimations = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImportResultPage(
          result: result ?? _result(),
          service: service,
          disableAnimations: disableAnimations,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a summary first and changes nothing', (tester) async {
    await pump(tester);

    expect(find.text('Sunday Service'), findsOneWidget);
    expect(find.text('SUNDAY, NOV 15, 2026'), findsOneWidget);
    expect(find.text('Marked by Sam.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'present');
    expect(find.text('Add to session'), findsOneWidget);
    expect(service.previewed, hasLength(1));
    expect(service.applied, isEmpty);
  });

  testWidgets('says so when the helper gave no name', (tester) async {
    await pump(tester, result: _result(helper: null));
    expect(find.text('Marked by someone who gave no name.'), findsOneWidget);
  });

  testWidgets('Add to session applies the result and says what happened',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('addToSessionButton')));
    await tester.pumpAndSettle();

    expect(service.applied.single.eventId, 'own-1');
    expect(find.text('Added to session'), findsOneWidget);
    expect(find.textContaining('was created'), findsOneWidget);
    expect(find.byKey(const Key('addToSessionButton')), findsNothing);
  });

  testWidgets('merging into an existing session is described as a merge',
      (tester) async {
    service.outcome = const ResultImportOutcome(
      sessionCreated: false,
      changed: true,
      unknownMemberMarks: 0,
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('addToSessionButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('merged into the session'), findsOneWidget);
  });

  testWidgets('a repeated import says nothing new was added', (tester) async {
    service.outcome = const ResultImportOutcome(
      sessionCreated: false,
      changed: false,
      unknownMemberMarks: 0,
    );
    await pump(tester);
    await tester.tap(find.byKey(const Key('addToSessionButton')));
    await tester.pumpAndSettle();
    expect(find.text('Already added'), findsOneWidget);
    expect(find.textContaining('nothing new'), findsOneWidget);
  });

  testWidgets('an unknown event is refused with a clear message',
      (tester) async {
    service.refuse = 'This result is for an event that is not on this phone.';
    await pump(tester);

    expect(find.text('Nothing was added'), findsOneWidget);
    expect(find.textContaining('not on this phone'), findsOneWidget);
    expect(find.byKey(const Key('addToSessionButton')), findsNothing);
    expect(service.applied, isEmpty);
  });

  testWidgets('an event that disappears before adding is refused too',
      (tester) async {
    await pump(tester);
    service.applyError = const HandoffFormatException('Gone since.');
    await tester.tap(find.byKey(const Key('addToSessionButton')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing was added'), findsOneWidget);
    expect(find.text('Gone since.'), findsOneWidget);
  });

  testWidgets('an unexpected failure is reported and can be retried',
      (tester) async {
    await pump(tester);
    service.applyError = StateError('disk full');
    await tester.tap(find.byKey(const Key('addToSessionButton')));
    await tester.pumpAndSettle();
    expect(find.text('Could not add the marks. Try again.'), findsOneWidget);
    expect(find.byKey(const Key('addToSessionButton')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('addToSessionButton')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Cancel closes without adding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ImportResultPage(
                    result: _result(),
                    service: service,
                    disableAnimations: true,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelImportButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ImportResultPage), findsNothing);
    expect(service.applied, isEmpty);
  });

  testWidgets('shows a skeleton for at least 800ms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImportResultPage(result: _result(), service: service),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('handoffSkeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('handoffSkeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('handoffSkeleton')), findsNothing);
    expect(find.byKey(const Key('addToSessionButton')), findsOneWidget);
  });

  testWidgets('buttons are at least 48dp tall', (tester) async {
    await pump(tester);
    for (final key in const [
      Key('addToSessionButton'),
      Key('cancelImportButton'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
  });
}
