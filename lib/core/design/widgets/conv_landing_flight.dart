import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../app_motion.dart';
import '../app_radii.dart';
import 'conv_fab_pill_shuttle.dart';

/// Key of the landing shuttle while it is on screen.
const convLandingShuttleKey = ValueKey<String>('convLandingShuttle');

/// Flies a filled stadium from the control a person just used to where their
/// change landed (#222 M3, ADR 0008): along an arc over
/// [AppMotion.morphDuration], its corners easing to [endRadius] and its
/// [label] fading out over the first ~30%. On landing it disappears, revealing
/// whatever it landed on.
///
/// [from] and every rect the target returns are global. The shuttle appears at
/// [from] at once and holds there until [target] completes, so the caller can
/// first wait for the destination to be built. The resolved function is read
/// on every frame of the flight, so the shuttle lands exactly on a destination
/// that is still settling; a null target removes the shuttle without flying.
///
/// The returned future completes once the shuttle is gone. Nothing is shown
/// when [motionEnabled] is false.
Future<void> showConvLandingFlight({
  required BuildContext context,
  required Rect from,
  required Future<Rect Function()?> target,
  required Color color,
  double endRadius = AppRadii.compact,
  Widget? label,
  bool disableAnimations = false,
}) {
  if (!motionEnabled(context, disableAnimations: disableAnimations)) {
    return Future.value();
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject()! as RenderBox;
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _LandingShuttle(
      from: from,
      target: target,
      toOverlay: (rect) => rect.shift(-overlayBox.localToGlobal(Offset.zero)),
      color: color,
      endRadius: endRadius,
      label: label,
      onDone: () {
        entry.remove();
        entry.dispose();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _LandingShuttle extends StatefulWidget {
  const _LandingShuttle({
    required this.from,
    required this.target,
    required this.toOverlay,
    required this.color,
    required this.endRadius,
    required this.label,
    required this.onDone,
  });

  final Rect from;
  final Future<Rect Function()?> target;
  final Rect Function(Rect global) toOverlay;
  final Color color;
  final double endRadius;
  final Widget? label;
  final VoidCallback onDone;

  @override
  State<_LandingShuttle> createState() => _LandingShuttleState();
}

class _LandingShuttleState extends State<_LandingShuttle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: AppMotion.morphDuration,
  );
  Rect Function()? _to;
  late Rect _rect = widget.toOverlay(widget.from);

  @override
  void initState() {
    super.initState();
    // The destination is measured from the ticker, never during build: by
    // then the previous frame's layout is final.
    _flight.addListener(() => setState(_place));
    widget.target.then((to) {
      if (!mounted) return;
      if (to == null) {
        widget.onDone();
        return;
      }
      _to = to;
      _flight.forward().whenCompleteOrCancel(() {
        if (mounted) widget.onDone();
      });
    });
  }

  void _place() {
    final end = widget.toOverlay(_to!());
    final from = widget.toOverlay(widget.from);
    _rect = convArcRectTween(from, end)
        .transform(AppMotion.morphCurve.transform(_flight.value))!;
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _flight.value;
    final eased = AppMotion.morphCurve.transform(t);
    final radius = lerpDouble(
      widget.from.shortestSide / 2,
      widget.endRadius,
      eased,
    )!;
    return Positioned.fromRect(
      rect: _rect,
      child: IgnorePointer(
        child: Material(
          key: convLandingShuttleKey,
          color: widget.color,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: widget.label == null
              ? null
              : Opacity(
                  opacity: (1 - t / 0.3).clamp(0.0, 1.0),
                  // Laid out at its own width and clipped, so the label never
                  // wraps as the shuttle narrows.
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    child: widget.label,
                  ),
                ),
        ),
      ),
    );
  }
}
