import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';
import 'app_typography.dart';
import '../presentation/no_transitions_builder.dart';

/// Composes [ThemeData] from the "Fluid Humanist" design tokens.
///
/// Call [lightTheme] / [darkTheme] from your [MaterialApp].
class AppTheme {
  AppTheme._();

  // ── Corner radii ──────────────────────────────────────────────────
  /// Standard container radius ("rounded-md" ≈ 1.5rem / 24px)
  static const double radiusMd = 24;

  /// Bottom‑sheet / modal top radius
  static const double radiusSheet = 28;

  /// Pill / fully rounded
  static const ShapeBorder pillShape = StadiumBorder();

  // ── Light theme ───────────────────────────────────────────────────
  static ThemeData lightTheme() {
    final colorScheme = AppColors.lightColorScheme;
    final textTheme = AppTypography.textTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // ── Page transitions (instant) ────────────────────────────────
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (var platform in TargetPlatform.values)
            platform: const NoTransitionsBuilder(),
        },
      ),

      // ── App Bar ───────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Cards (tonal layering, no shadow) ─────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Filled button (primary gradient pill) ─────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Elevated button ───────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurface,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Text button ───────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: const StadiumBorder(),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          shape: const StadiumBorder(),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 0,
      ),

      // ── Input fields (filled, no border) ──────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: AppShadows.ghostBorder,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ── Bottom sheet ──────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // ── Divider (invisible – spec forbids divider lines) ──────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.1),
        thickness: 0,
        space: 0,
      ),

      // ── List tile ─────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // ── Snack bar ─────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────
  static ThemeData darkTheme() {
    final colorScheme = AppColors.darkColorScheme;
    final textTheme = AppTypography.textTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (var platform in TargetPlatform.values)
            platform: const NoTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurface,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          shape: const StadiumBorder(),
          side: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: AppShadows.ghostBorder,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.1),
        thickness: 0,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }
}
