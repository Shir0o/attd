import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release-please-config.json', () {
    late File configFile;
    late Map<String, dynamic> config;

    setUpAll(() {
      configFile = File('release-please-config.json');
      if (!configFile.existsSync()) {
        fail(
          'release-please-config.json is missing at repo root. '
          'See RELEASING.md for the expected schema.',
        );
      }
      config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('declares the attendance_tracker package', () {
      expect(config['packageName'], 'attendance_tracker');
    });

    test('uses the pubspec release type so versionCode bumps with versionName',
        () {
      expect(config['releaseType'], 'pubspec');
    });

    test('bumps version (not just versionCode) on each release', () {
      final includeComponentInTag = config['includeComponentInTag'];
      expect(includeComponentInTag, isFalse);
    });

    test('targets main as the release branch', () {
      expect(config['branch'], 'main');
    });

    test('changelog-path points at CHANGELOG.md (not the deleted release.md)',
        () {
      expect(config['changelogPath'], 'CHANGELOG.md');
    });

    test('extra-files excludes release.md so legacy content does not resurface',
        () {
      final extraFiles = config['extraFiles'] as List<dynamic>?;
      expect(extraFiles, isNotNull);
      expect(
        extraFiles!.any((entry) => (entry as Map<String, dynamic>)['path'] == 'release.md'),
        isFalse,
        reason: 'release.md was deleted; release-please must not try to write it.',
      );
    });
  });

  group('.release-please-manifest.json', () {
    late File manifestFile;
    late Map<String, dynamic> manifest;

    setUpAll(() {
      manifestFile = File('.release-please-manifest.json');
      if (!manifestFile.existsSync()) {
        fail('.release-please-manifest.json is missing at repo root.');
      }
      manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('pins the attendance_tracker package to its current pubspec version',
        () {
      final pkg = manifest['packages']?['attendance_tracker'];
      expect(pkg, isNotNull);
      expect(pkg, '1.3.2+24');
    });
  });
}
