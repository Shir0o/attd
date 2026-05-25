import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConvocationColors', () {
    test('light and dark presets expose every role', () {
      const light = ConvocationColors.light;
      const dark = ConvocationColors.dark;

      expect(light.bg, isNot(dark.bg));
      expect(light.ink, isNot(dark.ink));
      expect(light.present, AppColors.primary);
      expect(light.absent, AppColors.coral);
    });

    test('copyWith overrides only the supplied roles', () {
      final override = ConvocationColors.light.copyWith(
        bg: const Color(0xFFAABBCC),
        ink: const Color(0xFF112233),
      );

      expect(override.bg, const Color(0xFFAABBCC));
      expect(override.ink, const Color(0xFF112233));
      expect(override.present, ConvocationColors.light.present);
      expect(override.cardSoft, ConvocationColors.light.cardSoft);
    });

    test('lerp interpolates between two ConvocationColors', () {
      final mid = ConvocationColors.light.lerp(ConvocationColors.dark, 0.5);
      expect(mid, isA<ConvocationColors>());
      expect(mid.bg, isNot(ConvocationColors.light.bg));
      expect(mid.bg, isNot(ConvocationColors.dark.bg));
    });

    test('lerp falls back to self when other is null', () {
      final result = ConvocationColors.light.lerp(null, 0.5);
      expect(result, same(ConvocationColors.light));
    });
  });
}
