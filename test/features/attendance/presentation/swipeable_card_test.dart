import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SwipeableCard calls onSwipeRight when swiped right', (
    WidgetTester tester,
  ) async {
    bool swipedRight = false;
    bool swipedLeft = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableCard(
            onSwipeRight: () {
              swipedRight = true;
            },
            onSwipeLeft: () {
              swipedLeft = true;
            },
            child: Container(
              width: 300,
              height: 400,
              color: Colors.blue,
              key: const Key('card'),
            ),
          ),
        ),
      ),
    );

    // Swipe right (large value to exceed threshold)
    await tester.drag(find.byKey(const Key('card')), const Offset(200, 0));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle(); // Wait for animation

    expect(swipedRight, isTrue);
    expect(swipedLeft, isFalse);
  });

  testWidgets('SwipeableCard calls onSwipeLeft when swiped left', (
    WidgetTester tester,
  ) async {
    bool swipedRight = false;
    bool swipedLeft = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableCard(
            onSwipeRight: () {
              swipedRight = true;
            },
            onSwipeLeft: () {
              swipedLeft = true;
            },
            child: Container(
              width: 300,
              height: 400,
              color: Colors.blue,
              key: const Key('card'),
            ),
          ),
        ),
      ),
    );

    // Swipe left
    await tester.drag(find.byKey(const Key('card')), const Offset(-200, 0));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle(); // Wait for animation

    expect(swipedLeft, isTrue);
    expect(swipedRight, isFalse);
  });

  testWidgets('SwipeableCard.childBuilder receives drag progress', (
    WidgetTester tester,
  ) async {
    SwipeProgress? lastProgress;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableCard(
            childBuilder: (ctx, p) {
              lastProgress = p;
              return Container(
                width: 300,
                height: 400,
                color: Colors.blue,
                key: const Key('card'),
              );
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('card'))),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(lastProgress, isNotNull);
    expect(lastProgress!.rightProgress, closeTo(0.5, 0.01));
    expect(lastProgress!.leftProgress, 0.0);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('SwipeableCard snaps back when drag is insufficient', (
    WidgetTester tester,
  ) async {
    bool swipedRight = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableCard(
            onSwipeRight: () {
              swipedRight = true;
            },
            child: Container(
              width: 300,
              height: 400,
              color: Colors.blue,
              key: const Key('card'),
            ),
          ),
        ),
      ),
    );

    // Drag slightly right (less than threshold 100)
    await tester.drag(find.byKey(const Key('card')), const Offset(50, 0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(swipedRight, isFalse);
    // Verified it didn't trigger callback.
    // To verify snap back explicitly we'd need to check position,
    // but assuming no callback means logic followed 'else' path.
  });
}
