import 'package:flutter/material.dart';

import '../app_motion.dart';
import 'conv_theme.dart';

class ConvSegmentOption {
  const ConvSegmentOption({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

/// Capsule segmented control — `.seg` in app.css.
///
/// The selected thumb slides and resizes between segments over
/// [AppMotion.houseDuration] (#222 M8). It snaps when [motionEnabled] is
/// false.
class ConvSegmented extends StatefulWidget {
  const ConvSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.disableAnimations = false,
  });

  final List<ConvSegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// The host widget's test/override flag; see [motionEnabled].
  final bool disableAnimations;

  @override
  State<ConvSegmented> createState() => _ConvSegmentedState();
}

/// Key on the sliding thumb.
const convSegmentedThumbKey = Key('convSegmentedThumb');

class _ConvSegmentedState extends State<ConvSegmented> {
  final GlobalKey _stackKey = GlobalKey();
  late List<GlobalKey> _segmentKeys = _newKeys();

  /// The selected segment's rect inside the stack, once laid out.
  Rect? _thumb;

  List<GlobalKey> _newKeys() =>
      List.generate(widget.options.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(ConvSegmented old) {
    super.didUpdateWidget(old);
    if (old.options.length != widget.options.length) {
      _segmentKeys = _newKeys();
      _thumb = null;
    }
  }

  void _measure() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject();
    final index = widget.selectedIndex;
    if (stack is! RenderBox ||
        !stack.attached ||
        index < 0 ||
        index >= _segmentKeys.length) {
      return;
    }
    final segment = _segmentKeys[index].currentContext?.findRenderObject();
    if (segment is! RenderBox || !segment.attached || !segment.hasSize) return;
    final rect =
        segment.localToGlobal(Offset.zero, ancestor: stack) & segment.size;
    final old = _thumb;
    if (old == null ||
        (old.left - rect.left).abs() > 0.01 ||
        (old.top - rect.top).abs() > 0.01 ||
        (old.width - rect.width).abs() > 0.01 ||
        (old.height - rect.height).abs() > 0.01) {
      setState(() => _thumb = rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final motion = motionEnabled(
      context,
      disableAnimations: widget.disableAnimations,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final thumb = _thumb;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        key: _stackKey,
        children: [
          if (thumb != null)
            AnimatedPositioned(
              key: convSegmentedThumbKey,
              duration: motion ? AppMotion.houseDuration : Duration.zero,
              curve: AppMotion.houseCurve,
              left: thumb.left,
              top: thumb.top,
              width: thumb.width,
              height: thumb.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.options.length; i++) ...[
                _SegButton(
                  key: _segmentKeys[i],
                  option: widget.options[i],
                  active: i == widget.selectedIndex,
                  // Until the thumb has been measured the active segment
                  // paints its own background, so there is no empty frame.
                  paintFill: thumb == null,
                  onTap: () => widget.onChanged(i),
                ),
                if (i < widget.options.length - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    super.key,
    required this.option,
    required this.active,
    required this.paintFill,
    required this.onTap,
  });
  final ConvSegmentOption option;
  final bool active;
  final bool paintFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = active ? c.ink : c.ink3;
    return Material(
      color: active && paintFill ? c.card : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: Semantics(
        button: true,
        selected: active,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
