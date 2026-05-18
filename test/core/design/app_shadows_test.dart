import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_shadows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ambient shadow uses a single tinted shadow', () {
    final shadows = AppShadows.ambient;

    expect(shadows, hasLength(1));
    expect(shadows.single.color, AppColors.primaryDim.withOpacity(0.04));
    expect(shadows.single.blurRadius, 32);
    expect(shadows.single.spreadRadius, 0);
  });

  test('elevated shadow uses two depth layers', () {
    final shadows = AppShadows.elevated;

    expect(shadows, hasLength(2));
    expect(shadows.first.color, AppColors.primaryDim.withOpacity(0.08));
    expect(shadows.first.blurRadius, 16);
    expect(shadows.last.color, AppColors.primaryDim.withOpacity(0.04));
    expect(shadows.last.blurRadius, 6);
  });

  test('ghost border uses outline variant tint', () {
    final border = AppShadows.ghostBorder;

    expect(border.color, AppColors.outlineVariant.withOpacity(0.2));
    expect(border.width, 2);
  });
}
