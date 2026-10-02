import 'package:flutter/widgets.dart';

/// Motion tokens for Convocation (DESIGN_SPEC §6, ADR 0008).
///
/// Pages themselves snap (`NoTransitionsBuilder`); these tokens time the few
/// in-surface and shared-element motions layered on top of that.
class AppMotion {
  AppMotion._();

  /// Container transforms and shared-element flights. Emphasized decelerate.
  static const Duration morphDuration = Duration(milliseconds: 400);
  static const Curve morphCurve = Cubic(0.05, 0.7, 0.1, 1);

  /// In-surface changes: counts, thumbs, tiles, bar heights. This is the
  /// existing toggle-thumb curve.
  static const Duration houseDuration = Duration(milliseconds: 220);
  static const Curve houseCurve = Cubic(0.2, 0.7, 0.3, 1);

  /// Dismissals and collapsing back into the source. Emphasized accelerate.
  static const Duration exitDuration = Duration(milliseconds: 200);
  static const Curve exitCurve = Cubic(0.3, 0, 0.8, 0.15);
}

/// Whether decorative motion should run.
///
/// False when the widget's existing test/override [disableAnimations] flag is
/// set or when the system "Remove animations" setting is on. Every motion
/// surface must behave exactly as it did before motion was added when this
/// returns false.
bool motionEnabled(BuildContext context, {bool disableAnimations = false}) {
  return !disableAnimations && !MediaQuery.disableAnimationsOf(context);
}
