import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/onboarding/presentation/onboarding_page.dart';
import 'package:attendance_tracker/features/onboarding/presentation/mock_components.dart';
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

    testWidgets('navigates through all slides using swipes', (tester) async {
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
    });

    testWidgets('Skip button completes onboarding', (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(controller.onboardingCompleted, isTrue);
    });

    testWidgets('Get Started button on final slide completes onboarding', (tester) async {
      await tester.pumpWidget(buildOnboardingPage());

      // Navigate to final slide (4 slides total)
      for (int i = 0; i < 3; i++) {
        await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
        await tester.pumpAndSettle();
      }

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(controller.onboardingCompleted, isTrue);
    });

    testWidgets('deck art card does not overflow under large text scale',
        (tester) async {
      // The deck cards are fixed-size decorative postcards; their inner
      // content must scale down rather than overflow at large text scales.
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
