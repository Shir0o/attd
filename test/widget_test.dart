import 'package:attendance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Shows attendance overview and actions', (tester) async {
    await tester.pumpWidget(const AttendanceApp());

    expect(find.text("Today's overview"), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
  });
}
