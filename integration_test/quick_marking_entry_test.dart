import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_roster_list.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';

/// "02 Quick marking" — the start mode chosen when beginning a session
/// determines the entry view:
///   - All absent      -> speed-swipe deck (mark each present)
///   - All present      -> roster List view (toggle off exceptions)
///   - Smart defaults    -> roster List view (toggle exceptions)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Quick marking entry view', () {
    Future<Directory> bootstrap(
      WidgetTester tester,
      String eventName,
      List<String> memberNames,
    ) async {
      final tempDir = await Directory.systemTemp.createTemp('quick_marking_');
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

      return tempDir;
    }

    testWidgets('All absent -> speed-swipe deck', (tester) async {
      final tempDir = await bootstrap(
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

      // Deck view: swipe cards present, no roster list.
      await tester.pumpUntilFound(find.byType(SwipeableCard));
      expect(find.byType(SwipeableCard), findsWidgets);
      expect(find.byType(AttendanceRosterList), findsNothing);

      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets('All present -> roster list, everyone present', (tester) async {
      final tempDir = await bootstrap(
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

      // List view: roster present, no swipe deck.
      await tester.pumpUntilFound(find.byType(AttendanceRosterList));
      expect(find.byType(AttendanceRosterList), findsOneWidget);
      expect(find.byType(SwipeableCard), findsNothing);

      // Roster renders every member as a toggle row (preseeded present).
      expect(find.text('Alice Present'), findsOneWidget);
      expect(find.text('Bob Present'), findsOneWidget);
      expect(find.text('Carol Present'), findsOneWidget);

      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    testWidgets('Smart defaults -> roster list', (tester) async {
      final tempDir = await bootstrap(
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

      // Smart defaults also open directly in the roster List view.
      await tester.pumpUntilFound(find.byType(AttendanceRosterList));
      expect(find.byType(AttendanceRosterList), findsOneWidget);
      expect(find.byType(SwipeableCard), findsNothing);

      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
  });
}
