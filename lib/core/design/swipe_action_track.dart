import 'package:flutter/material.dart';
import 'app_colors.dart';

class SwipeActionTrack extends StatefulWidget {
  const SwipeActionTrack({
    super.key,
    required this.onSwipeComplete,
    this.label = 'Swipe to confirm',
    this.icon = Icons.chevron_right,
    this.height = 64,
    this.disableAnimations = false,
  });

  final VoidCallback onSwipeComplete;
  final String label;
  final IconData icon;
  final double height;
  final bool disableAnimations;

  @override
  State<SwipeActionTrack> createState() => _SwipeActionTrackState();
}

class _SwipeActionTrackState extends State<SwipeActionTrack>
    with SingleTickerProviderStateMixin {
  double _dragValue = 0.0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _dragValue = (_dragValue + details.delta.dx / maxWidth).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragValue > 0.8) {
      setState(() {
        _dragValue = 1.0;
      });
      widget.onSwipeComplete();
      // Reset after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _dragValue = 0.0;
          });
        }
      });
    } else {
      _animateBack();
    }
  }

  void _animateBack() {
    _animation = Tween<double>(
      begin: _dragValue,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragValue = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayValue = _controller.isAnimating ? _animation.value : _dragValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final handleSize = widget.height - 8;
        final availableWidth = maxWidth - handleSize - 8;

        return Container(
          width: maxWidth,
          height: widget.height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              // Track Fill
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: (maxWidth - 8) * displayValue + handleSize / 2,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                  ),
                ),
              ),

              // Label
              Center(
                child: Opacity(
                  opacity: (1.0 - displayValue * 2).clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // Handle
              Positioned(
                left: availableWidth * displayValue,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) => _onDragUpdate(details, availableWidth),
                  onHorizontalDragEnd: _onDragEnd,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(handleSize / 2),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
