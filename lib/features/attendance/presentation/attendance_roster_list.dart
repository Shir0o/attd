import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../domain/active_roster_index.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/session_roster_utils.dart';
import '../../../data/session.dart';

typedef MemberToggle = Future<void> Function(Member member, bool isPresent);

/// The roster list on the session summary page: members grouped by status
/// (present, then absent), with a name search filter, tap-to-flip, and a
/// per-row menu for editing or removing a person.
class AttendanceRosterList extends StatefulWidget {
  const AttendanceRosterList({
    super.key,
    required this.session,
    required this.families,
    required this.onToggle,
    this.onEdit,
    this.onRemove,
    this.showSearch = true,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Family> families;
  final MemberToggle onToggle;

  final void Function(Member member)? onEdit;
  final void Function(Member member)? onRemove;
  final bool showSearch;

  /// When true, skips the 800ms skeleton frame and disables shimmer animation.
  /// Set by widget tests to keep `pumpAndSettle` from hanging on the
  /// indefinitely-repeating shimmer controller.
  final bool disableAnimations;

  @override
  State<AttendanceRosterList> createState() => _AttendanceRosterListState();
}

class _AttendanceRosterListState extends State<AttendanceRosterList> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.disableAnimations) {
      _isLoading = false;
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  late ActiveRosterIndex _rosterIndex = _buildIndex();

  ActiveRosterIndex _buildIndex() {
    final allMembers =
        widget.families.expand((f) => f.members).toList(growable: false);
    return ActiveRosterIndex(members: allMembers);
  }

  @override
  void didUpdateWidget(AttendanceRosterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.families != oldWidget.families) {
      _rosterIndex = _buildIndex();
    }
  }

  SessionRoster _buildRoster() {
    final allMembers =
        widget.families.expand((f) => f.members).toList(growable: false);
    return SessionRoster(widget.session, allMembers);
  }

  bool _matchesQuery(String valueLower) =>
      _rosterIndex.matchesLowercased(valueLower, _query);

  @override
  Widget build(BuildContext context) {
    return SkeletonSwitcher(
      loading: _isLoading,
      disableAnimations: widget.disableAnimations,
      skeleton: _buildSkeleton(context.conv),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final c = context.conv;
    final roster = _buildRoster();

    final familyMemberIds =
        widget.families.expand((f) => f.members.map((m) => m.id)).toSet();
    final visitors = <Member>[];
    for (final entry in roster.displayMembersMap.entries) {
      if (!familyMemberIds.contains(entry.key)) {
        visitors.add(entry.value);
      }
    }
    visitors.sort((a, b) => a.displayName.compareTo(b.displayName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showSearch) ...[
                ConvSearchField(
                  fieldKey: const Key('rosterSearchField'),
                  controller: _searchController,
                  hintText: 'Search by name',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _buildStatusList(roster, visitors, c),
        ),
      ],
    );
  }

  Widget _buildSkeleton(ConvocationColors c) {
    final disable = widget.disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showSearch) ...[
            AppShimmer(
              width: double.infinity,
              height: 48,
              borderRadius: AppRadii.compactR,
              disableAnimations: disable,
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => AppShimmer(
                width: double.infinity,
                height: 56,
                borderRadius: AppRadii.compactR,
                disableAnimations: disable,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusList(
    SessionRoster roster,
    List<Member> visitors,
    ConvocationColors c,
  ) {
    final allDisplayed = <Member>[];
    final seen = <String>{};
    for (final family in widget.families) {
      for (final m in family.members) {
        final displayed = roster.displayMembersMap[m.id];
        if (displayed == null) continue;
        // A member can belong to more than one family (e.g. a real family and
        // an auto-singleton); render each member only once.
        if (!seen.add(displayed.id)) continue;
        allDisplayed.add(displayed);
      }
    }
    allDisplayed.addAll(visitors);
    allDisplayed.sort((a, b) => a.displayName.compareTo(b.displayName));

    final filtered = allDisplayed
        .where((m) => _matchesQuery(m.displayNameLowercase))
        .toList();
    final present = filtered
        .where((m) => roster.getStatus(m) == AttendanceStatus.present)
        .toList();
    final absent = filtered
        .where((m) => roster.getStatus(m) == AttendanceStatus.absent)
        .toList();

    final children = <Widget>[];
    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: ConvSectionLabel(
          label: 'Marked Present',
          tone: ConvTone.present,
        ),
      ),
    );
    for (final m in present) {
      children.add(
        _MemberRow(
          key: ValueKey('present_row_${m.id}'),
          member: m,
          isPresent: true,
          onToggle: (val) => widget.onToggle(m, val),
          onEdit: widget.onEdit,
          onRemove: widget.onRemove,
        ),
      );
    }
    children.add(
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: ConvSectionLabel(
          label: 'Marked Absent',
          tone: ConvTone.absent,
        ),
      ),
    );
    for (final m in absent) {
      children.add(
        _MemberRow(
          key: ValueKey('absent_row_${m.id}'),
          member: m,
          isPresent: false,
          onToggle: (val) => widget.onToggle(m, val),
          onEdit: widget.onEdit,
          onRemove: widget.onRemove,
        ),
      );
    }

    if (present.isEmpty && absent.isEmpty) {
      return _emptyState(c);
    }

    return ListView.builder(
      key: const PageStorageKey('rosterStatusList'),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
    );
  }

  Widget _emptyState(ConvocationColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _query.isEmpty ? 'No members to show.' : 'No matches for "$_query".',
          style: AppTypography.geist(fontSize: 14, color: c.ink2),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.isPresent,
    required this.onToggle,
    this.onEdit,
    this.onRemove,
  });

