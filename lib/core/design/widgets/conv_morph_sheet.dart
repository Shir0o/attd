import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsHitTestBehavior;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_motion.dart';
import '../app_radii.dart';

/// Key of the box that always covers the morph sheet's visible bounds, from
/// the source control's rect when it opens to the full sheet when formed.
const convMorphSheetBoundsKey = ValueKey<String>('convMorphSheetBounds');

/// How long collapsing back into the source takes on cancel. Longer than
/// [AppMotion.exitDuration] because it plays three staggered fades.
const Duration _collapseDuration = Duration(milliseconds: 300);

// Drag-to-dismiss thresholds, as in Material's BottomSheet.
const double _minFlingVelocity = 700;
const double _closeProgressThreshold = 0.5;

/// A filled control that a morph sheet can grow out of (ADR 0008, #222 M1).
///
/// Give it a `GlobalKey<ConvMorphSourceState>` and pass that key to
/// [showConvMorphSheet]. [color], [borderRadius] and [label] describe how the
/// control looks, so the sheet can start as the control and collapse back into
/// it. The control is hidden while the sheet is up.
class ConvMorphSource extends StatefulWidget {
  const ConvMorphSource({
    super.key,
    required this.color,
    this.borderRadius,
    this.label,
    required this.child,
  });

  /// The control's fill, shown over the sheet while it forms.
  final Color color;

  /// The control's corners. Null means a stadium (half its height).
  final BorderRadius? borderRadius;

  /// A copy of the control's label, faded out as the sheet forms and back in
  /// as it collapses.
  final Widget? label;

  final Widget child;

  @override
  State<ConvMorphSource> createState() => ConvMorphSourceState();
}

class ConvMorphSourceState extends State<ConvMorphSource> {
  bool _hidden = false;

  void _setHidden(bool hidden) {
    if (!mounted || hidden == _hidden) return;
    setState(() => _hidden = hidden);
  }

  /// The control's rect in [ancestor]'s coordinates, or null if it is not
  /// laid out.
  Rect? _rectIn(RenderObject ancestor) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !_hidden,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: widget.child,
    );
  }
}

/// Opens a modal bottom sheet that grows out of the [ConvMorphSource] behind
/// [source] (a container transform, #222 M1).
///
/// Behaves like `showModalBottomSheet(isScrollControlled: true,
/// backgroundColor: Colors.transparent)`: the sheet draws its own surface,
/// rides up with the keyboard, and the scrim, back button and drag-down all
/// dismiss it.
///
/// How it leaves depends on how it was closed:
/// - popped with `null` (scrim tap, back, a close control): collapses back
///   into the source;
/// - dragged down past half its height or flung: slides off the bottom;
/// - popped with a non-null result (a submit): slides straight down. The
///   returned future completes with that result as soon as the slide starts,
///   so the caller can start a landing flight from it.
///
/// When motion is off ([motionEnabled] is false) or [source] is not mounted,
/// this is exactly that plain `showModalBottomSheet` call.
///
/// Content that would autofocus a field should wait for the sheet to form;
/// see [convMorphSheetFormingOf].
Future<T?> showConvMorphSheet<T>({
  required BuildContext context,
  required GlobalKey<ConvMorphSourceState> source,
  required WidgetBuilder builder,
  bool disableAnimations = false,
}) {
  if (source.currentState == null ||
      !motionEnabled(context, disableAnimations: disableAnimations)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _ConvMorphSheetRoute<T>(
      source: source,
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
    ),
  );
}

/// The entrance of the morph sheet around [context] while it is still
/// forming, or null when it has formed or [context] is not in a morph sheet
/// (a plain modal sheet, or motion is off).
///
/// Safe to call from `initState`. A sheet that would autofocus a field should
/// instead request focus once this completes, so the keyboard rises only after
/// the sheet has formed.
Animation<double>? convMorphSheetFormingOf(BuildContext context) {
  final scope = context
      .getElementForInheritedWidgetOfExactType<_ConvMorphSheetScope>()
      ?.widget as _ConvMorphSheetScope?;
  final animation = scope?.route.animation;
  if (animation == null || animation.isCompleted) return null;
  return animation;
}

