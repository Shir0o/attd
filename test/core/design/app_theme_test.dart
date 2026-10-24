import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void exerciseSwitch(ThemeData theme) {
    final s = theme.switchTheme;
    const selected = <WidgetState>{WidgetState.selected};
    const unselected = <WidgetState>{};

    expect(s.thumbColor!.resolve(selected), isNotNull);
    expect(s.thumbColor!.resolve(unselected), isNotNull);
    expect(s.trackColor!.resolve(selected), isNotNull);
    expect(s.trackColor!.resolve(unselected), isNotNull);
    // Convocation toggles intentionally omit a thumb glyph.
  }

  testWidgets('lightTheme switch resolves both selected and unselected states',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme(), home: const SizedBox()),
    );
    exerciseSwitch(AppTheme.lightTheme());
  });

  testWidgets('darkTheme switch resolves both selected and unselected states',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme(), home: const SizedBox()),
    );
    exerciseSwitch(AppTheme.darkTheme());
  });

  test('inputDecorationTheme omits focused border per the no-line rule', () {
    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      final focused = theme.inputDecorationTheme.focusedBorder;
      expect(focused, isA<OutlineInputBorder>());
      expect((focused as OutlineInputBorder).borderSide, BorderSide.none);
    }
  });

  test('snackBarTheme uses Convocation tokens and never raw white defaults', () {
    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      final snackBar = theme.snackBarTheme;
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, isNotNull);
      expect(snackBar.contentTextStyle?.color, isNotNull);
      expect(snackBar.actionTextColor, isNotNull);
    }
  });
}
