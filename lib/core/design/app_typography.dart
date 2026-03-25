import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for "The Fluid Humanist" design system.
///
/// Uses IBM Plex Sans (via google_fonts) with an editorial scale that
/// balances technical precision with human warmth.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(TextTheme baseTheme) {
    final base = GoogleFonts.ibmPlexSansTextTheme(baseTheme);
    return base.copyWith(
      // ── Display ────────────────────────────────────────────────────
      // 3.5rem (56px) – high-impact onboarding welcomes
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.12, // −2% of 56
        height: 1.1,
      ),
      // 2.75rem (44px)
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.88, // −2% of 44
        height: 1.15,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.72, // −2% of 36
        height: 1.2,
      ),

      // ── Headline ───────────────────────────────────────────────────
      // 1.75rem (28px) – direct questions
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      // 1.5rem (24px)
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),

      // ── Title ──────────────────────────────────────────────────────
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.4,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      ),

      // ── Body ───────────────────────────────────────────────────────
      // 1rem (16px) – generous line-height for "Soft Humanist" aesthetic
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      // 0.875rem (14px)
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),

      // ── Label ──────────────────────────────────────────────────────
      // 0.75rem (12px) – secondary but legible
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
