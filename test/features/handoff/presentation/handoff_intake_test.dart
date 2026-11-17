import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/handoff/presentation/handoff_intake.dart';
import 'package:attendance_tracker/features/handoff/presentation/import_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../handoff_test_support.dart';

Uint8List _handoffBytes() => HandoffCodec.encodeBytes(
      HandoffRoster(
        eventId: 'ev-1',
        eventTitle: 'Sunday Service',
        sessionDate: DateTime(2026, 11, 15),
        roster: const [HandoffPerson(id: 'm1', name: 'Alice')],
      ),
    );

Uint8List _resultBytes() => HandoffCodec.encodeBytes(
      HandoffResult(
        eventId: 'own-1',
        sessionDate: DateTime(2026, 11, 15),
        marks: [
          HandoffMark(
            memberId: 'm1',
            name: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: DateTime.utc(2026, 11, 15, 10),
          ),
        ],
        guests: const [],
      ),
    );

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late FakeHandoffService service;
  late HandoffIntake intake;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    service = FakeHandoffService();
    intake = HandoffIntake(
      navigatorKey: navigatorKey,
      service: service,
      disableAnimations: true,
    );
  });

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ),
      );

  testWidgets('a handoff is added as someone else\'s event', (tester) async {
    await pumpApp(tester);

    final done = intake.open(_handoffBytes());
    await tester.pumpAndSettle();

    expect(service.received.single.eventId, 'ev-1');
    expect(find.text('Added to your events'), findsOneWidget);
    expect(find.textContaining('someone else'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await done;
  });

  testWidgets('a result opens the review page and nothing is applied',
      (tester) async {
    await pumpApp(tester);

    intake.open(_resultBytes());
    await tester.pumpAndSettle();

    expect(find.byType(ImportResultPage), findsOneWidget);
    expect(service.applied, isEmpty);
  });

  testWidgets('a damaged file is explained and nothing is saved',
      (tester) async {
    await pumpApp(tester);

    intake.open(Uint8List.fromList(utf8.encode('not a handoff file')));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the file'), findsOneWidget);
    expect(find.textContaining('not an Attendance Tracker'), findsOneWidget);
    expect(service.received, isEmpty);
  });

  testWidgets('an oversized file is refused before it is parsed',
      (tester) async {
    await pumpApp(tester);

    intake.open(Uint8List(HandoffLimits.maxBytes + 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('too large'), findsOneWidget);
    expect(service.received, isEmpty);
  });

  testWidgets('a refused handoff shows the reason', (tester) async {
    service.receiveError = const HandoffFormatException('It clashes.');
    await pumpApp(tester);

    intake.open(_handoffBytes());
    await tester.pumpAndSettle();

    expect(find.text('Could not add this event'), findsOneWidget);
    expect(find.text('It clashes.'), findsOneWidget);
  });

  testWidgets('an unexpected failure saving a handoff is reported',
      (tester) async {
    service.receiveError = StateError('disk full');
    await pumpApp(tester);

    intake.open(_handoffBytes());
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing was changed'), findsOneWidget);
  });

  testWidgets('does nothing before the app has a navigator', (tester) async {
    await intake.open(_resultBytes());
    await intake.open(Uint8List.fromList([1, 2, 3]));
    await intake.open(_handoffBytes());
    expect(service.received, hasLength(1));
  });
}
