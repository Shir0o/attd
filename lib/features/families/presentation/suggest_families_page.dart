import 'package:flutter/material.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/member.dart';

enum FamilyConfidence { high, medium, low }

class FamilyCluster {
  FamilyCluster({
    required this.name,
    required this.members,
    required this.confidence,
    this.note,
    this.skipped = false,
    Set<String>? droppedMemberIds,
  }) : droppedMemberIds = droppedMemberIds ?? <String>{};

  String name;
  final List<Member> members;
  final FamilyConfidence confidence;
  final String? note;
  bool skipped;
  final Set<String> droppedMemberIds;

  List<Member> get activeMembers =>
      members.where((m) => !droppedMemberIds.contains(m.id)).toList();
}

class SuggestFamiliesPage extends StatefulWidget {
  const SuggestFamiliesPage({
    super.key,
    required this.repository,
    required this.ungroupedMembers,
    this.disableAnimations = false,
  });

  final AttendanceRepository repository;
  final List<Member> ungroupedMembers;
  final bool disableAnimations;

  @override
  State<SuggestFamiliesPage> createState() => _SuggestFamiliesPageState();
}

class _SuggestFamiliesPageState extends State<SuggestFamiliesPage> {
  late Future<List<FamilyCluster>> _clustersFuture;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _clustersFuture = _loadClusters();
  }

  Future<List<FamilyCluster>> _loadClusters() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return clusterByLastName(widget.ungroupedMembers);
  }

  static List<FamilyCluster> clusterByLastName(List<Member> members) {
    final groups = <String, List<Member>>{};
    for (final m in members) {
      final parts = m.displayName.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final key = parts.last.toLowerCase();
      groups.putIfAbsent(key, () => []).add(m);
    }
    final clusters = <FamilyCluster>[];
    for (final entry in groups.entries) {
      if (entry.value.length < 2) continue;
      final name = entry.value.first.displayName.split(RegExp(r'\s+')).last;
      final confidence = entry.value.length >= 3
          ? FamilyConfidence.high
          : FamilyConfidence.medium;
      clusters.add(FamilyCluster(
        name: name,
        members: entry.value,
        confidence: confidence,
        note: confidence == FamilyConfidence.medium
            ? 'Only 2 — could be coincidence'
            : null,
      ));
    }
    clusters.sort((a, b) => b.members.length.compareTo(a.members.length));
    return clusters;
  }

  Future<void> _create(List<FamilyCluster> clusters) async {
    final active = clusters
        .where((c) => !c.skipped && c.activeMembers.isNotEmpty)
        .toList();
    if (active.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _creating = true);
    try {
      for (final cluster in active) {
        final family = await widget.repository.addFamily(cluster.name);
        for (final member in cluster.activeMembers) {
          try {
            await widget.repository.moveMemberToFamily(member.id, family.id);
          } catch (_) {
            // Repository may not support move; skip silently.
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  int _solo(List<FamilyCluster> clusters) {
    final clustered = <String>{};
    for (final c in clusters) {
      if (c.skipped) continue;
      for (final m in c.activeMembers) {
        clustered.add(m.id);
      }
    }
    return widget.ungroupedMembers.length - clustered.length;
  }

  int _grouped(List<FamilyCluster> clusters) {
    var count = 0;
    for (final c in clusters) {
      if (c.skipped) continue;
      count += c.activeMembers.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.ink),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Suggested Families',
          style: AppTypography.eyebrow(color: c.ink3),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<FamilyCluster>>(
        future: _clustersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton(context);
          }
          final clusters = snapshot.data ?? const <FamilyCluster>[];
          if (clusters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No obvious family clusters in your roster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.ink2),
                ),
              ),
            );
          }
          return _buildContent(context, clusters);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<FamilyCluster> clusters) {
    final c = context.conv;
    final grouped = _grouped(clusters);
    final total = widget.ungroupedMembers.length;
    final activeClusters =
        clusters.where((cl) => !cl.skipped && cl.activeMembers.isNotEmpty).length;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GROUP BY LAST NAME',
                        style: AppTypography.eyebrow(color: c.primary),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'We spotted '),
                            TextSpan(
                              text: '$activeClusters families',
                              style: TextStyle(color: c.primary),
                            ),
                            const TextSpan(text: ' in your roster.'),
                          ],
                          style: AppTypography.fraunces(
                            fontSize: 30,
                            fontWeight: FontWeight.w400,
                            color: c.ink,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap a member to remove them from a group. Skip any cluster — nothing is created until you tap Create.',
                        style: TextStyle(fontSize: 14, color: c.ink2),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: c.cardSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: FractionallySizedBox(
                                widthFactor: total == 0 ? 0 : grouped / total,
                                alignment: Alignment.centerLeft,
                                child: Container(color: c.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$grouped / $total grouped',
                            style: AppTypography.eyebrow(color: c.ink3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                for (final cluster in clusters)
                  _SuggestCard(
                    cluster: cluster,
                    onChanged: () => setLocal(() {}),
                  ),
                if (_solo(clusters) > 0) _SoloRow(count: _solo(clusters)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: 0), c.bg],
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _creating
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text(
                        'Skip all',
                        style: TextStyle(color: c.ink3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _creating || activeClusters == 0
                            ? null
                            : () => _create(clusters),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Create $activeClusters ${activeClusters == 1 ? 'family' : 'families'}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
      children: [
        AppShimmer(
          width: double.infinity,
          height: 120,
          borderRadius: BorderRadius.circular(16),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          AppShimmer(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(22),
            disableAnimations: widget.disableAnimations,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SuggestCard extends StatelessWidget {
  const _SuggestCard({required this.cluster, required this.onChanged});

  final FamilyCluster cluster;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final tone = switch (cluster.confidence) {
      FamilyConfidence.high => (c.present, 'High match'),
      FamilyConfidence.medium => (c.clayDeep, 'Review'),
      FamilyConfidence.low => (c.ink3, 'Low confidence'),
    };
    final activeCount = cluster.activeMembers.length;
    return Opacity(
      opacity: cluster.skipped ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ConvCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        c.primary.withValues(alpha: 0.12),
                        c.card,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.family_restroom,
                        color: c.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cluster.name} Family',
                          style: AppTypography.fraunces(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$activeCount ${activeCount == 1 ? 'member' : 'members'}',
                          style: TextStyle(fontSize: 12, color: c.ink3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: tone.$1,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                cluster.note != null
                                    ? '${tone.$2} · ${cluster.note}'
                                    : tone.$2,
                                style: AppTypography.eyebrow(color: c.ink3),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in cluster.members)
                    _MemberPill(
                      member: m,
                      dropped: cluster.droppedMemberIds.contains(m.id),
                      onTap: () {
                        if (cluster.droppedMemberIds.contains(m.id)) {
                          cluster.droppedMemberIds.remove(m.id);
                        } else {
                          cluster.droppedMemberIds.add(m.id);
                        }
                        onChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: c.hair,
                margin: const EdgeInsets.only(bottom: 12),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      cluster.skipped = !cluster.skipped;
                      onChanged();
                    },
                    child: Text(
                      cluster.skipped ? 'Unskip' : 'Skip',
                      style: TextStyle(color: c.ink3, fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.check_circle_outline,
                      color: c.primary, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberPill extends StatelessWidget {
  const _MemberPill({
    required this.member,
    required this.dropped,
    required this.onTap,
  });

  final Member member;
  final bool dropped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final letter = member.displayName.isEmpty
        ? '?'
        : member.displayName.characters.first.toUpperCase();
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: dropped ? Colors.transparent : c.cardSoft,
          borderRadius: BorderRadius.circular(999),
          border: dropped
              ? Border.all(color: c.hair, style: BorderStyle.solid, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  c.primary.withValues(alpha: 0.16),
                  c.card,
                ),
                shape: BoxShape.circle,
              ),
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                  decoration:
                      dropped ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              member.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: dropped ? c.ink3 : c.ink2,
                decoration:
                    dropped ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoloRow extends StatelessWidget {
  const _SoloRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.hair, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.cardSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_outline, size: 18, color: c.ink3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count stay solo',
                  style: TextStyle(
                    color: c.ink2,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Members without an obvious shared last name',
                  style: TextStyle(fontSize: 12, color: c.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