  final Member member;
  final bool isPresent;
  final ValueChanged<bool> onToggle;
  final void Function(Member)? onEdit;
  final void Function(Member)? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final tone = isPresent ? ConvTone.present : ConvTone.absent;
    final bg = isPresent
        ? Color.alphaBlend(c.present.withValues(alpha: 0.06), c.card)
        : c.card;

    final tile = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.compactR,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ConvAvatar(
            letter: member.displayName.isNotEmpty
                ? member.displayName[0].toUpperCase()
                : '?',
            tone: tone,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.displayName,
                  style: AppTypography.geist(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.isVisitor
                      ? 'Visitor'
                      : isPresent
                          ? 'Marked present'
                          : 'Marked absent',
                  style: AppTypography.geist(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isPresent
                        ? c.present
                        : (member.isVisitor ? c.ink3 : c.absent),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConvToggle(
            key: ValueKey('memberToggle_${member.id}_${member.displayName}'),
            value: isPresent,
            onChanged: onToggle,
          ),
          if (onEdit != null || onRemove != null)
            _MoreActionsButton(
              member: member,
              onEdit: onEdit,
              onRemove: onRemove,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: tile,
    );
  }
}

enum _RowAction { edit, remove }

/// The visible per-row "more" control: a 48dp target that opens a small menu
/// with Edit name and Remove from session (the destructive one in danger ink).
class _MoreActionsButton extends StatelessWidget {
  const _MoreActionsButton({
    required this.member,
    this.onEdit,
    this.onRemove,
  });

  final Member member;
  final void Function(Member)? onEdit;
  final void Function(Member)? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final label = 'More actions for ${member.displayName}';
    return PopupMenuButton<_RowAction>(
      key: ValueKey('memberMore_${member.id}_${member.displayName}'),
      tooltip: label,
      icon: Icon(Icons.more_vert, color: c.ink2),
      iconSize: 24,
      padding: const EdgeInsets.all(12),
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.compactR),
      onSelected: (action) {
        switch (action) {
          case _RowAction.edit:
            onEdit?.call(member);
          case _RowAction.remove:
            onRemove?.call(member);
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem(
            value: _RowAction.edit,
            child: Text(
              'Edit name',
              style: AppTypography.geist(fontSize: 15, color: c.ink),
            ),
          ),
        if (onRemove != null)
          PopupMenuItem(
            value: _RowAction.remove,
            child: Text(
              'Remove from session',
              style: AppTypography.geist(fontSize: 15, color: c.danger),
            ),
          ),
      ],
    );
  }
}
