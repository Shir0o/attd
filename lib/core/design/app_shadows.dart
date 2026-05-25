import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shadow presets for Convocation.
///
/// Most surfaces sit flat (tonal layering). The editorial hub card,
/// onboarding cards, and the FAB use soft violet-tinted shadows derived
/// from `--shadow-card` and the FAB glow in app.css.
class AppShadows {
  AppShadows._();

  /// Soft card shadow used by the "Up next" hub card and onboarding cards.
  /// Mirrors `--shadow-card` in app.css.
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.violetDeep.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.violetDeep.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -10,
    ),
  ];

  /// Soft elevation for editorial elements (slightly stronger than card).
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.violetDeep.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.violetDeep.withValues(alpha: 0.18),
      blurRadius: 18,
      offset: const Offset(0, 4),
      spreadRadius: -8,
    ),
  ];

  /// FAB glow — primary-tinted bottom shadow.
  static List<BoxShadow> fab(Color primary) => [
    BoxShadow(
      color: primary.withValues(alpha: 0.5),
      blurRadius: 30,
      offset: const Offset(0, 10),
      spreadRadius: -8,
    ),
  ];

  /// Backwards-compatible aliases (some older screens import these).
  static List<BoxShadow> get ambient => card;
  static List<BoxShadow> get elevated => soft;

  /// Faint border kept for input-focus fallbacks.
  static BorderSide get ghostBorder => BorderSide(
    color: AppColors.outlineVariant.withValues(alpha: 0.2),
    width: 2,
  );
}
