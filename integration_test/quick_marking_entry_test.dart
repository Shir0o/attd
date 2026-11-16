import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_roster_list.dart';
import 'package:attendance_tracker/features/attendance/presentation/fast_marking/likely_here_view.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';

/// "02 Quick marking" — whichever start mode is chosen when beginning a
/// session, the marking page is the name grid. A bulk start (all present, smart
/// defaults) simply arrives with those people already marked.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Quick marking entry view', () {
    Future<void> bootstrap(
      WidgetTester tester,
      String eventName,
      List<String> memberNames,
    ) async {
      final tempDir = await Directory.systemTemp.createTemp('quick_marking_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final app = await createTestApp(tempDir);
      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);

      // Skip onboarding.
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Create an event scheduled for today so it is immediately startable.
      await hub.tapFab();
      await event.enterName(eventName);
      final today = const [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
      ][DateTime.now().weekday % 7];
      await event.selectDay(today);
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      // Add members.
      await hub.tapEventMenu(eventName);
      await hub.selectMenuOption('Manage Members');
      for (final name in memberNames) {
        await members.addMember(name);
      }
      await hub.goBack();
    }

    testWidgets('All absent -> the grid, nobody marked', (tester) async {
      await bootstrap(
        tester,
        'Absent Event',
        ['Alice Absent', 'Bob Absent'],
      );

      final hub = HubRobot(tester);
      await hub.tapEventCardWithMode(
        'Absent Event',
        AttendanceStartMode.allAbsent,
      );
      await tester.pumpAndSettle();

      await tester.pumpUntilFound(find.byType(LikelyHereView));
      expect(find.byType(LikelyHereView), findsOneWidget);
      expect(find.byType(AttendanceRosterList), findsNothing);
      expect(find.text('2 left'), findsOneWidget);
    });

    testWidgets('All present -> the grid, everyone marked', (tester) async {
      await bootstrap(
        tester,
        'Present Event',
        ['Alice Present', 'Bob Present', 'Carol Present'],
      );

      final hub = HubRobot(tester);
      await hub.tapEventCardWithMode(
        'Present Event',
        AttendanceStartMode.allPresent,
      );
      await tester.pumpAndSettle();

      await tester.pumpUntilFound(find.byType(LikelyHereView));
      expect(find.byType(LikelyHereView), findsOneWidget);
      expect(find.byType(AttendanceRosterList), findsNothing);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('0 left'), findsOneWidget);
    });

    testWidgets('Smart defaults -> the grid', (tester) async {
      await bootstrap(
        tester,
        'Smart Event',
        ['Alice Smart', 'Bob Smart'],
      );

      final hub = HubRobot(tester);
      await hub.tapEventCardWithMode(
        'Smart Event',
        AttendanceStartMode.perMemberDefault,
      );
      await tester.pumpAndSettle();

      await tester.pumpUntilFound(find.byType(LikelyHereView));
      expect(find.byType(LikelyHereView), findsOneWidget);
      expect(find.byType(AttendanceRosterList), findsNothing);
    });
  });
}
