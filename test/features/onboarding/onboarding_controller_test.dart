import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('OnboardingController', () {
    test('initializes with onboardingCompleted = false when no value in prefs', () {
      final controller = OnboardingController(prefs);
      expect(controller.onboardingCompleted, isFalse);
      expect(controller.shouldShowOnboarding, isTrue);
      expect(controller.coordinatorAgeAffirmed, isFalse);
    });

    test('initializes with values from prefs when set', () async {
      await prefs.setBool('onboarding_completed', true);
      await prefs.setBool('coordinator_age_affirmed', true);
      final controller = OnboardingController(prefs);
      expect(controller.onboardingCompleted, isTrue);
      expect(controller.shouldShowOnboarding, isFalse);
      expect(controller.coordinatorAgeAffirmed, isTrue);
    });

    test('setCoordinatorAgeAffirmed updates status, notifies listeners, and persists', () async {
      final controller = OnboardingController(prefs);
      var listenerCalled = false;
      controller.addListener(() {
        listenerCalled = true;
      });

      await controller.setCoordinatorAgeAffirmed(true);

      expect(controller.coordinatorAgeAffirmed, isTrue);
      expect(listenerCalled, isTrue);
      expect(prefs.getBool('coordinator_age_affirmed'), isTrue);

      listenerCalled = false;
      await controller.setCoordinatorAgeAffirmed(false);

      expect(controller.coordinatorAgeAffirmed, isFalse);
      expect(listenerCalled, isTrue);
      expect(prefs.getBool('coordinator_age_affirmed'), isFalse);
    });

    test('completeOnboarding does not complete if coordinatorAgeAffirmed is false', () async {
      final controller = OnboardingController(prefs);
      var listenerCalled = false;
      controller.addListener(() {
        listenerCalled = true;
      });

      await controller.completeOnboarding();

      expect(controller.onboardingCompleted, isFalse);
      expect(controller.shouldShowOnboarding, isTrue);
      expect(listenerCalled, isFalse);
      expect(prefs.getBool('onboarding_completed'), isNull);
    });

    test('completeOnboarding updates status and notifies listeners when affirmed', () async {
      final controller = OnboardingController(prefs);
      await controller.setCoordinatorAgeAffirmed(true);

      var listenerCalled = false;
      controller.addListener(() {
        listenerCalled = true;
      });

      await controller.completeOnboarding();

      expect(controller.onboardingCompleted, isTrue);
      expect(controller.shouldShowOnboarding, isFalse);
      expect(listenerCalled, isTrue);
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });
  });
}
