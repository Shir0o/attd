import 'package:flutter/material.dart';

/// Centralized color tokens for "The Fluid Humanist" design system.
///
/// All hex values are from the design spec. The palette is rooted in a
/// sophisticated violet and soft lily-white base.
class AppColors {
  AppColors._();

  // ── Primary ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6750A5);
  static const Color onPrimary = Color(0xFFFDF7FF);
  static const Color primaryContainer = Color(0xFFCAB6FF);
  static const Color primaryDim = Color(0xFF5B4497);
  static const Color primaryFixed = Color(0xFFCAB6FF);

  // ── Secondary ────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF4D6645);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Tertiary ─────────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF376B21);
  static const Color onTertiary = Color(0xFFFFFFFF);

  // ── Error ────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // ── Surface hierarchy ("No-Line" tonal layering) ─────────────────────
  /// Level 0 – Base background
  static const Color background = Color(0xFFFEF7FF);

  /// Level 1 – Sections
  static const Color surfaceContainerLow = Color(0xFFF9F1FB);

  /// Level 2 – Active cards
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  /// General surface
  static const Color surface = Color(0xFFFEF7FF);

  /// Surface container (mid-tier)
  static const Color surfaceContainer = Color(0xFFF3EDF7);

  /// Surface container high
  static const Color surfaceContainerHigh = Color(0xFFEDE5F2);

  /// Surface container highest
  static const Color surfaceContainerHighest = Color(0xFFE8DFED);

  // ── On‑surface ──────────────────────────────────────────────────────
  /// Primary text – never pure black
  static const Color onSurface = Color(0xFF35313B);

  /// Secondary text / labels
  static const Color onSurfaceVariant = Color(0xFF625D68);

  // ── Outline ──────────────────────────────────────────────────────────
  static const Color outlineVariant = Color(0xFFB7AFBC);

  // ── Surface tint (used for hover overlays) ───────────────────────────
  static const Color surfaceTint = Color(0xFF6750A5);

  /// The seed color for [ColorScheme.fromSeed] – used for any roles not
  /// explicitly overridden above.
  static const Color seed = Color(0xFF6750A5);

  // ────────────────────────────────────────────────────────────────────
  // Light ColorScheme
  // ────────────────────────────────────────────────────────────────────
  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    tertiary: tertiary,
    onTertiary: onTertiary,
    error: error,
    onError: onError,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    outlineVariant: outlineVariant,
    surfaceTint: surfaceTint,
  );

  // ────────────────────────────────────────────────────────────────────
  // Dark ColorScheme – adapted tonal palette from same seed
  // ────────────────────────────────────────────────────────────────────
  static ColorScheme get darkColorScheme => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
}