class _ConvMorphSheetScope extends InheritedWidget {
  const _ConvMorphSheetScope({required this.route, required super.child});

  final _ConvMorphSheetRoute<dynamic> route;

  @override
  bool updateShouldNotify(_ConvMorphSheetScope oldWidget) =>
      route != oldWidget.route;
}

/// How the route's next reverse plays.
enum _Exit {
  /// Collapse back into the source (cancel).
  collapse,

  /// Follow the finger, then slide off linearly (drag down).
  drag,

  /// Slide straight down with the exit curve (submit).
  submit,
}

class _ConvMorphSheetRoute<T> extends PopupRoute<T> {
  _ConvMorphSheetRoute({
    required this.source,
    required this.builder,
    required this.capturedThemes,
    required this.barrierLabel,
    required this.barrierOnTapHint,
    Color? modalBarrierColor,
  }) : barrierColor = modalBarrierColor ?? Colors.black54;

  final GlobalKey<ConvMorphSourceState> source;
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final String barrierOnTapHint;

  @override
  final String barrierLabel;

  @override
  final Color barrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => AppMotion.morphDuration;

  @override
  Duration get reverseTransitionDuration => _collapseDuration;

  _Exit _exit = _Exit.collapse;
  bool _popped = false;

  /// Whether a collapse started from the fully formed sheet. A cancel while
  /// still forming instead plays the opening backwards, so nothing jumps.
  bool _collapseFromFormed = false;

  /// The source's look, captured at open.
  late final ConvMorphSource _sourceWidget = source.currentState!.widget;
  Rect? _lastSourceRect;

  @override
  void install() {
    super.install();
    animation!.addStatusListener(_handleStatus);
    source.currentState?._setHidden(true);
  }

  void _handleStatus(AnimationStatus status) {
    // A drag that sprang back is fully formed again: cancel collapses.
    if (status.isCompleted) _exit = _Exit.collapse;
    if (status.isDismissed && _popped) _showSource();
  }

  void _showSource() => source.currentState?._setHidden(false);

  @override
  bool didPop(T? result) {
    _popped = true;
    if (result != null) _exit = _Exit.submit;
    _collapseFromFormed = controller!.isCompleted;
    controller!.reverseDuration =
        _exit == _Exit.collapse ? _collapseDuration : AppMotion.exitDuration;
    return super.didPop(result);
  }

  @override
  void dispose() {
    // Removed without playing its exit (e.g. `Navigator.removeRoute`): bring
    // the source back once this frame is done building.
    scheduleMicrotask(_showSource);
    super.dispose();
  }

  /// The source's current rect in the overlay, re-measured every frame so a
  /// collapse lands where the control is now (it may have moved with the
  /// keyboard).
  Rect? _measureSource() {
    final overlay = navigator?.overlay?.context.findRenderObject();
    final rect = overlay == null ? null : source.currentState?._rectIn(overlay);
    return _lastSourceRect = rect ?? _lastSourceRect;
  }

  void _drag(double fraction) {
    _exit = _Exit.drag;
    controller!.value -= fraction;
  }

  void _release(double velocity) {
    if (velocity > _minFlingVelocity ||
        controller!.value < _closeProgressThreshold) {
      if (isCurrent) navigator!.pop();
    } else {
      controller!.animateTo(
        1,
        duration: AppMotion.houseDuration,
        curve: AppMotion.houseCurve,
      );
    }
  }

