import 'package:flutter/material.dart';

/// Color tokens for the **Convocation** design system.
///
/// Values are sRGB approximations of the OKLCH tokens defined in
/// `/tmp/design/attd/project/app.css`. Surface and ink tones come from
/// the violet-tinted neutral ramp; "present" is the violet primary and
/// "absent" is a warm coral, matching the editorial swipe direction.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────────
  /// Primary violet (oklch 54% 0.18 285).
  static const Color primary = Color(0xFF6750A5);

  /// On-primary content (white).
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Soft violet (oklch 76% 0.10 285).
  static const Color violetSoft = Color(0xFFB8AAE0);

  /// Deep violet (oklch 38% 0.18 285).
  static const Color violetDeep = Color(0xFF463081);

  /// Pale violet wash (oklch 94% 0.04 285).
  static const Color violetWash = Color(0xFFECE5F5);

  /// Coral — the "absent" accent (oklch 68% 0.18 25).
  static const Color coral = Color(0xFFE5754D);
  static const Color coralWash = Color(0xFFF4E2D7);

  /// Clay — warm secondary used for "low confidence" / "review" affordances.
  static const Color clay = Color(0xFFDBA572);
  static const Color clayDeep = Color(0xFFB47744);
  static const Color clayWash = Color(0xFFF1EBE0);

  // ── Light surfaces ───────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFBF8FC);
  static const Color lightBg2 = Color(0xFFF2EEF4);
  static const Color lightBg3 = Color(0xFFE5DFEA);
  static const Color lightCard = Color(0xFFFDFBFD);
  static const Color lightCardSoft = Color(0xFFEFE9F2);
  static const Color lightInk = Color(0xFF2A2333);
  static const Color lightInk2 = Color(0xFF524A5A);
  static const Color lightInk3 = Color(0xFF837C8A);
  static const Color lightInk4 = Color(0xFFB5B0BC);
  static const Color lightHair = Color(0xFFD8D3DC);

  // ── Dark surfaces ────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF1A1422);
  static const Color darkBg2 = Color(0xFF211B2A);
  static const Color darkBg3 = Color(0xFF2A2333);
  static const Color darkCard = Color(0xFF251E2E);
  static const Color darkCardSoft = Color(0xFF2D2538);
  static const Color darkInk = Color(0xFFF1EDF3);
  static const Color darkInk2 = Color(0xFFC7C1CE);
  static const Color darkInk3 = Color(0xFF8A82A1);
  static const Color darkInk4 = Color(0xFF5F576B);
  static const Color darkHair = Color(0xFF3A3247);
  static const Color darkPrimary = Color(0xFFB5A4D8);
  static const Color darkOnPrimary = Color(0xFF2E2640);
  static const Color darkPresent = Color(0xFFC2B5DA);
  static const Color darkAbsent = Color(0xFFEAA585);

  /// Seed for [ColorScheme.fromSeed].
  static const Color seed = primary;

  // ── Backwards-compat tokens (referenced by older code paths) ─────────
  static const Color background = lightBg;
  static const Color surface = lightBg;
  static const Color surfaceContainerLow = lightCardSoft;
  static const Color surfaceContainerLowest = lightCard;
  static const Color surfaceContainer = lightBg2;
  static const Color surfaceContainerHigh = lightBg3;
  static const Color surfaceContainerHighest = Color(0xFFE0D9E5);
  static const Color onSurface = lightInk;
  static const Color onSurfaceVariant = lightInk2;
  static const Color outlineVariant = lightHair;
  static const Color surfaceTint = primary;
  static const Color primaryContainer = violetSoft;
  static const Color primaryDim = violetDeep;
  static const Color primaryFixed = violetSoft;
  static const Color secondary = clayDeep;
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFF376B21);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color error = coral;
  static const Color onError = Color(0xFFFFFFFF);

  // ── ColorSchemes ─────────────────────────────────────────────────────
  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: violetSoft,
    secondary: clayDeep,
    onSecondary: Colors.white,
    tertiary: const Color(0xFF376B21),
    onTertiary: Colors.white,
    error: coral,
    onError: Colors.white,
    surface: lightBg,
    onSurface: lightInk,
    onSurfaceVariant: lightInk2,
    surfaceContainerLowest: lightCard,
    surfaceContainerLow: lightCardSoft,
    surfaceContainer: lightBg2,
    surfaceContainerHigh: lightBg3,
    surfaceContainerHighest: const Color(0xFFE0D9E5),
    outlineVariant: lightHair,
    surfaceTint: primary,
  );

  static ColorScheme get darkColorScheme => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: darkPrimary,
    onPrimary: darkOnPrimary,
    primaryContainer: violetDeep,
    secondary: clay,
    onSecondary: Colors.black,
    error: darkAbsent,
    onError: Colors.black,
    surface: darkBg,
    onSurface: darkInk,
    onSurfaceVariant: darkInk2,
    surfaceContainerLowest: darkBg,
    surfaceContainerLow: darkCard,
    surfaceContainer: darkBg2,
    surfaceContainerHigh: darkBg3,
    surfaceContainerHighest: darkCardSoft,
    outlineVariant: darkHair,
    surfaceTint: darkPrimary,
  );
}

