import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../reports/report_export_page.dart';
import '../domain/event_insights.dart';
import 'insights_customize_sheet.dart';

/// Every statistic for one event, on one configurable page.
///
/// Replaces the separate Trends and Regulars screens. Sections are pure
/// renders of a single [EventInsights] computed once per load, so no two
/// sections can disagree about who counts.
class InsightsPage extends StatefulWidget {
  const InsightsPage({
    super.key,
    required this.event,
    required this.sessions,
    required this.members,
    this.families = const [],
    this.eventRepository,
    this.sessionRepository,
    this.disableAnimations = false,
  });

  final Event event;
  final List<Session> sessions;
  final List<Member> members;
  final List<Family> families;
  final EventRepository? eventRepository;
  final SessionRepository? sessionRepository;
  final bool disableAnimations;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  late Event _event;
  late EventInsights _insights;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _recompute();
    _finishLoad();
  }

  Future<void> _finishLoad() async {
    // One computation, so one load to wait on — the old screens each paid for
    // their own fixed-duration skeleton.
    if (!widget.disableAnimations) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _recompute() {
    _insights = EventInsights.from(
      event: _event,
      sessions: widget.sessions,
      members: widget.members,
      families: widget.families,
    );
  }

  Future<void> _applyConfig(InsightsConfig config) async {
    setState(() {
      _event = _event.copyWith(insightsConfig: config);
      _recompute();
    });
    final repo = widget.eventRepository;
    if (repo == null || _event.isReadOnly) return;
    try {
      await repo.updateEvent(_event.copyWith(updatedAt: DateTime.now()));
    } catch (e) {
      debugPrint('Could not save insights configuration: $e');
    }
  }

  void _setRange(InsightsRange range) {
    _applyConfig(_insights.config.copyWith(range: range));
  }

  Future<void> _openCustomize() async {
    final result = await showInsightsCustomizeSheet(
      context,
      config: _insights.config,
      readOnly: _event.isReadOnly,
    );
    if (result != null) await _applyConfig(result);
  }

  void _openExport() {
    final repo = widget.sessionRepository;
    if (repo == null) return;
    final points = _insights.points;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportExportPage(
          sessionRepository: repo,
          initialEventTitles: {_event.title.trim()},
          initialRange: points.isEmpty
              ? null
              : DateTimeRange(
                  start: points.first.date,
                  end: points.last.date,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final appBar = AppBar(
      backgroundColor: c.bg,
      leading: const BackButton(),
      centerTitle: true,
      elevation: 0,
      title: ConvEyebrow(_event.title),
      actions: [
        if (widget.sessionRepository != null)
          IconButton(
            tooltip: 'Export',
            onPressed: _openExport,
            icon: const Icon(Icons.ios_share_outlined),
          ),
        IconButton(
          tooltip: _event.isReadOnly ? 'Insights settings' : 'Customize',
          onPressed: _openCustomize,
          icon: const Icon(Icons.tune),
        ),
      ],
    );

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: appBar,
        body: _Skeleton(disableAnimations: widget.disableAnimations),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: appBar,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          children: [
            ConvEyebrow('Insights', color: c.primary),
            const SizedBox(height: 5),
            Text(
              _event.title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: c.ink,
                    fontSize: 32,
                  ),
            ),
            const SizedBox(height: 16),
            ConvSegmented(
              options: [
                for (final r in InsightsRange.values)
                  ConvSegmentOption(label: r.label),
              ],
              selectedIndex:
                  InsightsRange.values.indexOf(_insights.config.resolvedRange),
              onChanged: (i) => _setRange(InsightsRange.values[i]),
            ),
            const SizedBox(height: 14),
            if (!_insights.hasSessions) _EmptyState(c: c) else ..._sections(c),
            const SizedBox(height: 18),
            Center(
              child: ConvEyebrow(
                '100% local · export anytime',
                color: c.ink4,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(ConvocationColors c) {
    final out = <Widget>[];
    final pending = <Widget>[];

    void flushPair() {
      if (pending.isEmpty) return;
      if (pending.length == 1) {
        out.add(pending.first);
      } else {
        // IntrinsicHeight so equal-height tiles work inside the unbounded
        // ListView — a stretched Row there forces an infinite height.
        out.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: pending[0]),
                const SizedBox(width: 12),
                Expanded(child: pending[1]),
              ],
            ),
          ),
        );
      }
      pending.clear();
      out.add(const SizedBox(height: 12));
    }

    void addWide(Widget w) {
      flushPair();
      out.add(w);
      out.add(const SizedBox(height: 12));
    }

    void addTile(Widget w) {
      pending.add(w);
      if (pending.length == 2) flushPair();
    }

    for (final section in _insights.visibleSections) {
      final needed = _insights.sessionsNeededFor(section);
      if (needed > 0) {
        addWide(_NotYet(section: section, sessionsNeeded: needed, c: c));
        continue;
      }
      switch (section) {
        case InsightsSection.rateOverTime:
          addWide(_RateSection(insights: _insights, c: c));
        case InsightsSection.extremes:
          addWide(_ExtremesRow(insights: _insights, c: c));
        case InsightsSection.regulars:
          addWide(_RegularsSection(insights: _insights, c: c));
        case InsightsSection.lapsed:
          addWide(_LapsedSection(insights: _insights, c: c));
        case InsightsSection.memberTable:
          addWide(_MemberTableSection(insights: _insights, c: c));
        case InsightsSection.firstTimers:
          addWide(_FirstTimersSection(insights: _insights, c: c));
        case InsightsSection.growth:
          addWide(_GrowthSection(insights: _insights, c: c));
        case InsightsSection.guests:
          addTile(
            _StatTile(
              label: 'Guests',
              value: '${_insights.guestMarkCount}',
              sub:
                  '${_insights.firstTimers.where((f) => f.isGuest).length} first-timers',
              color: c.ink,
              c: c,
            ),
          );
        case InsightsSection.lateness:
          addTile(
            _StatTile(
              label: 'Late',
              value: '${_insights.lateRatePercent ?? 0}%',
              sub: 'of present marks',
              color: c.clayDeep,
              c: c,
            ),
          );
        case InsightsSection.streaks:
          final streak = _insights.longestCurrentStreak;
          addTile(
            _StatTile(
              label: 'Longest streak',
              value: '${streak?.currentStreak ?? 0}',
              sub: streak?.member.displayName ?? 'Nobody yet',
              color: c.present,
              c: c,
            ),
          );
        case InsightsSection.medianSize:
          addTile(
            _StatTile(
              label: 'Median',
              value: '${_insights.medianPresentCount ?? 0}',
              sub: 'in the room',
              color: c.ink,
              c: c,
            ),
          );
      }
    }
    flushPair();
    return out;
  }
}

