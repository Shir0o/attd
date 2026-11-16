/// Small shared pieces of the "Who to check on" screens: the eight-dot
/// history, the flag label, and the dot legend.
library;

import 'package:flutter/material.dart';

import '../../../core/design/widgets/conv_widgets.dart';
import '../domain/check_on.dart';

const double _dotSize = 12;
const double _dotGap = 4;

/// The last eight meetings, oldest first, newest on the right.
///
/// The four states differ by fill, outline and size, never by hue alone:
/// came is a solid disc; missed lately a thick open ring; missed earlier a
/// thin ring with a faint fill; no meeting yet a tiny dot.
class CheckOnDots extends StatelessWidget {
  const CheckOnDots({super.key, required this.history});

  final List<CheckOnSlot> history;

  /// Screen-reader summary, e.g. "Last 8 meetings: came to 5".
  String get semanticsLabel {
    final came = history.where((s) => s == CheckOnSlot.came).length;
    return 'Last ${history.length} meetings: came to $came';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < history.length; i++) ...[
              if (i > 0) const SizedBox(width: _dotGap),
              CheckOnDot(slot: history[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One history dot.
class CheckOnDot extends StatelessWidget {
  const CheckOnDot({super.key, required this.slot});

  final CheckOnSlot slot;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return CustomPaint(
      size: const Size.square(_dotSize),
      painter: _DotPainter(
        slot: slot,
        came: c.primary,
        lately: c.danger,
        earlier: c.ink3,
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.slot,
    required this.came,
    required this.lately,
    required this.earlier,
  });

  final CheckOnSlot slot;
  final Color came;
  final Color lately;
  final Color earlier;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    switch (slot) {
      case CheckOnSlot.came:
        canvas.drawCircle(center, r, Paint()..color = came);
      case CheckOnSlot.missedLately:
        canvas.drawCircle(
          center,
          r - 1.25,
          Paint()
            ..color = lately
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      case CheckOnSlot.missedEarlier:
        canvas.drawCircle(
          center,
          r - 0.75,
          Paint()..color = earlier.withValues(alpha: 0.2),
        );
        canvas.drawCircle(
          center,
          r - 0.75,
          Paint()
            ..color = earlier
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case CheckOnSlot.noMeetingYet:
        canvas.drawCircle(
          center,
          1.75,
          Paint()..color = earlier.withValues(alpha: 0.6),
        );
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.slot != slot ||
      old.came != came ||
      old.lately != lately ||
      old.earlier != earlier;
}

/// A flag's name in its tone: strong in the destructive ink with a mark, soft
/// in body ink. The mark means the strong tone is not carried by colour alone.
class CheckOnFlagLabel extends StatelessWidget {
  const CheckOnFlagLabel(this.flag, {super.key});

  final CheckOnFlag flag;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final strong = flag.tone == CheckOnTone.strong;
    final color = strong ? c.danger : c.ink2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (strong) ...[
          Icon(Icons.error_outline_rounded, size: 14, color: color),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            flag.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Key for the legend, so a test can find it.
const checkOnLegendKey = Key('checkOnLegend');

/// What the dots mean. Decorative: the dots carry their own labels.
class CheckOnLegend extends StatelessWidget {
  const CheckOnLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final style = TextStyle(fontSize: 12, color: c.ink2);
    Widget item(CheckOnSlot slot, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckOnDot(slot: slot),
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        );
    return ExcludeSemantics(
      child: Wrap(
        key: checkOnLegendKey,
        spacing: 14,
        runSpacing: 6,
        children: [
          item(CheckOnSlot.came, 'Came'),
          item(CheckOnSlot.missedLately, 'Missed lately'),
          item(CheckOnSlot.missedEarlier, 'Missed earlier'),
          Text('Last 8 meetings, newest on the right', style: style),
        ],
      ),
    );
  }
}
