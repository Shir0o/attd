import 'package:flutter/material.dart';
import 'dart:math';

class SwipeProgress {
  const SwipeProgress({
    required this.dx,
    required this.rightProgress,
    required this.leftProgress,
  });

  final double dx;
  final double rightProgress;
  final double leftProgress;
}

/// Lets a parent programmatically trigger the same fly-off animation as a
/// manual swipe (e.g. from footer Present/Absent buttons).
class SwipeableCardController {
  _SwipeableCardState? _state;

  void swipeRight() => _state?._programmaticDismiss(1);
  void swipeLeft() => _state?._programmaticDismiss(-1);
}

class SwipeableCard extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext, SwipeProgress)? childBuilder;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double threshold;
  final Color? rightSwipeColor;
  final Color? leftSwipeColor;
  final SwipeableCardController? controller;

  const SwipeableCard({
    super.key,
    this.child,
    this.childBuilder,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.threshold = 100.0,
    this.rightSwipeColor,
    this.leftSwipeColor,
    this.controller,
  }) : assert(child != null || childBuilder != null,
            'Provide either child or childBuilder');

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;
  double _rotation = 0.0;
  bool _isDragging = false;
  Size _screenSize = Size.zero;

  Animation<Offset>? _slideAnimation;
  Animation<double>? _rotateAnimation;

  static const double _rotationFactor = 0.05;
  static const Duration _snapDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _snapDuration)
      ..addListener(() {
        setState(() {});
      });

    widget.controller?._state = this;

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_slideAnimation != null) _dragOffset = _slideAnimation!.value;
        if (_rotateAnimation != null) _rotation = _rotateAnimation!.value;
        _slideAnimation = null;
        _rotateAnimation = null;
        _controller.reset();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void didUpdateWidget(SwipeableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _controller.dispose();
    super.dispose();
  }

  void _programmaticDismiss(int direction) {
    if (_controller.isAnimating || _isDragging) return;
    _animateToDismiss(direction: direction);
  }

  void _onPanStart(DragStartDetails details) {
    if (_controller.isAnimating) {
      _controller.stop();
      if (_slideAnimation != null) _dragOffset = _slideAnimation!.value;
      if (_rotateAnimation != null) _rotation = _rotateAnimation!.value;
    }
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _rotation = _dragOffset.dx * _rotationFactor * (pi / 180);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final velocity = details.velocity.pixelsPerSecond.dx;
    final x = _dragOffset.dx;

    if (x > widget.threshold || (x > 0 && velocity > 1000)) {
      _animateToDismiss(direction: 1);
    } else if (x < -widget.threshold || (x < 0 && velocity < -1000)) {
      _animateToDismiss(direction: -1);
    } else {
      _animateBackToCenter();
    }
  }

  void _animateBackToCenter() {
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _rotateAnimation = Tween<double>(
      begin: _rotation,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0.0);
  }

  void _animateToDismiss({required int direction}) {
    final endX = direction * _screenSize.width * 1.5;
    final endY = _dragOffset.dy + (_dragOffset.dy * 0.5);
    final endOffset = Offset(endX, endY);

    final endRotation = _rotation + (direction * 20 * (pi / 180));

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _rotateAnimation = Tween<double>(
      begin: _rotation,
      end: endRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0.0).then((_) {
      if (direction == 1) {
        widget.onSwipeRight?.call();
      } else {
        widget.onSwipeLeft?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final offset = _controller.isAnimating && _slideAnimation != null
        ? _slideAnimation!.value
        : _dragOffset;

    final rotation = _controller.isAnimating && _rotateAnimation != null
        ? _rotateAnimation!.value
        : _rotation;

    final dx = offset.dx;
    final rightProgress = (dx / 80).clamp(0.0, 1.0);
    final leftProgress = (-dx / 80).clamp(0.0, 1.0);
    final progress = SwipeProgress(
      dx: dx,
      rightProgress: rightProgress,
      leftProgress: leftProgress,
    );

    final body = widget.childBuilder != null
        ? widget.childBuilder!(context, progress)
        : widget.child!;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              body,
              if ((_isDragging || _controller.isAnimating) && dx != 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: dx > 0
                            ? (widget.rightSwipeColor ?? Colors.green)
                                .withValues(
                                    alpha: min(0.18, dx.abs() / 500))
                            : (widget.leftSwipeColor ?? Colors.red)
                                .withValues(
                                    alpha: min(0.18, dx.abs() / 500)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
