import 'package:attendance_tracker/core/design/fluid_loading_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders child without painter when not loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FluidLoadingBorder(
          isLoading: false,
          child: Text('Ready'),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(_loadingOverlayFinder(), findsNothing);
  });

  testWidgets('renders animated border while loading and responds to updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FluidLoadingBorder(
          isLoading: true,
          borderWidth: 4,
          borderRadius: 12,
          gradientColors: [
            Colors.transparent,
            Colors.red,
            Colors.green,
            Colors.blue,
            Colors.transparent,
          ],
          child: SizedBox(width: 80, height: 40, child: Text('Loading')),
        ),
      ),
    );

    expect(find.text('Loading'), findsOneWidget);
    expect(_loadingOverlayFinder(), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      const MaterialApp(
        home: FluidLoadingBorder(
          isLoading: false,
          child: SizedBox(width: 80, height: 40, child: Text('Stopped')),
        ),
      ),
    );

    expect(find.text('Stopped'), findsOneWidget);
    expect(_loadingOverlayFinder(), findsNothing);
  });
}

Finder _loadingOverlayFinder() {
  return find.descendant(
    of: find.byType(FluidLoadingBorder),
    matching: find.byType(IgnorePointer),
  );
}
