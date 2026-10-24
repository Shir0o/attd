import 'dart:io';

import 'package:attendance_tracker/core/design/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Offline font bundling and zero CDN fetching', () {
    test('pubspec.yaml bundles Fraunces and Geist font assets and font families', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue, reason: 'pubspec.yaml should exist');

      final yamlContent = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
      final flutterSection = yamlContent['flutter'] as YamlMap?;
      expect(flutterSection, isNotNull, reason: 'flutter section must exist in pubspec.yaml');

      // Verify assets include assets/fonts/
      final assets = (flutterSection!['assets'] as YamlList?)?.map((e) => e.toString()).toList();
      expect(assets, isNotNull);
      expect(assets, contains('assets/fonts/'));

      // Verify fonts section declares Fraunces and Geist with weights 400, 500, 600, 700
      final fonts = (flutterSection['fonts'] as YamlList?);
      expect(fonts, isNotNull, reason: 'flutter.fonts must be configured');

      final fontFamilies = <String, List<int>>{};
      for (final fontEntry in fonts!) {
        final family = fontEntry['family'] as String;
        final fontList = fontEntry['fonts'] as YamlList;
        final weights = <int>[];
        for (final item in fontList) {
          final asset = item['asset'] as String;
          expect(File(asset).existsSync(), isTrue, reason: 'Font asset $asset must exist on disk');
          final weight = item['weight'] as int? ?? 400;
          weights.add(weight);
        }
        fontFamilies[family] = weights;
      }

      expect(fontFamilies.containsKey('Fraunces'), isTrue, reason: 'Fraunces must be registered');
      expect(fontFamilies['Fraunces'], containsAll([400, 500, 600, 700]));

      expect(fontFamilies.containsKey('Geist'), isTrue, reason: 'Geist must be registered');
      expect(fontFamilies['Geist'], containsAll([400, 500, 600, 700]));
    });

    testWidgets('AppTypography styles render with allowRuntimeFetching disabled without errors',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Display Number', style: AppTypography.displayNumber(fontSize: 48)),
                Text('Headline', style: AppTypography.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
                Text('Eyebrow', style: AppTypography.eyebrow()),
                Text('Geist Body', style: AppTypography.geist(fontSize: 16)),
                Text('Geist Tabular', style: AppTypography.geistTabular(fontSize: 14)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Display Number'), findsOneWidget);
      expect(find.text('Headline'), findsOneWidget);
      expect(find.text('Eyebrow'), findsOneWidget);
      expect(find.text('Geist Body'), findsOneWidget);
      expect(find.text('Geist Tabular'), findsOneWidget);
    });
  });
}
