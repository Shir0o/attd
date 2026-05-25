import 'package:flutter/widgets.dart';

/// Corner-radius tokens for Convocation. Pulled from the pervasive
/// 24 / 22 / 18 / 14 corner family in screens.jsx + app.css.
class AppRadii {
  AppRadii._();

  /// Card radius (24px). Used by the `.card` primitive.
  static const double card = 24;

  /// Soft card radius (22px). Used by `.card-soft`.
  static const double soft = 22;

  /// Bottom-sheet top radius (28px).
  static const double sheet = 28;

  /// Inline tile radius (18px). Used by bulk-action tiles and input chips.
  static const double tile = 18;

  /// Compact tile / search bar radius (14px).
  static const double compact = 14;

  /// FAB squircle radius (22px).
  static const double fab = 22;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius softR = BorderRadius.all(Radius.circular(soft));
  static const BorderRadius sheetR = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius tileR = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius compactR = BorderRadius.all(
    Radius.circular(compact),
  );
  static const BorderRadius fabR = BorderRadius.all(Radius.circular(fab));
}
