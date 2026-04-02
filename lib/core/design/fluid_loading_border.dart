import 'package:flutter/material.dart';
import 'dart:math' as math;

class FluidLoadingBorder extends StatefulWidget {
  const FluidLoadingBorder({
    super.key,
    required this.child,
    this.isLoading = false,
    this.borderWidth = 6.0,
    this.borderRadius = 32.0,
    this.gradientColors,
  });

  final Widget child;
  final bool isLoading;
  final double borderWidth;
  final double borderRadius;
  final List<Color>? gradientColors;

  @override
  State<FluidLoadingBorder> createState() => _FluidLoadingBorderState();
}

class _FluidLoadingBorderState extends State<FluidLoadingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FluidLoadingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final defaultColors = [
      colorScheme.primary.withOpacity(0.0),
      colorScheme.primary.withOpacity(0.8),
      colorScheme.primary,
      colorScheme.primary.withOpacity(0.8),
      colorScheme.primary.withOpacity(0.0),
    ];

    return Stack(
      children: [
        widget.child,
        if (widget.isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _BorderPainter(
                      progress: _controller.value,
                      borderWidth: widget.borderWidth,
                      borderRadius: widget.borderRadius,
                      colors: widget.gradientColors ?? defaultColors,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _BorderPainter extends CustomPainter {
  _BorderPainter({
    required this.progress,
    required this.borderWidth,
    required this.borderRadius,
    required this.colors,
  });

  final double progress;
  final double borderWidth;
  final double borderRadius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final path = Path()..addRRect(rRect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Use a sweep gradient for the rotating effect
    // We adjust the stops to make the "light" segment smaller and more focused
    paint.shader = SweepGradient(
      colors: colors,
      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    ).createShader(rect);

    // Add a stronger blur effect for the "lighting" feel
    canvas.saveLayer(rect, Paint());
    
    // Outer glow
    canvas.drawPath(path, paint..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12));
    // Core light
    canvas.drawPath(path, paint..maskFilter = null..strokeWidth = borderWidth * 0.75);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.colors != colors;
  }
}
