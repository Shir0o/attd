import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Signature gradient presets for "The Fluid Humanist" design system.
class AppGradients {
  AppGradients._();

  /// Primary CTA / Hero gradient – 135° from primary to primaryContainer.
  /// Adds "soul" and professional luster per the spec.
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight, // ≈ 135°
    colors: [AppColors.primary, AppColors.primaryContainer],
  );
}
