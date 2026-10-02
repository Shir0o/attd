import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Hero rect tween that travels along a gentle arc instead of a straight line.
RectTween convArcRectTween(Rect? begin, Rect? end) =>
    MaterialRectArcTween(begin: begin, end: end);

/// Shuttle for the Hub FAB <-> Add Event pill Hero (ADR 0008).
///
/// The flight animation always runs 0 at the FAB to 1 at the pill (a pop
/// flight plays it backwards), so one builder mirrors both directions: the
/// corner radius grows from the FAB squircle to the pill's stadium, the icon
/// fades out over roughly the first 35% and the label fades in from roughly
/// 45%. The label is laid out at its intrinsic width and clipped, so it is
/// never wrapped or squeezed while the box is still narrow.
HeroFlightShuttleBuilder convFabPillShuttleBuilder({
  required String label,
  required Color color,
  required Color onColor,
  required TextStyle labelStyle,
  double fabRadius = 24,
  IconData icon = Icons.add,
}) {
  return (flightContext, animation, direction, fromContext, toContext) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value.clamp(0.0, 1.0);
        final iconOpacity = (1 - t / 0.35).clamp(0.0, 1.0);
        final labelOpacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final radius = lerpDouble(
              fabRadius,
              constraints.biggest.shortestSide / 2,
              t,
            )!;
            return Material(
              key: const ValueKey('fab_pill_shuttle'),
              color: color,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: iconOpacity,
                    child: Icon(icon, size: 24, color: onColor),
                  ),
                  Opacity(
                    opacity: labelOpacity,
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      child: Text(
                        label,
                        key: const ValueKey('fab_pill_shuttle_label'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: labelStyle.copyWith(
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  };
}