// ── Sections ──────────────────────────────────────────────────────────────

class _RateSection extends StatelessWidget {
  const _RateSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final avg = insights.averageRatePercent ?? 0;
    final prior = insights.priorAverageRatePercent ?? avg;
    final up = insights.isImproving;
    final points = insights.points;
    final df = DateFormat('MMM d');

    return ConvCardSoft(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConvEyebrow('Attendance rate · ${points.length} sessions'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTypography.displayNumber(
                    fontSize: 60,
                    color: c.primary,
                  ),
                  children: [
                    TextSpan(text: '$avg'),
                    TextSpan(
                      text: '%',
                      style: AppTypography.displayNumber(
                        fontSize: 26,
                        color: c.primary.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${up ? '↑ up from' : '↓ down from'} $prior% prior',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: up ? c.present : c.absent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'of ${insights.rosterSize} on roster',
                        style: TextStyle(fontSize: 12, color: c.ink2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: _BarChart(points: points, primary: c.primary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                df.format(points.first.date),
                style: TextStyle(fontSize: 10, color: c.ink2),
              ),
              Text(
                df.format(points.last.date),
                style: TextStyle(fontSize: 10, color: c.ink2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.points, required this.primary});

  final List<SessionPoint> points;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final n = points.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < n; i++) ...[
          Expanded(
            child: FractionallySizedBox(
              heightFactor: points[i].rate.clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: i == n - 1 ? 1 : 0.32),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                    bottom: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          if (i < n - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ExtremesRow extends StatelessWidget {
  const _ExtremesRow({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d');
    final best = insights.bestSession;
    final lowest = insights.lowestSession;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              label: 'Best',
              value: '${best?.ratePercent ?? 0}%',
              sub: best == null ? '—' : df.format(best.date),
              color: c.present,
              c: c,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Lowest',
              value: '${lowest?.ratePercent ?? 0}%',
              sub: lowest == null ? '—' : df.format(lowest.date),
              color: c.absent,
              c: c,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: 'Average',
              value: '${insights.averageRatePercent ?? 0}%',
              sub: insights.config.resolvedRange.label,
              color: c.ink,
              c: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.c,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    return ConvCardSoft(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConvEyebrow(label),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.displayNumber(fontSize: 30, color: color)),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: c.ink2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    required this.c,
    this.accent,
  });

  final String title;
  final List<Widget> children;
  final ConvocationColors c;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ConvCardSoft(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: accent ?? c.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: ConvEyebrow(title)),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RegularsSection extends StatelessWidget {
  const _RegularsSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final regulars = insights.regulars;
    final window = insights.config.resolvedRegularWindow;
    return _SectionCard(
      title: 'Regulars · ${regulars.length}',
      c: c,
      children: [
        if (regulars.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nobody clears ${insights.config.resolvedRegularThresholdPercent}% of the last $window sessions yet.',
              style: TextStyle(fontSize: 13, color: c.ink2),
            ),
          )
        else
          for (final r in regulars.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.member.displayName,
                      style: TextStyle(fontSize: 14, color: c.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${r.recentHits.where((h) => h).length}/${r.recentHits.length}',
                    style: TextStyle(fontSize: 12, color: c.ink2),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _LapsedSection extends StatelessWidget {
  const _LapsedSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final lapsed = insights.lapsed;
    final df = DateFormat('MMM d');
    return _SectionCard(
      title: 'Lapsed · ${lapsed.length}',
      accent: c.absent,
      c: c,
      children: [
        if (lapsed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nobody who was a regular has stopped coming.',
              style: TextStyle(fontSize: 13, color: c.ink2),
            ),
          )
        else
          for (final l in lapsed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  ConvAvatar(
                    letter: l.member.displayName.isEmpty
                        ? '?'
                        : l.member.displayName[0].toUpperCase(),
                    size: 36,
                    tone: ConvTone.absent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.member.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Was ${l.priorAttended} of ${l.priorEligible} · missed last ${l.consecutiveMisses}',
                          style: TextStyle(fontSize: 12, color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                  if (l.lastSeen != null)
                    Text(
                      df.format(l.lastSeen!),
                      style: TextStyle(fontSize: 12, color: c.ink2),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MemberTableSection extends StatelessWidget {
  const _MemberTableSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final lapsedIds = insights.lapsed.map((l) => l.member.id).toSet();
    final rows = insights.memberTable;
    return _SectionCard(
      title: 'Every attendee · ${rows.length}',
      c: c,
      children: [
        for (final m in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    m.member.displayName,
                    style: TextStyle(fontSize: 14, color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lapsedIds.contains(m.member.id)) ...[
                  ConvPill(
                    label: 'Lapsed',
                    fontSize: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${m.attended}/${m.eligible}',
                  style: TextStyle(fontSize: 12, color: c.ink2),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  child: Text(
                    '${m.ratePercent}%',
                    textAlign: TextAlign.right,
                    style: AppTypography.geistTabular(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FirstTimersSection extends StatelessWidget {
  const _FirstTimersSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d');
    final firsts = insights.firstTimers;
    return _SectionCard(
      title: 'First-timers · ${firsts.length}',
      c: c,
      children: [
        if (firsts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nobody new in this range.',
              style: TextStyle(fontSize: 13, color: c.ink2),
            ),
          )
        else
          for (final f in firsts.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      f.name,
                      style: TextStyle(fontSize: 14, color: c.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    df.format(f.firstSeen),
                    style: TextStyle(fontSize: 12, color: c.ink2),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _GrowthSection extends StatelessWidget {
  const _GrowthSection({required this.insights, required this.c});

  final EventInsights insights;
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    final points = insights.points;
    final peak = points.isEmpty
        ? 0
        : points
            .map((p) => p.cumulativePeopleSeen)
            .reduce((a, b) => a > b ? a : b);
    return _SectionCard(
      title: 'People seen · $peak',
      c: c,
      children: [
        const SizedBox(height: 6),
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < points.length; i++) ...[
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: peak == 0
                        ? 0.02
                        : (points[i].cumulativePeopleSeen / peak)
                            .clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                if (i < points.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Distinct people marked present, accumulating over the range.',
          style: TextStyle(fontSize: 12, color: c.ink2),
        ),
      ],
    );
  }
}

/// A section that cannot say anything honest yet.
///
/// Shown rather than hidden: a section toggled on that renders nothing is
/// indistinguishable from a bug, and a partial figure reads as a fact.
class _NotYet extends StatelessWidget {
  const _NotYet({
    required this.section,
    required this.sessionsNeeded,
    required this.c,
  });

  final InsightsSection section;
  final int sessionsNeeded;
  final ConvocationColors c;

  static String _title(InsightsSection s) {
    switch (s) {
      case InsightsSection.rateOverTime:
        return 'Attendance rate';
      case InsightsSection.extremes:
        return 'Best and lowest';
      case InsightsSection.regulars:
        return 'Regulars';
      case InsightsSection.lapsed:
        return 'Lapsed';
      case InsightsSection.guests:
        return 'Guests';
      case InsightsSection.lateness:
        return 'Late';
      case InsightsSection.growth:
        return 'People seen';
      case InsightsSection.memberTable:
        return 'Every attendee';
      case InsightsSection.firstTimers:
        return 'First-timers';
      case InsightsSection.streaks:
        return 'Longest streak';
      case InsightsSection.medianSize:
        return 'Median';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConvCardSoft(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 18, color: c.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConvEyebrow(_title(section)),
                const SizedBox(height: 3),
                Text(
                  sessionsNeeded == 1
                      ? 'Needs 1 more session.'
                      : 'Needs $sessionsNeeded more sessions.',
                  style: TextStyle(fontSize: 13, color: c.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c});

  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.insights_outlined, size: 56, color: c.ink4),
          const SizedBox(height: 14),
          Text(
            'No sessions recorded yet',
            style: TextStyle(fontSize: 16, color: c.ink2),
          ),
          const SizedBox(height: 4),
          Text(
            'Take attendance once and this fills in.',
            style: TextStyle(fontSize: 13, color: c.ink3),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.disableAnimations});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        AppShimmer(
          width: 160,
          height: 34,
          borderRadius: AppRadii.compactR,
          disableAnimations: disableAnimations,
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 4; i++) ...[
          AppShimmer(
            width: double.infinity,
            height: i == 0 ? 190 : 96,
            borderRadius: AppRadii.softR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
