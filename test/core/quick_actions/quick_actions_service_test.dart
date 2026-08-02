import 'package:attendance_tracker/core/quick_actions/quick_actions_service.dart';
import 'package:flutter/widgets.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('QuickActionsService initializes shortcuts and handles take_attendance',
      () async {
    const fake = FakeQuickActions();
    final service = QuickActionsService(quickActions: fake);
    final navKey = GlobalKey<NavigatorState>();

    await service.initialize(navigatorKey: navKey);

    expect(FakeQuickActions.registeredItems, isNotNull);
    expect(FakeQuickActions.registeredItems!.length, 1);
    expect(
      FakeQuickActions.registeredItems!.first.type,
      QuickActionsService.takeAttendanceType,
    );

    // Invoke handler with take_attendance type
    expect(() => FakeQuickActions.handler?.call('take_attendance'), returnsNormally);
    // Invoke handler with unknown type
    expect(() => FakeQuickActions.handler?.call('unknown_action'), returnsNormally);
  });
}
