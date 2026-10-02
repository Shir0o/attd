import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app_motion.dart';

/// A count that rolls its changed digits like an odometer (#222 M5).
///
/// When [value] changes, each digit that differs rolls over
/// [AppMotion.houseDuration]: the new digit comes up from below when the value
/// went up and down from above when it went down. Unchanged digits and the
/// [suffix] stay put. At rest it is a single `Text('$value$suffix')`, so
/// finders and screen readers see the plain string; mid-roll the semantics
/// read only the new value.
///
/// It snaps when [motionEnabled] is false.
class ConvRollingNumber extends StatefulWidget {
  const ConvRollingNumber({
    super.key,
    required this.value,
    this.suffix = '',
    this.style,
    this.disableAnimations = false,
  });

  final int value;

  /// Static text after the number, e.g. `' left'`.
  final String suffix;
  final TextStyle? style;

  /// The host widget's test/override flag; see [motionEnabled].
  final bool disableAnimations;

  @override
  State<ConvRollingNumber> createState() => _ConvRollingNumberState();
}

class _ConvRollingNumberState extends State<ConvRollingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: AppMotion.houseDuration,
    value: 1,
  );
  late final Animation<double> _eased = CurvedAnimation(
    parent: _roll,
    curve: AppMotion.houseCurve,
  );

  /// The value rolling out, while a roll runs.
  int? _from;

  @override
  void didUpdateWidget(ConvRollingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (!motionEnabled(context, disableAnimations: widget.disableAnimations)) {
      _roll.value = 1;
      return;
    }
    _from = oldWidget.value;
    _roll.forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = '${widget.value}${widget.suffix}';
    return AnimatedBuilder(
      animation: _roll,
      builder: (context, _) {
        final from = _from;
        if (from == null || !_roll.isAnimating) {
          return Text(text, style: widget.style);
        }
        final up = widget.value > from;
        final t = _eased.value;
        final oldDigits = '$from';
        final newDigits = '${widget.value}';
        final width = math.max(oldDigits.length, newDigits.length);
        final o = oldDigits.padLeft(width);
        final n = newDigits.padLeft(width);
        return Semantics(
          label: text,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < width; i++)
                if (o[i] == n[i])
                  Text(n[i], style: widget.style)
                else
                  ClipRect(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (o[i] != ' ')
                          FractionalTranslation(
                            translation: Offset(0, up ? -t : t),
                            child: Text(o[i], style: widget.style),
                          ),
                        if (n[i] != ' ')
                          FractionalTranslation(
                            translation: Offset(0, up ? 1 - t : t - 1),
                            child: Text(n[i], style: widget.style),
                          ),
                      ],
                    ),
                  ),
              if (widget.suffix.isNotEmpty)
                Text(widget.suffix, style: widget.style),
            ],
          ),
        );
      },
    );
  }
}
