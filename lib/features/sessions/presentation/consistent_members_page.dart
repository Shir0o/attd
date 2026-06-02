import 'package:flutter/material.dart';

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

/// Members who attended ≥ 80% of the last 8 sessions of an event.
///
/// Mirrors `RegularsPreview` from the design handoff (see `DESIGN_SPEC.md`).
class ConsistentMembersPage extends StatefulWidget {
  const ConsistentMembersPage({
    super.key,
    required this.event,
    required this.sessions,
    required this.members,
    this.families = const [],
    this.windowSize = 8,
    this.thresholdHits = 7,
    this.disableAnimations = false,
  });

  final Event event;
  final List<Session> sessions;
  final List<Member> members;
  final List<Family> families;
  final int windowSize;
  final int thresholdHits;
  final bool disableAnimations;

  @override
  State<ConsistentMembersPage> createState() => _ConsistentMembersPageState();
}

class _ConsistentMembersPageState extends State<ConsistentMembersPage> {
  bool _loading = true;
  List<_MemberStreak> _streaks = const [];
  int _relevantSessionCount = 0;
  int _activeMemberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    final streaks = _computeStreaks();
    final count = widget.sessions
        .where((s) => s.eventId == widget.event.id && s.deletedAt == null)
        .length;
    final activeMembers =
        widget.members.where((m) => m.deletedAt == null).length;
    if (!widget.disableAnimations) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    if (!mounted) return;
    setState(() {
      _streaks = streaks;
      _relevantSessionCount = count;
      _activeMemberCount = activeMembers;
      _loading = false;
    });
  }

  List<_MemberStreak> _computeStreaks() {
    final relevant = widget.sessions
        .where((s) => s.eventId == widget.event.id && s.deletedAt == null)
        .toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final window = relevant.take(widget.windowSize).toList();
    final familyByMember = <String, String>{};
    for (final f in widget.families) {
      for (final m in f.members) {
        familyByMember[m.id] = f.displayName;
      }
    }

    final streaks = <_MemberStreak>[];
    for (final m in widget.members) {
      if (m.deletedAt != null) continue;
      final hits = <bool>[];
      for (final s in window) {
        final present = s.records.any(
          (r) =>
              r.memberId == m.id && r.status == AttendanceStatus.present,
        );
        hits.add(present);
      }
      final hitCount = hits.where((h) => h).length;
      if (hitCount >= widget.thresholdHits) {
        streaks.add(
          _MemberStreak(
            member: m,
            family: familyByMember[m.id],
            hits: hits,
            windowSize: window.length,
          ),
        );
      }
    }
    streaks.sort((a, b) => b.hitCount.compareTo(a.hitCount));
    return streaks;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final event = widget.event;
    final streaks = _streaks;
    final relevantSessionCount = _relevantSessionCount;
    final windowSize = widget.windowSize;
    final thresholdHits = widget.thresholdHits;
    final avgPct = streaks.isEmpty
        ? 0
        : (streaks
                      .map((s) => s.hitCount / s.windowSize)
                      .reduce((a, b) => a + b) /
                  streaks.length *
                  100)
              .round();

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
        child: _loading
            ? _Skeleton(disableAnimations: widget.disableAnimations)
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  ConvEyebrow('Regulars', color: c.primary),
                  const SizedBox(height: 6),
                  Text(
                    'The reliable few',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: c.ink,
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    relevantSessionCount < windowSize
                        ? 'Members at ${(thresholdHits / windowSize * 100).round()}%+ across the last $relevantSessionCount session${relevantSessionCount == 1 ? '' : 's'} — a quiet nudge to thank your most consistent.'
                        : 'Members at ${(thresholdHits / windowSize * 100).round()}%+ across the last $windowSize sessions — a quiet nudge to thank your most consistent.',
                    style: TextStyle(fontSize: 14, color: c.ink2, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  if (streaks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: _Empty(c: c),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _CountTile(
                            label: 'Regulars',
                            value: '${streaks.length}',
                            suffix: ' / $_activeMemberCount',
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CountTile(
                            label: 'Avg attendance',
                            value: '$avgPct%',
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _HeroCard(streak: streaks[0]),
                    const SizedBox(height: 24),
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
                        ConvEyebrow('Also reliable'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (var i = 1; i < streaks.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RankedRow(rank: i + 1, streak: streaks[i]),
                      ),
                    const SizedBox(height: 14),
                    Center(
                      child: ConvEyebrow(
                        'Lives on your device · never shared',
                        color: c.ink4,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });
  final String label;
  final String value;
  final String? suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ConvCardSoft(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConvEyebrow(label),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: AppTypography.displayNumber(fontSize: 30, color: color),
              children: [
                TextSpan(text: value),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: AppTypography.displayNumber(
                      fontSize: 14,
                      color: c.ink3,
                    ),
                  ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmer(
            width: 120,
            height: 12,
            borderRadius: BorderRadius.circular(4),
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 10),
          AppShimmer(
            width: 240,
            height: 28,
            borderRadius: BorderRadius.circular(6),
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 24),
          AppShimmer(
            width: double.infinity,
            height: 120,
            borderRadius: AppRadii.tileR,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 3; i++) ...[
            AppShimmer(
              width: double.infinity,
              height: 48,
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

class _MemberStreak {
  _MemberStreak({
    required this.member,
    required this.family,
    required this.hits,
    required this.windowSize,
  });
  final Member member;
  final String? family;
  final List<bool> hits;
  final int windowSize;
  int get hitCount => hits.where((h) => h).length;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.streak});
  final _MemberStreak streak;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final initial = streak.member.displayName.isNotEmpty
        ? streak.member.displayName[0].toUpperCase()
        : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(c.primary.withValues(alpha: 0.22), c.bg),
            Color.alphaBlend(c.primary.withValues(alpha: 0.06), c.bg),
          ],
        ),
        borderRadius: AppRadii.tileR,
        border: Border.all(
          color: c.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ConvAvatar(letter: initial, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConvEyebrow('Most consistent', color: c.primary, fontSize: 10),
                    const SizedBox(height: 2),
                    Text(
                      streak.member.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: c.ink,
                        fontSize: 22,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streak.family == null ? 'Solo' : '${streak.family} family',
                      style: TextStyle(fontSize: 12, color: c.ink3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTypography.displayNumber(
                        fontSize: 40,
                        color: c.primary,
                      ),
                      children: [
                        TextSpan(text: '${streak.hitCount}'),
                        TextSpan(
                          text: '/${streak.windowSize}',
                          style: AppTypography.displayNumber(
                            fontSize: 18,
                            color: c.primary.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConvEyebrow('Sessions', fontSize: 9),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Ribbon(hits: streak.hits, color: c.primary, height: 8, gap: 5),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${streak.windowSize} weeks ago',
                style: TextStyle(fontSize: 10, color: c.ink3),
              ),
              Text('This week', style: TextStyle(fontSize: 10, color: c.ink3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.rank, required this.streak});
  final int rank;
  final _MemberStreak streak;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final initial = streak.member.displayName.isNotEmpty
        ? streak.member.displayName[0].toUpperCase()
        : '?';
    final pct = (streak.hitCount / streak.windowSize * 100).round();
    return ConvCardSoft(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: AppTypography.geistTabular(
                fontSize: 15,
                color: c.ink4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConvAvatar(letter: initial, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak.member.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                SizedBox(
                  width: 72,
                  child: _Ribbon(hits: streak.hits, color: c.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: AppTypography.displayNumber(fontSize: 18, color: c.ink),
              ),
              const SizedBox(height: 2),
              ConvEyebrow(
                '${streak.hitCount}/${streak.windowSize}',
                color: c.ink3,
                fontSize: 9,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.hits,
    required this.color,
    this.height = 5,
    this.gap = 3,
  });
  final List<bool> hits;
  final Color color;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < hits.length; i++) ...[
            Expanded(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: hits[i]
                      ? color.withValues(alpha: 0.45 + (i / hits.length) * 0.55)
                      : c.hair,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
            if (i < hits.length - 1) SizedBox(width: gap),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 64, color: c.ink4),
          const SizedBox(height: 14),
          Text(
            'No regulars yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 260,
            child: Text(
              'Once members hit 80%+ across the last 8 sessions, they’ll show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.ink2, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
