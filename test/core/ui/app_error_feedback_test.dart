import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/ui/app_error_feedback.dart';

void main() {
  group('AppErrorFeedback', () {
    testWidgets('showSnackBar displays pill snackbar with message and retry action', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppErrorFeedback.showSnackBar(
                    context,
                    message: 'Drive sync failed due to network.',
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Trigger SnackBar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger SnackBar'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 750)); // Complete animation

      expect(find.text('Drive sync failed due to network.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('showDialog displays recovery dialog with title, message, and actions', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppErrorFeedback.showDialog(
                    context,
                    title: 'Restore Failed',
                    message: 'The selected backup file is corrupted.',
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Trigger Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Restore Failed'), findsOneWidget);
      expect(find.text('The selected backup file is corrupted.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retried, isTrue);
      expect(find.text('Restore Failed'), findsNothing);
    });

    testWidgets('AppErrorView renders inline error state with retry button', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              message: 'Failed to load attendees.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to load attendees.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('ErrorBoundary renders fallback AppErrorView on child build error', (tester) async {
      final widget = MaterialApp(
        home: Scaffold(
          body: ErrorBoundary(
            builder: (context) {
              throw Exception('Unexpected render explosion');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}
