import 'package:flutter/widgets.dart';

import '../app_motion.dart';

/// A start-aligned fill covering [fraction] of its track's width and all of
/// its height, easing to a new fraction over [AppMotion.houseDuration]
/// (#222 M5). Lay it over a track (e.g. in a [Stack]); several can stack to
/// draw a multi-tone bar.
///
/// It snaps when [motionEnabled] is false.
class ConvProgressFill extends StatelessWidget {
  const ConvProgressFill({
    super.key,
    required this.fraction,
    required this.color,
    this.disableAnimations = false,
  });

  /// Share of the track to fill, clamped to 0–1.
  final double fraction;
  final Color color;

  /// The host widget's test/override flag; see [motionEnabled].
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return AnimatedFractionallySizedBox(
      duration: motionEnabled(context, disableAnimations: disableAnimations)
          ? AppMotion.houseDuration
          : Duration.zero,
      curve: AppMotion.houseCurve,
      alignment: Alignment.centerLeft,
      widthFactor: fraction.clamp(0.0, 1.0),
      heightFactor: 1,
      child: ColoredBox(color: color),
    );
  }
}
