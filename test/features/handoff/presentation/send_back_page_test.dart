import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/handoff/presentation/send_back_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../handoff_test_support.dart';

void main() {
  late FakeSharer sharer;
  late FakeHandoffService service;
  late FakeSessions sessions;

  setUp(() {
    sharer = FakeSharer();
    service = FakeHandoffService();
    sessions = FakeSessions([markedSession()]);
  });

  Future<void> pump(WidgetTester tester, {bool disableAnimations = true}) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('home'))),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SendBackPage(
          event: handedOffEvent(),
          session: markedSession(),
          sessionRepository: sessions,
          service: service,
          sharer: sharer,
          disableAnimations: disableAnimations,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the tally of present, absent and guests', (tester) async {
    await pump(tester);

    expect(find.text('Sunday Service'), findsOneWidget);
    expect(find.text('Send back'), findsWidgets);
    expect(find.text('PRESENT'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3), reason: 'one of each');
    expect(find.text('Absent'.toUpperCase()), findsOneWidget);
    expect(find.text('Guests'.toUpperCase()), findsOneWidget);
  });

  testWidgets('loads behind a skeleton that lasts at least 800ms',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SendBackPage(
          event: handedOffEvent(),
          session: markedSession(),
          sessionRepository: sessions,
          service: service,
          sharer: sharer,
          disableAnimations: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('handoffSkeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('handoffSkeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('handoffSkeleton')), findsNothing);
    expect(find.byKey(const Key('sendBackButton')), findsOneWidget);
  });

  testWidgets('Send back opens the share sheet with the result file',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('sendBackNameField')), ' Sam ');
    await tester.tap(find.byKey(const Key('sendBackButton')));
    await tester.pumpAndSettle();

    final sent = sharer.sent.single;
    final result = sent.document as HandoffResult;
    expect(result.eventId, 'ev-1', reason: 'the owner\'s id, prefix removed');
    expect(result.helperName, 'Sam');
    expect(result.sessionDate, DateTime(2026, 11, 15));
    expect(result.marks.map((m) => m.memberId), ['m1', 'm2']);
    expect(result.marks.last.status, AttendanceStatus.absent);
    expect(result.guests.single.name, 'Visitor Vic');
    expect(sent.fileName, matches(RegExp(r'^sunday-service-2026-11-15-marks\.')));
    expect(HandoffCodec.encode(result), isNotEmpty);
  });

  testWidgets('the name is optional', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('sendBackButton')));
    await tester.pumpAndSettle();
    expect((sharer.sent.single.document as HandoffResult).helperName, isNull);
  });

  testWidgets('a share failure is reported and Send back stays available',
      (tester) async {
    sharer.fail = true;
    await pump(tester);

    await tester.tap(find.byKey(const Key('sendBackButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not prepare'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('sendBackButton')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Remove asks first, then removes and returns home',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('removeHandedOffButton')));
    await tester.pumpAndSettle();
    expect(find.text('Remove from this phone?'), findsOneWidget);
    expect(find.textContaining('Your own events and members are not touched'),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.removed, isEmpty);

    await tester.tap(find.byKey(const Key('removeHandedOffButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmRemoveHandedOff')));
    await tester.pumpAndSettle();

    expect(service.removed.single.id, 'handoff:ev-1');
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(SendBackPage), findsNothing);
  });

  testWidgets('targets are at least 48dp tall', (tester) async {
    await pump(tester);
    for (final key in const [
      Key('sendBackButton'),
      Key('removeHandedOffButton'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
  });
}
