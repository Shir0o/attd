import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_shadows.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('card shadow uses two violet-tinted depth layers', () {
    final shadows = AppShadows.card;

    expect(shadows, hasLength(2));
    expect(shadows.first.blurRadius, 2);
    expect(shadows.last.blurRadius, 24);
  });

  test('soft shadow uses two violet-tinted depth layers', () {
    final shadows = AppShadows.soft;

    expect(shadows, hasLength(2));
    expect(shadows.first.blurRadius, 2);
    expect(shadows.last.blurRadius, 18);
  });

  test('fab glow is tinted by the supplied primary color', () {
    final shadows = AppShadows.fab(const Color(0xFFAABBCC));

    expect(shadows, hasLength(1));
    expect(shadows.single.blurRadius, 30);
  });

  test('ghost border uses outline variant tint', () {
    final border = AppShadows.ghostBorder;

    expect(border.color, AppColors.outlineVariant.withValues(alpha: 0.2));
    expect(border.width, 2);
  });
}
