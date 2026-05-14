import 'package:flutter/widgets.dart';
import 'package:quick_actions/quick_actions.dart';

/// Registers home-screen / launcher long-press shortcuts.
///
/// iOS surfaces these as Home Screen Quick Actions; Android surfaces them as
/// dynamic App Shortcuts. The single "take_attendance" action brings the app
/// to the foreground on the Hub events list — the same screen as a normal
/// launch, but we also pop any deep navigation so the user lands ready to
/// pick an event.
class QuickActionsService {
  QuickActionsService({QuickActions? quickActions})
      : _quickActions = quickActions ?? const QuickActions();

  static const takeAttendanceType = 'take_attendance';

  final QuickActions _quickActions;

  /// Initializes shortcuts and routes incoming shortcut taps.
  ///
  /// [navigatorKey] is used to pop to the root route so the user always
  /// lands on the hub when invoking the shortcut.
  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _quickActions.initialize((type) {
      if (type == takeAttendanceType) {
        final nav = navigatorKey.currentState;
        nav?.popUntil((route) => route.isFirst);
      }
    });

    await _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: takeAttendanceType,
        localizedTitle: 'Take Attendance',
      ),
    ]);
  }
}
