import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads every bundled Fraunces and Geist weight before any test in the file
/// runs.
///
/// google_fonts loads a font the first time a style asks for it. In a widget
/// test that load finishes in real time, usually after the test body, and the
/// engine then sends a `fontsChange` system message. The "Test finished."
/// paragraph the binding leaves mounted reacts by scheduling a frame callback,
/// and since Flutter 3.50 the binding checks for pending transient callbacks
/// in `postTest`, so the test fails with "An animation is still running even
/// after the widget tree was disposed". With the fonts already loaded here, no
/// load is in flight during a test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The weights bundled under `flutter: fonts:` in pubspec.yaml.
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    GoogleFonts.fraunces(fontWeight: weight);
    GoogleFonts.geist(fontWeight: weight);
  }
  await GoogleFonts.pendingFonts();
  await testMain();
}
