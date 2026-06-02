import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/utils/session_roster_utils.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';

/// Attendance-rate trends for a single event.
///
/// Mirrors `TrendsScreen` from the design handoff (`insights.jsx`, "05 Insights").
class EventTrendPage extends StatefulWidget {
  const EventTrendPage({
    super.key,
    required this.event,
    required this.sessions,
    required this.members,
    this.families = const [],
    this.windowSize = 12,
    this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
    this.disableAnimations = false,
  });

  final Event event;
  final List<Session> sessions;
  final List<Member> members;
  final List<Family> families;
  final int windowSize;
  final SessionRepository? sessionRepository;
  final AttendanceRepository? attendanceRepository;
  final EventRepository? eventRepository;
  final bool disableAnimations;

  @override
  State<EventTrendPage> createState() => _EventTrendPageState();
}

class _EventTrendPageState extends State<EventTrendPage> {
  /// Range options — window of most-recent sessions to chart.
  static const _ranges = [12, 26, 52];
  static const _rangeLabels = ['12 wk', '6 mo', 'Year'];

  bool _loading = true;
  int _rangeIndex = 0;
  List<_PointStat> _allPoints = const [];

  @override
  void initState() {
    super.initState();
    _rangeIndex = _ranges.indexOf(widget.windowSize);
    if (_rangeIndex < 0) _rangeIndex = 0;
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    final points = _points();
    if (!widget.disableAnimations) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() {
      _allPoints = points;
      _loading = false;
    });
  }

  /// Chronological present/absent stats for every recorded session.
  List<_PointStat> _points() {
    final relevant = widget.sessions
        .where((s) => s.eventId == widget.event.id && s.deletedAt == null)
        .toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    // Mirror SessionSummaryPage: count present/absent over the event roster, so
    // members with no record default to absent (raw records omit absentees).
    final rosterMembers = widget.event.memberIds.isEmpty
        ? widget.members
        : widget.members
            .where((m) => widget.event.memberIds.contains(m.id))
            .toList();
    return relevant.map((s) {
      final roster = SessionRoster(s, rosterMembers);
      var present = 0;
      var total = 0;
      for (final m in roster.sortedMembers) {
        total++;
        if (roster.getStatus(m) == AttendanceStatus.present) present++;
      }
      return _PointStat(session: s, present: present, total: total);
    }).toList();
  }

  void _openSummary(Session session) {
    final repo = widget.sessionRepository;
    if (repo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(
          session: session,
          members: widget.members,
          families: widget.families,
          sessionRepository: repo,
          attendanceRepository: widget.attendanceRepository,
          eventRepository: widget.eventRepository,
          event: widget.event,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final event = widget.event;
    final windowSize = _ranges[_rangeIndex];

    final appBar = AppBar(
      backgroundColor: c.bg,
      leading: const BackButton(),
      title: ConvEyebrow(event.title),
      centerTitle: true,
      elevation: 0,
    );

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: appBar,
        body: _TrendSkeleton(disableAnimations: widget.disableAnimations),
      );
    }

    final points = _allPoints.length <= windowSize
        ? _allPoints
        : _allPoints.sublist(_allPoints.length - windowSize);
    final df = DateFormat('MMM d');

    if (points.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: appBar,
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
            children: [
              ConvEyebrow('Trends', color: c.primary),
              const SizedBox(height: 6),
              Text(
                event.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 18),
              _Empty(c: c),
            ],
          ),
        ),
      );
    }

    final rates = points.map((p) => p.rate).toList();
    final avg = (rates.reduce((a, b) => a + b) / rates.length * 100).round();
    final half = rates.length ~/ 2;
    final priorAvg = half > 0
        ? (rates.take(half).reduce((a, b) => a + b) / half * 100).round()
        : avg;
    final up = avg >= priorAvg;

    final best = points.reduce((a, b) => a.rate >= b.rate ? a : b);
    final lowest = points.reduce((a, b) => a.rate <= b.rate ? a : b);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: appBar,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
          children: [
            ConvEyebrow('Trends', color: c.primary),
            const SizedBox(height: 6),
            Text(
              event.title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: c.ink,
              ),
            ),
            const SizedBox(height: 18),
            // Hero average
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppTypography.displayNumber(
                      fontSize: 72,
                      color: c.primary,
                    ),
                    children: [
                      TextSpan(text: '$avg'),
                      TextSpan(
                        text: '%',
                        style: AppTypography.displayNumber(
                          fontSize: 30,
                          color: c.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConvEyebrow('Avg · ${points.length} sessions'),
                      const SizedBox(height: 3),
                      Text(
                        '${up ? '↑ up from' : '↓ down from'} $priorAvg% prior',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: up ? c.present : c.absent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Range selector
            Align(
              alignment: Alignment.centerLeft,
              child: ConvSegmented(
                options: [
                  for (final l in _rangeLabels) ConvSegmentOption(label: l),
                ],
                selectedIndex: _rangeIndex,
                onChanged: (i) => setState(() => _rangeIndex = i),
              ),
            ),
            const SizedBox(height: 18),
            // Bar chart
            ConvCardSoft(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                children: [
                  SizedBox(
                    height: 132,
                    child: _BarChart(points: points, avg: avg, primary: c.primary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        points.length >= windowSize
                            ? '$windowSize weeks ago'
                            : df.format(points.first.session.sessionDate),
                        style: TextStyle(fontSize: 10, color: c.ink3),
                      ),
                      Text('Today', style: TextStyle(fontSize: 10, color: c.ink3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Stat tiles
            Row(
              children: [
                Expanded(
                  child: _TrendStat(
                    label: 'Best',
                    value: '${(best.rate * 100).round()}%',
                    sub: df.format(best.session.sessionDate),
                    color: c.present,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrendStat(
                    label: 'Lowest',
                    value: '${(lowest.rate * 100).round()}%',
                    sub: df.format(lowest.session.sessionDate),
                    color: c.absent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TrendStat(
                    label: 'Average',
                    value: '$avg%',
                    sub: _rangeLabels[_rangeIndex],
                    color: c.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Recent sessions
            Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.ink3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                ConvEyebrow('Recent sessions'),
              ],
            ),
            const SizedBox(height: 10),
            for (final p in points.reversed.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SessionRow(
                  point: p,
                  time: event.time,
                  onTap: widget.sessionRepository == null
                      ? null
                      : () => _openSummary(p.session),
                ),
              ),
            const SizedBox(height: 14),
            Center(
              child: ConvEyebrow(
                '100% local · export to CSV anytime',
                color: c.ink4,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointStat {
  _PointStat({
    required this.session,
    required this.present,
    required this.total,
  });
  final Session session;
  final int present;
  final int total;
  int get absent => total - present;
  double get rate => total == 0 ? 0 : present / total;
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.points,
    required this.avg,
    required this.primary,
  });
  final List<_PointStat> points;
  final int avg;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final n = points.length;
    return Stack(
      children: [
        // Bars
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < n; i++) ...[
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: points[i].rate.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary.withValues(
                          alpha: i == n - 1 ? 1 : 0.32,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                if (i < n - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        // Average line + label
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: CustomPaint(
            painter: _AvgLinePainter(
              fraction: 1 - avg / 100,
              color: primary.withValues(alpha: 0.45),
            ),
            child: Align(
              alignment: Alignment(1, -1 + 2 * (1 - avg / 100)),
              child: FractionalTranslation(
                translation: const Offset(0, -1.1),
                child: Text(
                  'AVG $avg%',
                  style: AppTypography.eyebrow(fontSize: 9, color: primary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvgLinePainter extends CustomPainter {
  _AvgLinePainter({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * fraction;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_AvgLinePainter old) =>
      old.fraction != fraction || old.color != color;
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ConvCardSoft(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConvEyebrow(label, fontSize: 9),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.displayNumber(fontSize: 24, color: color)),
          const SizedBox(height: 3),
          Text(sub, style: TextStyle(fontSize: 10, color: c.ink3)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.point, required this.time, this.onTap});
  final _PointStat point;
  final TimeOfDay time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final date = DateFormat('MMM d').format(point.session.sessionDate);
    final dow = DateFormat('EEEE').format(point.session.sessionDate);
    final pct = (point.rate * 100).round();
    return ConvCardSoft(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$dow · ${time.format(context)}',
                style: TextStyle(fontSize: 11, color: c.ink3),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${point.present}',
            style: AppTypography.displayNumber(fontSize: 20, color: c.present),
          ),
          const SizedBox(width: 6),
          Text('·', style: TextStyle(color: c.ink4)),
          const SizedBox(width: 6),
          Text(
            '${point.absent}',
            style: AppTypography.displayNumber(fontSize: 20, color: c.absent),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: AppTypography.displayNumber(fontSize: 14, color: c.ink2),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: c.ink4, size: 18),
        ],
      ),
    );
  }
}

class _TrendSkeleton extends StatelessWidget {
  const _TrendSkeleton({required this.disableAnimations});
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmer(
            width: 80,
            height: 12,
            borderRadius: BorderRadius.circular(4),
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 10),
          AppShimmer(
            width: 220,
            height: 36,
            borderRadius: BorderRadius.circular(6),
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 22),
          AppShimmer(
            width: 160,
            height: 64,
            borderRadius: AppRadii.compactR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 18),
          AppShimmer(
            width: double.infinity,
            height: 180,
            borderRadius: AppRadii.tileR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++) ...[
            AppShimmer(
              width: double.infinity,
              height: 56,
              borderRadius: AppRadii.softR,
              disableAnimations: disableAnimations,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.c});
  final ConvocationColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.show_chart, size: 64, color: c.ink4),
          const SizedBox(height: 14),
          Text(
            'No sessions yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 260,
            child: Text(
              'Trends will appear after you record at least one session for this event.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.ink2, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