  /// Where every layer is at the current animation value.
  _MorphFrame _frame() {
    final v = animation!.value;
    if (_exit != _Exit.collapse) {
      return _MorphFrame.sliding(
        _exit == _Exit.submit ? AppMotion.exitCurve.flipped.transform(v) : v,
      );
    }
    if (_popped && _collapseFromFormed) {
      // Cancel: content fades first, the fill returns, the label comes last.
      // The shape lands softly on the source (the morph curve, run from the
      // sheet back to the source); an accelerating curve would still be well
      // short of the source on the last frame and then snap into it.
      return _MorphFrame(
        geometry: AppMotion.morphCurve.flipped.transform(v),
        content: _ramp(v, 0.7, 1),
        fill: 1 - _ramp(v, 0.4, 0.8),
        label: 1 - _ramp(v, 0, 0.2),
      );
    }
    // Open: the label goes first, the fill fades out, the content settles in.
    return _MorphFrame(
      geometry: AppMotion.morphCurve.transform(v),
      content: _ramp(v, 0.3, 0.8),
      fill: 1 - _ramp(v, 0.15, 0.55),
      label: 1 - _ramp(v, 0, 0.2),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget page = DisplayFeatureSubScreen(child: _MorphSheetPage(route: this));
    page = MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: page,
    );
    // Taps inside the sheet must not pass through to the barrier.
    page = Semantics(
      hitTestBehavior: SemanticsHitTestBehavior.opaque,
      child: page,
    );
    return capturedThemes.wrap(page);
  }

  @override
  Widget buildModalBarrier() {
    return AnimatedModalBarrier(
      color: animation!.drive(
        ColorTween(
          begin: barrierColor.withValues(alpha: 0),
          end: barrierColor,
        ).chain(CurveTween(curve: barrierCurve)),
      ),
      dismissible: barrierDismissible,
      semanticsLabel: barrierLabel,
      barrierSemanticsDismissible: semanticsDismissible,
      semanticsOnTapHint: barrierOnTapHint,
    );
  }
}

/// 0 below [from], 1 above [to], linear between.
double _ramp(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0);

class _MorphFrame {
  const _MorphFrame({
    required this.geometry,
    required this.content,
    required this.fill,
    required this.label,
  }) : slide = 1;

  /// Fully formed, slid [slide] of the way up (1 is in place).
  const _MorphFrame.sliding(this.slide)
      : geometry = 1,
        content = 1,
        fill = 0,
        label = 0;

  /// 0 at the source's rect and radius, 1 at the sheet's.
  final double geometry;
  final double content;
  final double fill;
  final double label;
  final double slide;

  bool get clips => geometry < 1;
}

class _MorphSheetPage extends StatefulWidget {
  const _MorphSheetPage({required this.route});

  final _ConvMorphSheetRoute<dynamic> route;

  @override
  State<_MorphSheetPage> createState() => _MorphSheetPageState();
}

class _MorphSheetPageState extends State<_MorphSheetPage> {
  final _bounds = _MorphBounds();
  bool _dragging = false;

  _ConvMorphSheetRoute<dynamic> get _route => widget.route;

  void _dragStart(DragStartDetails _) {
    // Only a formed sheet can be dragged; mid-morph it would jump.
    _dragging = _route.animation!.isCompleted && !_route._popped;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (!_dragging || _bounds.sheetHeight == 0) return;
    _route._drag(details.primaryDelta! / _bounds.sheetHeight);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _route._release(details.velocity.pixelsPerSecond.dy);
  }

