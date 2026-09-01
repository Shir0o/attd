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

    /// Resolves a key from either the v3 top-level config or the v4
    /// nested `packages: { ".": { ... } }` config. Returns null if
    /// neither path has the key.
    dynamic getValue(String key) {
      final top = config[key];
      if (top != null) return top;
      final packages = config['packages'] as Map<String, dynamic>?;
      if (packages == null) return null;
      final root = packages['.'] as Map<String, dynamic>?;
      if (root == null) return null;
      return root[key];
    }

    test('uses the dart release-type (the only one that handles pubspec.yaml)',
        () {
      expect(getValue('release-type'), 'dart');
    });

    test('targets main as the release branch (or omits the key, defaulting to main)',
        () {
      // release-please v4 defaults the branch to the default git branch,
      // which is `main` for this repo. An explicit value is fine too.
      final branch = getValue('branch');
      expect(branch == null || branch == 'main', isTrue,
          reason: 'Unexpected branch: $branch');
    });

    test('changelog-path points at CHANGELOG.md', () {
      expect(getValue('changelog-path'), 'CHANGELOG.md');
    });

    test('include-component-in-tag is false (tags are vX.Y.Z)', () {
      expect(getValue('include-component-in-tag'), isFalse);
    });

    test('extra-files points at pubspec.yaml so release-please updates it',
        () {
      final extraFiles = getValue('extra-files') as List<dynamic>?;
      expect(extraFiles, isNotNull);
      expect(
        extraFiles!.any((entry) =>
            (entry as Map<String, dynamic>)['path'] == 'pubspec.yaml'),
        isTrue,
        reason: 'release-please needs an extra-files entry pointing at '
            'pubspec.yaml so the version field gets updated.',
      );
    });

    test('extra-files excludes release.md so the deleted legacy file cannot resurface',
        () {
      final extraFiles = getValue('extra-files') as List<dynamic>?;
      expect(extraFiles, isNotNull);
      expect(
        extraFiles!.any((entry) =>
            (entry as Map<String, dynamic>)['path'] == 'release.md'),
        isFalse,
        reason: 'release.md was deleted; release-please must not try to write it.',
      );
    });

    test('changelog-sections lists every conventional type the lint workflow allows',
        () {
      final sections = (getValue('changelog-sections') as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final releasePleaseTypes =
          sections.map((s) => s['type'] as String).toSet();
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
      // The manifest version drifts with each release-please PR; this
      // test pins the no-+versionCode invariant, not the specific value.
      final version = manifest['.'] as String;
      expect(version, isNot(contains('+')),
          reason:
              'The +N build-code suffix breaks release-please\'s pubspec '
              'parsing. Flag any re-introduction immediately.');
      // Sanity-check the shape, not the value.
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')),
          reason: 'Manifest version must be bare semver X.Y.Z, was: $version');
    });
  });
}