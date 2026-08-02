import 'package:attendance_tracker/core/quick_actions/quick_actions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

class FakeQuickActions extends QuickActions {
  const FakeQuickActions();

  static void Function(String)? handler;
  static List<ShortcutItem>? registeredItems;

  @override
  Future<void> initialize(void Function(String type) actionHandler) async {
    handler = actionHandler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    registeredItems = items;
  }
}

void main() {
  testWidgets('QuickActionsService initializes shortcuts and pops navigator to root',
      (WidgetTester tester) async {
    const fake = FakeQuickActions();
    final service = QuickActionsService(quickActions: fake);
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        initialRoute: '/',
        routes: {
          '/': (_) => const Scaffold(body: Text('Hub Root')),
          '/detail': (_) => const Scaffold(body: Text('Detail Screen')),
        },
      ),
    );
    await tester.pumpAndSettle();

    await service.initialize(navigatorKey: navKey);

    expect(FakeQuickActions.registeredItems, isNotNull);
    expect(FakeQuickActions.registeredItems!.length, 1);
    expect(
      FakeQuickActions.registeredItems!.first.type,
      QuickActionsService.takeAttendanceType,
    );

    // Push a nested route onto the navigator
    navKey.currentState!.pushNamed('/detail');
    await tester.pumpAndSettle();
    expect(find.text('Detail Screen'), findsOneWidget);

    // Invoke handler with take_attendance type -> pops back to root
    FakeQuickActions.handler?.call('take_attendance');
    await tester.pumpAndSettle();

    expect(find.text('Hub Root'), findsOneWidget);
    expect(find.text('Detail Screen'), findsNothing);

    // Invoke handler with unknown type -> no-op
    expect(() => FakeQuickActions.handler?.call('unknown_action'), returnsNormally);
  });
}
