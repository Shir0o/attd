import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';
import 'consistent_members_page.dart';

/// 12-week attendance sparkline for a single event.
///
/// Mirrors `SummaryPreview` in
/// `/tmp/design/attd/project/marketing.jsx` (lines 289–331).
class EventTrendPage extends StatefulWidget {
  const EventTrendPage({
    super.key,
    required this.event,
    required this.sessions,
    required this.members,
    this.families = const [],
    this.windowSize = 12,
    this.disableAnimations = false,
  });

  final Event event;
  final List<Session> sessions;
  final List<Member> members;
  final List<Family> families;
  final int windowSize;
  final bool disableAnimations;

  @override
  State<EventTrendPage> createState() => _EventTrendPageState();
}

class _EventTrendPageState extends State<EventTrendPage> {
  bool _loading = true;
  List<_PointStat> _cachedPoints = const [];
  String _cachedRegulars = '';

  @override
  void initState() {
    super.initState();
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    final points = _points();
    final regulars = _regularsHeadline();
    if (!widget.disableAnimations) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() {
      _cachedPoints = points;
      _cachedRegulars = regulars;
      _loading = false;
    });
  }

  List<_PointStat> _points() {
    final relevant = widget.sessions
        .where((s) => s.eventId == widget.event.id && s.deletedAt == null)
        .toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final tail = relevant.length <= widget.windowSize
        ? relevant
        : relevant.sublist(relevant.length - widget.windowSize);
    return tail.map((s) {
      final present = s.records
          .where((r) => r.status == AttendanceStatus.present)
          .length;
      final total = s.records.length;
      return _PointStat(
        session: s,
        present: present,
        total: total,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final event = widget.event;
    final windowSize = widget.windowSize;
    final points = _cachedPoints;
    final latest = points.isNotEmpty ? points.last : null;
    final maxValue = points.fold<double>(0, (m, p) => p.rate > m ? p.rate : m);
    final priorAvg = points.length > 1
        ? points
                  .sublist(0, points.length - 1)
                  .map((p) => p.rate)
                  .reduce((a, b) => a + b) /
              (points.length - 1)
        : 0;
    final trendingDown = latest != null && latest.rate < priorAvg;
    final df = DateFormat('MMM d');

    if (_loading) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          leading: const BackButton(),
          title: ConvEyebrow(event.title),
          centerTitle: true,
          elevation: 0,
        ),
        body: _TrendSkeleton(disableAnimations: widget.disableAnimations),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: const BackButton(),
        title: ConvEyebrow(event.title),
        centerTitle: true,
        elevation: 0,
      ),
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
            if (latest == null)
              _Empty(c: c)
            else ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HeroStat(
                        label: 'Present',
                        value: '${latest.present}',
                        sub: latest.total > 0
                            ? '${(latest.rate * 100).round()}% of expected'
                            : 'No expected count',
                        color: c.present,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(width: 1, color: c.hair),
                    ),
                    Expanded(
                      child: _HeroStat(
                        label: 'Absent',
                        value: latest.absent.toString().padLeft(2, '0'),
                        sub: trendingDown
                            ? '↓ trending down'
                            : '↑ trending up',
                        color: c.absent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ConvCardSoft(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConsistentMembersPage(
                      event: widget.event,
                      sessions: widget.sessions,
                      members: widget.members,
                      families: widget.families,
                      disableAnimations: widget.disableAnimations,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConvEyebrow('Regulars · 80% in last 8'),
                          const SizedBox(height: 4),
                          Text(
                            _cachedRegulars,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.ink3),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 90,
                child: _Sparkline(
                  points: points,
                  maxValue: maxValue,
                  primary: c.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    points.length >= windowSize
                        ? '$windowSize weeks ago'
                        : df.format(points.first.session.sessionDate),
                    style: TextStyle(fontSize: 10, color: c.ink3),
                  ),
                  Text(
                    'Today',
                    style: TextStyle(fontSize: 10, color: c.ink3),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ConvEyebrow('Latest sessions'),
              const SizedBox(height: 8),
              for (final p in points.reversed.take(6)) _SessionLine(point: p),
            ],
          ],
        ),
      ),
    );
  }

  String _regularsHeadline() {
    final familyByMember = <String, String>{};
    for (final f in widget.families) {
      for (final m in f.members) {
        familyByMember[m.id] = f.displayName;
      }
    }
    final relevant = widget.sessions
        .where((s) => s.eventId == widget.event.id && s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final window = relevant.take(8).toList();
    final scores = <Member, int>{};
    for (final m in widget.members) {
      if (m.deletedAt != null) continue;
      var hits = 0;
      for (final s in window) {
        if (s.records.any(
          (r) =>
              r.memberId == m.id && r.status == AttendanceStatus.present,
        )) {
          hits++;
        }
      }
      if (hits >= 7) scores[m] = hits;
    }
    final names = scores.keys.map((m) => m.displayName.split(' ').first).toList();
    if (names.isEmpty) return 'None yet — keep going';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3}';
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConvEyebrow(label, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.displayNumber(fontSize: 76, color: color),
        ),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 12, color: c.ink3)),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.points,
    required this.maxValue,
    required this.primary,
  });
  final List<_PointStat> points;
  final double maxValue;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = points.length;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < n; i++) ...[
              Expanded(
                child: Container(
                  height: maxValue == 0
                      ? 4
                      : (points[i].rate / maxValue) * constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: primary.withValues(
                      alpha: i == n - 1 ? 1 : 0.35,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < n - 1) const SizedBox(width: 6),
            ],
          ],
        );
      },
    );
  }
}

class _SessionLine extends StatelessWidget {
  const _SessionLine({required this.point});
  final _PointStat point;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final df = DateFormat('EEE · MMM d');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              df.format(point.session.sessionDate),
              style: TextStyle(fontSize: 14, color: c.ink),
            ),
          ),
          Text(
            '${point.present}',
            style: AppTypography.displayNumber(fontSize: 20, color: c.present),
          ),
          const SizedBox(width: 8),
          Text('·', style: TextStyle(color: c.ink4)),
          const SizedBox(width: 8),
          Text(
            '${point.absent}',
            style: AppTypography.displayNumber(fontSize: 20, color: c.absent),
          ),
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
    return Padding(
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
            width: double.infinity,
            height: 100,
            borderRadius: AppRadii.compactR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 16),
          AppShimmer(
            width: double.infinity,
            height: 64,
            borderRadius: AppRadii.softR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 18),
          AppShimmer(
            width: double.infinity,
            height: 90,
            borderRadius: BorderRadius.circular(8),
            disableAnimations: disableAnimations,
          ),
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
