import 'dart:async';

import 'package:attendance_tracker/features/settings/application/app_lock_controller.dart';
import 'package:attendance_tracker/features/settings/presentation/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  Future<AppLockController> controller({
    required bool enabled,
    required LocalAuthentication auth,
  }) async {
    SharedPreferences.setMockInitialValues({'app_lock_enabled': enabled});
    final prefs = await SharedPreferences.getInstance();
    return AppLockController(prefs, auth: auth);
  }

  Widget wrap(AppLockController controller) {
    return MaterialApp(
      home: AppLockGate(
        controller: controller,
        child: const Text('Unlocked content'),
      ),
    );
  }

  testWidgets('shows child without overlay when unlocked', (tester) async {
    final auth = _MockLocalAuth();
    final c = await controller(enabled: false, auth: auth);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(find.text('Unlocked content'), findsOneWidget);
    expect(find.text('Attendance is locked'), findsNothing);
    verifyNever(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        options: any(named: 'options'),
      ),
    );
  });

  testWidgets('keeps lock overlay when automatic unlock fails', (tester) async {
    final auth = _MockLocalAuth();
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => false);
    final c = await controller(enabled: true, auth: auth);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlocked content'), findsOneWidget);
    expect(find.text('Attendance is locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('removes lock overlay after successful unlock', (tester) async {
    final auth = _MockLocalAuth();
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => true);
    final c = await controller(enabled: true, auth: auth);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlocked content'), findsOneWidget);
    expect(find.text('Attendance is locked'), findsNothing);
    expect(c.isLocked, isFalse);
  });

  testWidgets('disables unlock button while authentication is active', (
    tester,
  ) async {
    final auth = _MockLocalAuth();
    final completer = Completer<bool>();
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) => completer.future);
    final c = await controller(enabled: true, auth: auth);

    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(find.textContaining('Authenticating'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    completer.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlock'), findsOneWidget);
  });
}
