import 'package:attendance_tracker/features/settings/application/app_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  group('AppLockController', () {
    late SharedPreferences prefs;
    late _MockLocalAuth auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      auth = _MockLocalAuth();
      when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    });

    test('starts disabled and unlocked when no preference saved', () {
      final c = AppLockController(prefs, auth: auth);
      expect(c.isEnabled, isFalse);
      expect(c.isLocked, isFalse);
    });

    test('starts locked on cold start when previously enabled', () async {
      await prefs.setBool('app_lock_enabled', true);
      final c = AppLockController(prefs, auth: auth);
      expect(c.isEnabled, isTrue);
      expect(c.isLocked, isTrue);
    });

    test('enable() requires successful authentication', () async {
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => false);

      final c = AppLockController(prefs, auth: auth);
      expect(await c.enable(), isFalse);
      expect(c.isEnabled, isFalse);
      expect(prefs.getBool('app_lock_enabled'), anyOf(isNull, isFalse));
    });

    test('enable() persists when authentication succeeds', () async {
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => true);

      final c = AppLockController(prefs, auth: auth);
      expect(await c.enable(), isTrue);
      expect(c.isEnabled, isTrue);
      expect(c.isLocked, isFalse);
      expect(prefs.getBool('app_lock_enabled'), isTrue);
    });

    test('locks on resume after threshold elapses', () async {
      await prefs.setBool('app_lock_enabled', true);
      final c = AppLockController(
        prefs,
        auth: auth,
        backgroundLockThreshold: const Duration(milliseconds: 50),
      );
      // Unlock first (simulate successful initial auth).
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => true);
      await c.unlock();
      expect(c.isLocked, isFalse);

      c.markBackgrounded();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      c.onResumed();
      expect(c.isLocked, isTrue);
    });

    test('does not lock on resume below threshold', () async {
      await prefs.setBool('app_lock_enabled', true);
      final c = AppLockController(
        prefs,
        auth: auth,
        backgroundLockThreshold: const Duration(seconds: 30),
      );
      when(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => true);
      await c.unlock();
      expect(c.isLocked, isFalse);

      c.markBackgrounded();
      c.onResumed();
      expect(c.isLocked, isFalse);
    });

    test('onResumed re-notifies when already locked so gate can re-prompt',
        () async {
      await prefs.setBool('app_lock_enabled', true);
      final c = AppLockController(
        prefs,
        auth: auth,
        backgroundLockThreshold: const Duration(seconds: 30),
      );
      expect(c.isLocked, isTrue);

      var notifications = 0;
      c.addListener(() => notifications++);

      // User backgrounds briefly (under threshold) while still locked.
      c.markBackgrounded();
      c.onResumed();

      expect(c.isLocked, isTrue);
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('onResumed is a no-op when lock is disabled', () async {
      final c = AppLockController(
        prefs,
        auth: auth,
        backgroundLockThreshold: Duration.zero,
      );
      c.markBackgrounded();
      c.onResumed();
      expect(c.isLocked, isFalse);
    });
  });
}
