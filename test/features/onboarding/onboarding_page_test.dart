import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/onboarding/presentation/mock_components.dart';
import 'package:attendance_tracker/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late OnboardingController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    controller = OnboardingController(prefs);
  });

  Widget buildOnboardingPage() {
    return MaterialApp(
      home: OnboardingPage(onboardingController: controller),
    );
  }

  group('OnboardingPage', () {
    testWidgets('renders first slide initially', (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      expect(find.text('Swipe with one thumb.'), findsOneWidget);
      expect(find.byType(OnboardingDeckArt), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('navigates through all slides using swipes and shows coordinator age affirmation',
        (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      // Slide 1 -> Slide 2
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Every Sunday, remembered.'), findsOneWidget);
      expect(find.byType(OnboardingHistoryArt), findsOneWidget);

      // Slide 2 -> Slide 3
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Roll up by family.'), findsOneWidget);
      expect(find.byType(OnboardingFamilyArt), findsOneWidget);

      // Slide 3 -> Slide 4 (final)
      await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Local-first. Always yours.'), findsOneWidget);
      expect(find.byType(OnboardingCloudArt), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      // Verify Coordinator Age Affirmation declaration and checkbox
      expect(
        find.text(
          'I confirm that I am at least 13 years old or an authorized adult coordinator.',
        ),
        findsOneWidget,
      );
      final checkboxFinder = find.byKey(
        const ValueKey('coordinator_age_affirmation_checkbox'),
      );
      expect(checkboxFinder, findsOneWidget);

      final checkbox = tester.widget<Checkbox>(checkboxFinder);
      expect(checkbox.value, isFalse);

      final getStartedButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Get Started'),
      );
      expect(getStartedButton.onPressed, isNull);
    });

    testWidgets('Skip button navigates to final affirmation slide instead of bypassing onboarding',
        (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Should land on final slide with affirmation
      expect(find.text('Local-first. Always yours.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(controller.onboardingCompleted, isFalse);
    });

    testWidgets('Get Started completes onboarding only after affirming coordinator age',
        (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      // Navigate to final slide
      for (int i = 0; i < 3; i++) {
        await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
        await tester.pumpAndSettle();
      }

      expect(find.text('Get Started'), findsOneWidget);
      expect(controller.onboardingCompleted, isFalse);

      // Tap affirmation checkbox
      final checkboxFinder = find.byKey(
        const ValueKey('coordinator_age_affirmation_checkbox'),
      );
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(controller.coordinatorAgeAffirmed, isTrue);

      final getStartedButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Get Started'),
      );
      expect(getStartedButton.onPressed, isNotNull);

      // Now tap Get Started
      await tester.tap(find.widgetWithText(TextButton, 'Get Started'));
      await tester.pumpAndSettle();

      expect(controller.onboardingCompleted, isTrue);
    });

    testWidgets('unchecking affirmation disables completion again', (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final checkboxFinder = find.byKey(
        const ValueKey('coordinator_age_affirmation_checkbox'),
      );

      // Check it
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(controller.coordinatorAgeAffirmed, isTrue);

      // Uncheck it
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect(controller.coordinatorAgeAffirmed, isFalse);

      final getStartedButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Get Started'),
      );
      expect(getStartedButton.onPressed, isNull);
    });

    testWidgets('deck art card does not overflow under large text scale',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2.0)),
                child: const Center(child: OnboardingDeckArt()),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OnboardingDeckArt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
