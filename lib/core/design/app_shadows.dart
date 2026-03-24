import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tinted shadow presets for "The Fluid Humanist" design system.
///
/// We eschew grey shadows in favour of tinted `primaryDim` shadows
/// that simulate natural light passing through a violet lens.
class AppShadows {
  AppShadows._();

  /// Ambient shadow for floating action buttons and elevated elements.
  /// Large blur (32px) at 4% opacity with tinted primaryDim.
  static List<BoxShadow> get ambient => [
    BoxShadow(
      color: AppColors.primaryDim.withOpacity(0.04),
      blurRadius: 32,
      spreadRadius: 0,
      offset: Offset.zero,
    ),
  ];

  /// Elevated shadow for cards that need subtle lift.
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.primaryDim.withOpacity(0.08),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primaryDim.withOpacity(0.04),
      blurRadius: 6,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  /// Ghost border for input field focus states.
  /// Uses outlineVariant at 20% opacity.
  static BorderSide get ghostBorder => BorderSide(
    color: AppColors.outlineVariant.withOpacity(0.2),
    width: 2,
  );
}
