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
    });

    test('initializes with onboardingCompleted = true when value in prefs is true', () async {
      await prefs.setBool('onboarding_completed', true);
      final controller = OnboardingController(prefs);
      expect(controller.onboardingCompleted, isTrue);
      expect(controller.shouldShowOnboarding, isFalse);
    });

    test('completeOnboarding updates status and notifies listeners', () async {
      final controller = OnboardingController(prefs);
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
