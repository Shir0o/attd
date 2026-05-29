import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for the **Convocation** design system.
///
/// Pairs Fraunces (serif, editorial) for display + headline with Geist
/// (sans, technical) for body, label, and numeric runs. Mirrors the
/// `.t-display / .t-headline / .t-eyebrow / .t-body / .t-label / .t-num`
/// scale documented in `DESIGN_SPEC.md`.
class AppTypography {
  AppTypography._();

  static TextStyle fraunces({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) => GoogleFonts.fraunces(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle geist({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) => GoogleFonts.geist(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  /// Tabular Geist for numeric runs that aren't the editorial display number.
  static TextStyle geistTabular({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.geist(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme(TextTheme baseTheme) {
    final body = GoogleFonts.geistTextTheme(baseTheme);
    return body.copyWith(
      // ── Display (Fraunces) ────────────────────────────────────────
      displayLarge: fraunces(
        fontSize: 56,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.68,
        height: 1.0,
      ),
      displayMedium: fraunces(
        fontSize: 44,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.32,
        height: 1.05,
      ),
      displaySmall: fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.08,
        height: 1.1,
      ),

      // ── Headline (Fraunces) ───────────────────────────────────────
      headlineLarge: fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.64,
        height: 1.1,
      ),
      headlineMedium: fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.52,
        height: 1.12,
      ),
      headlineSmall: fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.44,
        height: 1.15,
      ),

      // ── Title (Geist) ─────────────────────────────────────────────
      titleLarge: geist(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: geist(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      titleSmall: geist(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),

      // ── Body (Geist) ──────────────────────────────────────────────
      bodyLarge: geist(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: geist(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: geist(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),

      // ── Label (Geist) ─────────────────────────────────────────────
      labelLarge: geist(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: geist(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: geist(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.54, // 0.14em on 11px
      ),
    );
  }

  // ── Convocation-specific helpers ──────────────────────────────────────
  /// Editorial display numeral — Fraunces, tabular, tight tracking.
  static TextStyle displayNumber({required double fontSize, Color? color}) =>
      fraunces(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: -fontSize * 0.04,
        height: 0.95,
        color: color,
      );

  /// All-caps eyebrow used pervasively in the design (`.t-eyebrow`).
  static TextStyle eyebrow({Color? color, double fontSize = 11}) => geist(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    letterSpacing: fontSize * 0.14,
    color: color,
  );
}
