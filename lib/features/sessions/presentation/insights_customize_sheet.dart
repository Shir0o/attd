import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../domain/insights_config.dart';

/// Tune what Insights shows and what its words mean, on the page itself.
///
/// Editing here rather than in Edit Event is the point: moving a threshold and
/// watching the affected list change is the interaction. Read-only on a shared
/// event the user does not own — `Event.isReadOnly` means the write would be
/// discarded anyway.
Future<InsightsConfig?> showInsightsCustomizeSheet(
  BuildContext context, {
  required InsightsConfig config,
  bool readOnly = false,
}) {
  return showModalBottomSheet<InsightsConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomizeSheet(config: config, readOnly: readOnly),
  );
}

const _sectionLabels = <InsightsSection, String>{
  InsightsSection.rateOverTime: 'Attendance rate over time',
  InsightsSection.extremes: 'Best, lowest and average',
  InsightsSection.regulars: 'Regulars',
  InsightsSection.lapsed: 'Lapsed attendees',
  InsightsSection.guests: 'Guests',
  InsightsSection.lateness: 'Late arrivals',
  InsightsSection.growth: 'People seen over time',
  InsightsSection.memberTable: 'Every attendee',
  InsightsSection.firstTimers: 'First-timers',
  InsightsSection.streaks: 'Longest streak',
  InsightsSection.medianSize: 'Median session size',
};

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.config, required this.readOnly});

  final InsightsConfig config;
  final bool readOnly;

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late Set<InsightsSection> _visible;
  late int _regularThreshold;
  late int _regularWindow;
  late int _lapsedMisses;
  late int _lapsedMinPrior;

  @override
  void initState() {
    super.initState();
    _visible = {...widget.config.resolvedVisibleSections};
    _regularThreshold = widget.config.resolvedRegularThresholdPercent;
    _regularWindow = widget.config.resolvedRegularWindow;
    _lapsedMisses = widget.config.resolvedLapsedConsecutiveMisses;
    _lapsedMinPrior = widget.config.resolvedLapsedMinimumPriorSessions;
  }

  void _save() {
    Navigator.of(context).pop(
      widget.config.copyWith(
        visibleSections: _visible,
        regularThresholdPercent: _regularThreshold,
        regularWindow: _regularWindow,
        lapsedConsecutiveMisses: _lapsedMisses,
        lapsedMinimumPriorSessions: _lapsedMinPrior,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final ro = widget.readOnly;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      // A Material ancestor, not a plain coloured box: the switch rows paint
      // their ink on the nearest Material.
      builder: (context, controller) => Material(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hair,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ConvEyebrow(ro ? 'Insights settings' : 'Customize',
                color: c.primary),
            const SizedBox(height: 6),
            Text(
              ro ? 'Set by the event owner' : 'What this event counts',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: c.ink),
            ),
            if (ro) ...[
              const SizedBox(height: 10),
              Text(
                'This event is shared with you, so its Insights settings are '
                'read-only. You see the same definitions the owner does.',
                style: TextStyle(fontSize: 13, color: c.ink2),
              ),
            ],
            const SizedBox(height: 22),
            ConvEyebrow('A regular attends'),
            const SizedBox(height: 8),
            _Stepper(
              label: '$_regularThreshold% of the last $_regularWindow sessions',
              onLess: ro || _regularThreshold <= 50
                  ? null
                  : () => setState(() => _regularThreshold -= 10),
              onMore: ro || _regularThreshold >= 100
                  ? null
                  : () => setState(() => _regularThreshold += 10),
              c: c,
            ),
            const SizedBox(height: 10),
            _Stepper(
              label: 'Window of $_regularWindow sessions',
              onLess: ro || _regularWindow <= 4
                  ? null
                  : () => setState(() => _regularWindow -= 2),
              onMore: ro || _regularWindow >= 20
                  ? null
                  : () => setState(() => _regularWindow += 2),
              c: c,
            ),
            const SizedBox(height: 22),
            ConvEyebrow('Someone has lapsed after'),
            const SizedBox(height: 8),
            _Stepper(
              label: _lapsedMisses == 1
                  ? '1 missed session in a row'
                  : '$_lapsedMisses missed sessions in a row',
              onLess: ro || _lapsedMisses <= 2
                  ? null
                  : () => setState(() => _lapsedMisses -= 1),
              onMore: ro || _lapsedMisses >= 10
                  ? null
                  : () => setState(() => _lapsedMisses += 1),
              c: c,
            ),
            const SizedBox(height: 10),
            _Stepper(
              label: _lapsedMinPrior == 1
                  ? 'Judged on 1 prior session'
                  : 'Judged on $_lapsedMinPrior prior sessions',
              onLess: ro || _lapsedMinPrior <= 2
                  ? null
                  : () => setState(() => _lapsedMinPrior -= 1),
              onMore: ro || _lapsedMinPrior >= 12
                  ? null
                  : () => setState(() => _lapsedMinPrior += 1),
              c: c,
            ),
            const SizedBox(height: 6),
            Text(
              'Below this much history the section says so instead of naming '
              'anyone.',
              style: TextStyle(fontSize: 12, color: c.ink2),
            ),
            const SizedBox(height: 26),
            ConvEyebrow('Sections'),
            const SizedBox(height: 4),
            for (final entry in _sectionLabels.entries)
              SwitchListTile.adaptive(
                key: ValueKey('section_${entry.key.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.value,
                  style: TextStyle(fontSize: 15, color: c.ink),
                ),
                value: _visible.contains(entry.key),
                onChanged: ro
                    ? null
                    : (on) => setState(() {
                          if (on) {
                            _visible.add(entry.key);
                          } else {
                            _visible.remove(entry.key);
                          }
                        }),
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: ro ? () => Navigator.of(context).pop() : _save,
                child: Text(ro ? 'Close' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.onLess,
    required this.onMore,
    required this.c,
  });

  final String label;
  final VoidCallback? onLess;
  final VoidCallback? onMore;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    return ConvCardSoft(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onLess,
            icon: const Icon(Icons.remove),
            tooltip: 'Less',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: onMore,
            icon: const Icon(Icons.add),
            tooltip: 'More',
          ),
        ],
      ),
    );
  }
}
