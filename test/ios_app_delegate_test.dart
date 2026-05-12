import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard against the white-screen-on-launch regression.
///
/// `main.dart` awaits `Firebase.initializeApp()` and `SharedPreferences`
/// before `runApp()`. Those platform-channel calls require
/// `GeneratedPluginRegistrant.register(...)` to have run synchronously in
/// `didFinishLaunchingWithOptions` — otherwise the awaits throw
/// `MissingPluginException` at top level, `runApp()` is never reached, and
/// the app shows a white screen on iOS launch.
///
/// A runtime integration test can't catch this: integration tests construct
/// `AttendanceApp` directly and never exercise the native AppDelegate path.
void main() {
  test('iOS AppDelegate registers plugins in didFinishLaunchingWithOptions',
      () {
    final file = File('ios/Runner/AppDelegate.swift');
    expect(file.existsSync(), isTrue,
        reason: 'ios/Runner/AppDelegate.swift must exist');

    final source = file.readAsStringSync();

    // The launch method must register plugins synchronously.
    final launchMethod = RegExp(
      r'didFinishLaunchingWithOptions[\s\S]*?\{([\s\S]*?)\n  \}',
    ).firstMatch(source);
    expect(launchMethod, isNotNull,
        reason: 'Could not find didFinishLaunchingWithOptions in AppDelegate');

    final body = launchMethod!.group(1)!;
    expect(
      body.contains('GeneratedPluginRegistrant.register(with: self)'),
      isTrue,
      reason:
          'AppDelegate.didFinishLaunchingWithOptions must call '
          'GeneratedPluginRegistrant.register(with: self) so platform '
          'channels are available before main.dart awaits Firebase / '
          'SharedPreferences. See PR #54.',
    );

    // The implicit-engine deferred-registration pattern broke launch; ban it.
    expect(
      source.contains('FlutterImplicitEngineDelegate'),
      isFalse,
      reason:
          'FlutterImplicitEngineDelegate defers plugin registration past '
          'main.dart\'s startup awaits, causing MissingPluginException and '
          'a white screen on launch. Register plugins in '
          'didFinishLaunchingWithOptions instead.',
    );
  });
}
