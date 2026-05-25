import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';
import '../presentation/no_transitions_builder.dart';

/// Composes [ThemeData] for the Convocation design system.
class AppTheme {
  AppTheme._();

  /// Backwards-compatible alias used by older screens that still reference
  /// `AppTheme.radiusMd`.
  static const double radiusMd = AppRadii.card;

  /// Bottom-sheet top radius.
  static const double radiusSheet = AppRadii.sheet;

  /// Pill / fully rounded.
  static const ShapeBorder pillShape = StadiumBorder();

  static ThemeData lightTheme() => _buildTheme(
    colorScheme: AppColors.lightColorScheme,
    convColors: ConvocationColors.light,
    baseTextTheme: ThemeData.light().textTheme,
  );

  static ThemeData darkTheme() => _buildTheme(
    colorScheme: AppColors.darkColorScheme,
    convColors: ConvocationColors.dark,
    baseTextTheme: ThemeData.dark().textTheme,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required ConvocationColors convColors,
    required TextTheme baseTextTheme,
  }) {
    final textTheme = AppTypography.textTheme(baseTextTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: convColors.bg,
      extensions: <ThemeExtension<dynamic>>[convColors],

      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (var platform in TargetPlatform.values)
            platform: const NoTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: convColors.bg,
        foregroundColor: convColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: convColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardR),
        margin: EdgeInsets.zero,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: convColors.primary,
          foregroundColor: convColors.onPrimary,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: convColors.cardSoft,
          foregroundColor: convColors.ink,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: convColors.primary,
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: convColors.ink,
          shape: const StadiumBorder(),
          side: BorderSide(color: convColors.hair),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: convColors.primary,
        foregroundColor: convColors.onPrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.fabR),
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: convColors.cardSoft,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.compactR,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.compactR,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.compactR,
          borderSide: BorderSide(color: convColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: convColors.ink3),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: convColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetR),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: convColors.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardR),
      ),

      dividerTheme: DividerThemeData(
        color: convColors.hair,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: convColors.ink2,
        textColor: convColors.ink,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.compactR),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? convColors.primary
              : convColors.ink4,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Color.alphaBlend(
                  convColors.primary.withValues(alpha: 0.3),
                  convColors.bg,
                )
              : convColors.bg3,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.compactR),
      ),
    );
  }
}
