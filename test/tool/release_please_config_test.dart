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

    test('uses the dart release-type (the only one that handles pubspec.yaml)',
        () {
      expect(config['releaseType'], 'dart');
    });

    test('does NOT pin packageName to attendance_tracker (dart release-type uses "." in the manifest)',
        () {
      // The old `pubspec` release-type used `packageName`. The `dart`
      // release-type uses `.` as the package key in the manifest.
      expect(config.containsKey('packageName'), isFalse,
          reason:
              '`packageName` is a `pubspec`-release-type field. The '
              '`dart` release-type uses the manifest\'s `.` key instead.');
    });

    test('targets main as the release branch', () {
      expect(config['branch'], 'main');
    });

    test('changelog-path points at CHANGELOG.md', () {
      expect(config['changelogPath'], 'CHANGELOG.md');
    });

    test('version is bumped on the tag (no separate component suffix)', () {
      expect(config['includeComponentInTag'], isFalse);
    });

    test('excludes release.md so the deleted legacy file cannot resurface',
        () {
      final extraFiles = config['extra-files'] as List<dynamic>?;
      expect(extraFiles, isNotNull);
      expect(
        extraFiles!.any((entry) =>
            (entry as Map<String, dynamic>)['path'] == 'release.md'),
        isFalse,
        reason: 'release.md was deleted; release-please must not try to write it.',
      );
    });

    test('changelogSections lists every conventional type the lint workflow allows',
        () {
      final sections = (config['changelogSections'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final releasePleaseTypes = sections.map((s) => s['type'] as String).toSet();
      // All conventional types we expect; release-please also accepts
      // `revert` even when no changelogSection is declared for it.
      expect(releasePleaseTypes.containsAll([
        'feat',
        'fix',
        'perf',
        'refactor',
      ]), isTrue);
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

    test('uses the "." package key for a single-package Flutter repo', () {
      expect(manifest.containsKey('.'), isTrue);
    });

    test('current version is a bare semver (no +versionCode suffix)', () {
      final version = manifest['.'] as String;
      expect(version, '1.3.2');
      // The +N suffix breaks release-please's pubspec parsing; flag any
      // re-introduction immediately.
      expect(version, isNot(contains('+')));
    });
  });
}