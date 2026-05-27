import 'package:flutter/material.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import 'add_family_page.dart';
import 'assign_solo_members_page.dart';
import 'family_details_page.dart';
import 'resolve_duplicates_page.dart';
import 'suggest_families_page.dart';

class FamilyListPage extends StatefulWidget {
  const FamilyListPage({
    super.key,
    required this.repository,
    this.disableAnimations = false,
  });

  final AttendanceRepository repository;
  final bool disableAnimations;

  @override
  State<FamilyListPage> createState() => _FamilyListPageState();
}

class _FamilyListPageState extends State<FamilyListPage> {
  late Future<List<Family>> _familiesFuture;
  bool _showedSkeletonOnce = false;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  void _loadFamilies() {
    setState(() {
      _familiesFuture = _fetchWithMinDelay();
    });
  }

  Future<List<Family>> _fetchWithMinDelay() async {
    final results = await Future.wait([
      widget.repository.fetchFamilies(),
      if (!_showedSkeletonOnce && !widget.disableAnimations)
        Future.delayed(const Duration(milliseconds: 800)),
    ]);
    _showedSkeletonOnce = true;
    return results.first as List<Family>;
  }

  Future<void> _addFamily() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddFamilyPage(repository: widget.repository),
      ),
    );

    if (result != null) {
      _loadFamilies();
    }
  }

  void _openFamily(Family family) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FamilyDetailsPage(
          family: family,
          repository: widget.repository,
        ),
      ),
    );
    _loadFamilies();
  }

  Future<void> _openSuggestions(List<Member> ungrouped) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SuggestFamiliesPage(
          repository: widget.repository,
          ungroupedMembers: ungrouped,
        ),
      ),
    );
    if (created == true) {
      _loadFamilies();
    }
  }

  Future<void> _openAssignSolo(List<Member> solo) async {
    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AssignSoloMembersPage(
          repository: widget.repository,
          soloMembers: solo,
        ),
      ),
    );
    if (assigned == true) {
      _loadFamilies();
    }
  }

  Future<void> _openResolveDuplicates() async {
    final resolved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ResolveDuplicatesPage(
          repository: widget.repository,
        ),
      ),
    );
    if (resolved == true) {
      _loadFamilies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text(
          'Manage Families',
          style: AppTypography.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: c.ink,
          ),
        ),
      ),
      body: FutureBuilder<List<Family>>(
        future: _familiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeleton(context);
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final families = snapshot.data ?? [];

          final ungroupedMembers = _collectUngrouped(families);
          final realFamilies =
              families.where((f) => !f.isAutoSingleton).toList();
          final memberCount = families.fold<int>(
            0,
            (sum, f) => sum + f.members.length,
          );

          final memberToFamilies = <String, List<String>>{};
          for (final f in realFamilies) {
            for (final m in f.members) {
              memberToFamilies.putIfAbsent(m.displayName, () => []).add(f.displayName);
            }
          }
          final duplicateMembers = Map.fromEntries(
            memberToFamilies.entries.where((e) => e.value.length > 1),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
            children: [
              if (duplicateMembers.isNotEmpty) ...[
                _DuplicateMembersBanner(
                  duplicateMembers: duplicateMembers,
                  onReview: _openResolveDuplicates,
                ),
                const SizedBox(height: 12),
              ],
              if (ungroupedMembers.isNotEmpty) ...[
                _SuggestionBanner(
                  count: _estimateClusters(ungroupedMembers),
                  ungroupedCount: ungroupedMembers.length,
                  totalMembers: memberCount,
                  onReview: () => _openSuggestions(ungroupedMembers),
                ),
                const SizedBox(height: 12),
                _SoloMembersBanner(
                  soloMembers: ungroupedMembers,
                  onReview: () => _openAssignSolo(ungroupedMembers),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: ConvStatChip(
                      label: 'Families',
                      value: '${realFamilies.length}',
                      tone: ConvTone.neutral,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConvStatChip(
                      label: 'Members',
                      value: '$memberCount',
                      tone: ConvTone.neutral,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConvStatChip(
                      label: 'Solo',
                      value: '${ungroupedMembers.length}',
                      tone: ConvTone.neutral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (realFamilies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No families found. Add one!',
                      style: TextStyle(color: c.ink3, fontSize: 16),
                    ),
                  ),
                )
              else
                for (final family in realFamilies) ...[
                  _FamilyCard(
                    family: family,
                    onTap: () => _openFamily(family),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
      floatingActionButton: ConvFab(
        onPressed: _addFamily,
        tooltip: 'Add Family',
      ),
    );
  }

  List<Member> _collectUngrouped(List<Family> families) {
    return [
      for (final f in families)
        if (f.isAutoSingleton || f.members.length <= 1) ...f.members,
    ];
  }

  int _estimateClusters(List<Member> members) {
    final groups = <String, int>{};
    for (final m in members) {
      final last = _lastNameOf(m.displayName);
      if (last.isEmpty) continue;
      groups.update(last, (v) => v + 1, ifAbsent: () => 1);
    }
    return groups.values.where((c) => c >= 2).length;
  }

  static String _lastNameOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: AppShimmer(
                  width: double.infinity,
                  height: 64,
                  borderRadius: BorderRadius.circular(16),
                  disableAnimations: widget.disableAnimations,
                ),
              ),
              if (i < 2) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 4; i++) ...[
          AppShimmer(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.circular(22),
            disableAnimations: widget.disableAnimations,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({
    required this.count,
    required this.ungroupedCount,
    required this.totalMembers,
    required this.onReview,
  });

  final int count;
  final int ungroupedCount;
  final int totalMembers;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.primary.withValues(alpha: 0.10), c.bg),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.family_restroom, color: c.onPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0
                      ? '$count possible families spotted'
                      : 'Group your members',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'From shared last names · $ungroupedCount of $totalMembers members',
                  style: TextStyle(fontSize: 12, color: c.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            key: const Key('review_suggestions_btn'),
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onReview,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Review',
                  style: TextStyle(
                    color: c.bg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.family, required this.onTap});

  final Family family;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final isSolo = family.isAutoSingleton;
    final count = family.members.length;
    return ConvCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      Color.alphaBlend(c.primary.withValues(alpha: 0.14), c.card),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSolo ? Icons.person_outline : Icons.family_restroom,
                  color: c.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.displayName,
                      style: AppTypography.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'member' : 'members'}',
                      style: TextStyle(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.ink3, size: 20),
            ],
          ),
          if (family.members.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in family.members) _MemberChip(member: m),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final letter = member.displayName.isEmpty
        ? '?'
        : member.displayName.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConvAvatar(letter: letter, size: 28),
          const SizedBox(width: 8),
          Text(
            member.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoloMembersBanner extends StatelessWidget {
  const _SoloMembersBanner({
    required this.soloMembers,
    required this.onReview,
  });

  final List<Member> soloMembers;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.primary.withValues(alpha: 0.10), c.bg),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_outline, color: c.onPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign solo members',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${soloMembers.length} members are not assigned to a family',
                  style: TextStyle(fontSize: 12, color: c.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            key: const Key('review_solo_members_btn'),
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onReview,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Review',
                  style: TextStyle(
                    color: c.bg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateMembersBanner extends StatelessWidget {
  const _DuplicateMembersBanner({
    required this.duplicateMembers,
    required this.onReview,
  });

  final Map<String, List<String>> duplicateMembers;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final count = duplicateMembers.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.absent.withValues(alpha: 0.10), c.bg),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.absent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate members detected',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'member is' : 'members are'} assigned to multiple families',
                  style: TextStyle(fontSize: 12, color: c.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            key: const Key('review_duplicate_members_btn'),
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onReview,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Review',
                  style: TextStyle(
                    color: c.bg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

