import 'package:flutter/material.dart';

import '../../../core/design/app_motion.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';

/// The marking header's **Done** control (#222 M6).
///
/// A violet pill. While marking, its pale violet wash is filled with a violet
/// [ConvProgressFill] as the session progresses (replacing the thin bar), and
/// the label turns on-primary wherever the fill passes under it. When
/// everyone is accounted for it is fully violet and one glow ring fades out.
/// In [solid] mode (confirm lists, which keep their two-tone bar) it is simply
/// violet with an on-primary label.
///
/// All motion (the fill easing, the glow) is skipped when [motionEnabled] is
/// false, leaving the same end states.
class DoneProgressPill extends StatefulWidget {
  const DoneProgressPill({
    super.key,
    required this.progress,
    required this.complete,
    required this.onPressed,
    this.solid = false,
    this.disableAnimations = false,
  });

  /// Share of the session decided so far, 0–1.
  final double progress;

  /// True when nobody is left (and there is someone to mark).
  final bool complete;

  final VoidCallback onPressed;

  /// Solid violet with no progress fill (confirm mode).
  final bool solid;

  final bool disableAnimations;

  @override
  State<DoneProgressPill> createState() => _DoneProgressPillState();
}

/// Key on the glow ring; present only while it is fading out.
const doneGlowKey = Key('doneProgressGlow');

class _DoneProgressPillState extends State<DoneProgressPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(DoneProgressPill old) {
    super.didUpdateWidget(old);
    // One glow per completion: only on the transition, never on a rebuild.
    if (!old.complete &&
        widget.complete &&
        !widget.solid &&
        motionEnabled(context, disableAnimations: widget.disableAnimations)) {
      _glow.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Widget _label(Color color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'Done',
          style: AppTypography.geist(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final motion = motionEnabled(
      context,
      disableAnimations: widget.disableAnimations,
    );
    final filled = widget.solid || widget.complete;
    final fraction = widget.complete ? 1.0 : widget.progress.clamp(0.0, 1.0);
    final wash = Color.alphaBlend(c.primary.withValues(alpha: 0.14), c.card);

    final pill = Material(
      color: widget.solid ? c.primary : wash,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!widget.solid)
            Positioned.fill(
              child: ConvProgressFill(
                key: const Key('doneProgressFill'),
                fraction: fraction,
                color: c.primary,
                disableAnimations: widget.disableAnimations,
              ),
            ),
          // The label colour flips where the fill passes under it: an
          // on-primary copy to the left of the fill's edge, ink to the right.
          if (filled)
            _label(c.onPrimary)
          else
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: motion ? AppMotion.houseDuration : Duration.zero,
              curve: AppMotion.houseCurve,
              builder: (context, f, _) => f >= 1
                  ? _label(c.onPrimary)
                  : ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [c.onPrimary, c.onPrimary, c.ink, c.ink],
                        stops: [0, f, f, 1],
                      ).createShader(bounds),
                      // Any opaque colour: srcIn keeps only the glyph shapes.
                      child: _label(c.ink),
                    ),
            ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: widget.onPressed),
            ),
          ),
        ],
      ),
    );

    return ConvPressable(
      disableAnimations: widget.disableAnimations,
      child: AnimatedBuilder(
        animation: _glow,
        child: pill,
        builder: (context, child) {
          if (!_glow.isAnimating) return child!;
          final t = Curves.decelerate.transform(_glow.value);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  key: doneGlowKey,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    shadows: [
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.5 * (1 - t)),
                        blurRadius: 6,
                        spreadRadius: 12 * t,
                      ),
                    ],
                  ),
                ),
              ),
              child!,
            ],
          );
        },
      ),
    );
  }
}
