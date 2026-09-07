import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fastlane/Fastfile', () {
    late String fastfile;
    late String appfile;

    setUpAll(() {
      final f = File('fastlane/Fastfile');
      final a = File('fastlane/Appfile');
      if (!f.existsSync()) fail('fastlane/Fastfile missing.');
      if (!a.existsSync()) fail('fastlane/Appfile missing.');
      fastfile = f.readAsStringSync();
      appfile = a.readAsStringSync();
    });

    test('uploads to the internal track (not production)', () {
      expect(fastfile, contains('track: "internal"'));
      expect(fastfile, isNot(contains('track: "production"')),
          reason: 'Production promotion must stay a manual Play Console click.');
    });

    test('package_name matches the Android applicationId', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      // applicationId is the first match; ignore case.
      final match =
          RegExp(r'applicationId\s*=\s*"([^"]+)"').firstMatch(gradle);
      expect(match, isNotNull,
          reason: 'applicationId not found in android/app/build.gradle.kts');
      final applicationId = match!.group(1)!;
      expect(fastfile, contains('"$applicationId"'));
    });

    test('reads service-account JSON from the runtime-mounted fastlane/ path', () {
      expect(
          fastfile, contains('fastlane/play-supply-credentials.json'));
      expect(appfile, contains('fastlane/play-supply-credentials.json'));
    });

    test('uploads text metadata and changelogs, skips images/screenshots', () {
      // ADR 0002: release notes are prefilled from the changelog, so text
      // metadata and changelogs are synchronized; only media is skipped.
      expect(fastfile, contains('metadata_path: "fastlane/metadata/android"'));
      expect(fastfile, contains('skip_upload_metadata: false'));
      expect(fastfile, contains('skip_upload_changelogs: false'));
      expect(fastfile, contains('skip_upload_images: true'));
      expect(fastfile, contains('skip_upload_screenshots: true'));
    });
  });

  group('fastlane/.gitignore', () {
    test('ignores the runtime-mounted service-account JSON', () {
      final f = File('fastlane/.gitignore');
      expect(f.existsSync(), isTrue);
      expect(f.readAsStringSync(),
          contains('play-supply-credentials.json'));
    });
  });
}