  String _routeLabel(MaterialLocalizations localizations) =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => '',
        _ => localizations.dialogLabel,
      };

  @override
  Widget build(BuildContext context) {
    final sheet = _ConvMorphSheetScope(
      route: _route,
      child: GestureDetector(
        excludeFromSemantics: true,
        onVerticalDragStart: _dragStart,
        onVerticalDragUpdate: _dragUpdate,
        onVerticalDragEnd: _dragEnd,
        child: Material(
          type: MaterialType.transparency,
          child: Builder(builder: _route.builder),
        ),
      ),
    );
    final source = _route._sourceWidget;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: _routeLabel(MaterialLocalizations.of(context)),
      explicitChildNodes: true,
      child: AnimatedBuilder(
        animation: _route.animation!,
        child: sheet,
        builder: (context, sheet) {
          final frame = _route._frame();
          final sourceRect = _route._measureSource();
          final sourceRadius = source.borderRadius ??
              BorderRadius.circular((sourceRect?.height ?? 0) / 2);
          return _MorphClip(
            bounds: _bounds,
            radius: BorderRadius.lerp(
              sourceRadius,
              AppRadii.sheetR,
              frame.geometry,
            )!,
            enabled: frame.clips,
            child: CustomMultiChildLayout(
              delegate: _MorphLayout(
                bounds: _bounds,
                sourceRect: sourceRect,
                frame: frame,
              ),
              children: [
                LayoutId(
                  id: _Slot.sheet,
                  child: Opacity(opacity: frame.content, child: sheet),
                ),
                LayoutId(
                  id: _Slot.bounds,
                  child: IgnorePointer(
                    key: convMorphSheetBoundsKey,
                    child: Opacity(
                      opacity: frame.fill,
                      child: ColoredBox(color: source.color),
                    ),
                  ),
                ),
                if (source.label != null && frame.label > 0)
                  LayoutId(
                    id: _Slot.label,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: Opacity(
                          opacity: frame.label,
                          child: Material(
                            type: MaterialType.transparency,
                            child: source.label,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Slot { sheet, bounds, label }

/// Where the visible sheet is this frame, written during layout and read when
/// painting the clip.
class _MorphBounds {
  Rect rect = Rect.zero;
  double sheetHeight = 0;
}

class _MorphLayout extends MultiChildLayoutDelegate {
  _MorphLayout({
    required this.bounds,
    required this.sourceRect,
    required this.frame,
  });

  final _MorphBounds bounds;
  final Rect? sourceRect;
  final _MorphFrame frame;

  /// Content rises this far into place as it fades in.
  static const double _settle = 6;

  @override
  void performLayout(Size size) {
    // Full width up to Material's 640 px sheet limit, as tall as the content
    // (scroll controlled), pinned to the bottom.
    final width = math.min(size.width, 640.0);
    final sheetSize = layoutChild(
      _Slot.sheet,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
    );
    final shown = Rect.fromLTWH(
      (size.width - width) / 2,
      size.height - sheetSize.height * frame.slide,
      width,
      sheetSize.height,
    );
    final visible = Rect.lerp(sourceRect ?? shown, shown, frame.geometry)!;
    bounds
      ..rect = visible
      ..sheetHeight = sheetSize.height;

    positionChild(
      _Slot.sheet,
      shown.topLeft.translate(0, _settle * (1 - frame.content)),
    );
    layoutChild(_Slot.bounds, BoxConstraints.tight(visible.size));
    positionChild(_Slot.bounds, visible.topLeft);
    if (hasChild(_Slot.label)) {
      final labelSize = layoutChild(_Slot.label, BoxConstraints.loose(size));
      positionChild(
        _Slot.label,
        visible.center - Offset(labelSize.width / 2, labelSize.height / 2),
      );
    }
  }

  @override
  bool shouldRelayout(_MorphLayout oldDelegate) => true;
}

/// Clips its child to the morph bounds measured by [_MorphLayout] this frame.
class _MorphClip extends SingleChildRenderObjectWidget {
  const _MorphClip({
    required this.bounds,
    required this.radius,
    required this.enabled,
    super.child,
  });

  final _MorphBounds bounds;
  final BorderRadius radius;
  final bool enabled;

  @override
  _RenderMorphClip createRenderObject(BuildContext context) =>
      _RenderMorphClip(bounds: bounds, radius: radius, enabled: enabled);

  @override
  void updateRenderObject(BuildContext context, _RenderMorphClip renderObject) {
    renderObject
      ..radius = radius
      ..enabled = enabled;
  }
}

class _RenderMorphClip extends RenderProxyBox {
  _RenderMorphClip({
    required this.bounds,
    required BorderRadius radius,
    required bool enabled,
  })  : _radius = radius,
        _enabled = enabled;

  final _MorphBounds bounds;
  final _clipLayer = LayerHandle<ClipRRectLayer>();

  BorderRadius _radius;
  set radius(BorderRadius value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsPaint();
  }

  RRect get _rrect => _radius.toRRect(bounds.rect);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_enabled && !_rrect.contains(position)) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !_enabled) {
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _rrect,
      super.paint,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}
