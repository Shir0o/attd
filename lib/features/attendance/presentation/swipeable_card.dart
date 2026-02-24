import 'package:flutter/material.dart';
import 'dart:math';

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final double threshold;
  final Color? rightSwipeColor;
  final Color? leftSwipeColor;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.threshold = 100.0,
    this.rightSwipeColor,
    this.leftSwipeColor,
  });

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

  // Animation values driven by default controller or transient tweens
  Animation<Offset>? _slideAnimation;
  Animation<double>? _rotateAnimation;

  // Visual feedback settings
  static const double _rotationFactor = 0.05; // Degrees per pixel of drag
  static const Duration _snapDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _snapDuration)
      ..addListener(() {
        setState(() {
          // This triggers rebuild to show animation values
        });
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Sync state when animation finishes
        if (_slideAnimation != null) _dragOffset = _slideAnimation!.value;
        if (_rotateAnimation != null) _rotation = _rotateAnimation!.value;
        // Reset animations so we go back to manual drag mode (though offset might be non-zero if dismissed)
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_controller.isAnimating) {
      _controller.stop();
      // Sync state/capture current value
      // Note: _slideAnimation might be null if we stopped before it started? Unlikely if isAnimating.
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
      // Rotate based on x movement, slightly modulated by y
      _rotation = _dragOffset.dx * _rotationFactor * (pi / 180);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final velocity = details.velocity.pixelsPerSecond.dx;
    final x = _dragOffset.dx;

    // Check if we should dismiss or snap back
    // Dismiss if dragged past threshold OR flung fast enough
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
    // direction: 1 for right, -1 for left
    final endX = direction * _screenSize.width * 1.5;
    final endY =
        _dragOffset.dy + (_dragOffset.dy * 0.5); // Continue 'drift' in y
    final endOffset = Offset(endX, endY);

    // Continue rotating slightly
    final endRotation = _rotation + (direction * 20 * (pi / 180));

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _rotateAnimation = Tween<double>(
      begin: _rotation,
      end: endRotation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // We can use a clean listener for the callback to avoid complex state
    // But since we are using the main controller, we need to be careful.
    // Let's use `whenComplete` on the forward future.
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

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: rotation,
          child: Stack(
            children: [
              widget.child,
              // Visual Overlay for swipe direction
              if ((_isDragging || _controller.isAnimating) && offset.dx != 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Match card radius
                      color: offset.dx > 0
                          ? (widget.rightSwipeColor ?? Colors.green).withValues(
                              alpha: min(0.3, offset.dx.abs() / 400),
                            )
                          : (widget.leftSwipeColor ?? Colors.red).withValues(
                              alpha: min(0.3, offset.dx.abs() / 400),
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