/// Extension on [ColorScheme] exposing the Convocation-specific roles
/// (ink ladder, hair line, present/absent semantic, clay accents).
///
/// Use via `Theme.of(context).extension<ConvocationColors>()!` or the
/// convenience getter `context.conv` from `widgets/conv_theme.dart`.
@immutable
class ConvocationColors extends ThemeExtension<ConvocationColors> {
  const ConvocationColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.card,
    required this.cardSoft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.hair,
    required this.primary,
    required this.onPrimary,
    required this.present,
    required this.absent,
    required this.clayDeep,
  });

  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color card;
  final Color cardSoft;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color ink4;
  final Color hair;
  final Color primary;
  final Color onPrimary;
  final Color present;
  final Color absent;
  final Color clayDeep;

  static const ConvocationColors light = ConvocationColors(
    bg: AppColors.lightBg,
    bg2: AppColors.lightBg2,
    bg3: AppColors.lightBg3,
    card: AppColors.lightCard,
    cardSoft: AppColors.lightCardSoft,
    ink: AppColors.lightInk,
    ink2: AppColors.lightInk2,
    ink3: AppColors.lightInk3,
    ink4: AppColors.lightInk4,
    hair: AppColors.lightHair,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    present: AppColors.primary,
    absent: AppColors.coral,
    clayDeep: AppColors.clayDeep,
  );

  static const ConvocationColors dark = ConvocationColors(
    bg: AppColors.darkBg,
    bg2: AppColors.darkBg2,
    bg3: AppColors.darkBg3,
    card: AppColors.darkCard,
    cardSoft: AppColors.darkCardSoft,
    ink: AppColors.darkInk,
    ink2: AppColors.darkInk2,
    ink3: AppColors.darkInk3,
    ink4: AppColors.darkInk4,
    hair: AppColors.darkHair,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    present: AppColors.darkPresent,
    absent: AppColors.darkAbsent,
    clayDeep: AppColors.clay,
  );

  @override
  ConvocationColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? card,
    Color? cardSoft,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? ink4,
    Color? hair,
    Color? primary,
    Color? onPrimary,
    Color? present,
    Color? absent,
    Color? clayDeep,
  }) => ConvocationColors(
    bg: bg ?? this.bg,
    bg2: bg2 ?? this.bg2,
    bg3: bg3 ?? this.bg3,
    card: card ?? this.card,
    cardSoft: cardSoft ?? this.cardSoft,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    ink4: ink4 ?? this.ink4,
    hair: hair ?? this.hair,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    present: present ?? this.present,
    absent: absent ?? this.absent,
    clayDeep: clayDeep ?? this.clayDeep,
  );

  @override
  ConvocationColors lerp(ThemeExtension<ConvocationColors>? other, double t) {
    if (other is! ConvocationColors) return this;
    return ConvocationColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardSoft: Color.lerp(cardSoft, other.cardSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      ink4: Color.lerp(ink4, other.ink4, t)!,
      hair: Color.lerp(hair, other.hair, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      present: Color.lerp(present, other.present, t)!,
      absent: Color.lerp(absent, other.absent, t)!,
      clayDeep: Color.lerp(clayDeep, other.clayDeep, t)!,
    );
  }
}
