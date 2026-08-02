import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_radii.dart';
import 'package:attendance_tracker/core/design/app_shadows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppRadii, AppShadows, and AppColors tokens access correctly', () {
    expect(AppRadii.card, 24);
    expect(AppRadii.cardR, const BorderRadius.all(Radius.circular(24)));
    expect(AppRadii.softR, const BorderRadius.all(Radius.circular(22)));
    expect(AppRadii.sheetR, const BorderRadius.vertical(top: Radius.circular(28)));
    expect(AppRadii.tileR, const BorderRadius.all(Radius.circular(18)));
    expect(AppRadii.compactR, const BorderRadius.all(Radius.circular(14)));
    expect(AppRadii.fabR, const BorderRadius.all(Radius.circular(22)));

    expect(AppShadows.card.length, 2);
    expect(AppShadows.soft.length, 2);
    expect(AppShadows.fab(Colors.purple).length, 1);
    expect(AppShadows.ambient, AppShadows.card);
    expect(AppShadows.elevated, AppShadows.soft);
    expect(AppShadows.ghostBorder.width, 2);

    expect(AppColors.lightColorScheme.brightness, Brightness.light);
    expect(AppColors.darkColorScheme.brightness, Brightness.dark);
  });

  test('ConvocationColors copyWith and lerp operate correctly', () {
    const light = ConvocationColors.light;
    const dark = ConvocationColors.dark;

    final custom = light.copyWith(
      bg: Colors.red,
      present: Colors.green,
    );

    expect(custom.bg, Colors.red);
    expect(custom.present, Colors.green);
    expect(custom.absent, light.absent);

    final lerpedHalf = light.lerp(dark, 0.5);
    expect(lerpedHalf.bg, Color.lerp(light.bg, dark.bg, 0.5));
    expect(lerpedHalf.present, Color.lerp(light.present, dark.present, 0.5));

    final lerpedNull = light.lerp(null, 0.5);
    expect(lerpedNull, light);
  });
}
