import 'package:flutter/material.dart';

import '../../../core/design/app_theme.dart';
import '../../../data/session.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/session_roster_utils.dart';

enum RosterGrouping { byFamily, byStatus }

typedef MemberToggle = Future<void> Function(Member member, bool isPresent);
typedef FamilyBulkToggle = Future<void> Function(Family family, bool isPresent);

/// A reusable roster list used both for in-session attendance entry and for
/// post-session review on the summary page. Supports family grouping with
/// per-family bulk actions, status grouping, and a name search filter.
class AttendanceRosterList extends StatefulWidget {
  const AttendanceRosterList({
    super.key,
    required this.session,
    required this.families,
    required this.onToggle,
    this.onFamilyToggle,
    this.onEdit,
    this.onRemove,
    this.initialGrouping = RosterGrouping.byFamily,
    this.showGroupingToggle = true,
    this.showSearch = true,
  });

  final Session session;
  final List<Family> families;
  final MemberToggle onToggle;
  final FamilyBulkToggle? onFamilyToggle;
  final void Function(Member member)? onEdit;
  final void Function(Member member)? onRemove;
  final RosterGrouping initialGrouping;
  final bool showGroupingToggle;
  final bool showSearch;

  @override
  State<AttendanceRosterList> createState() => _AttendanceRosterListState();
}

class _AttendanceRosterListState extends State<AttendanceRosterList> {
  late RosterGrouping _grouping = widget.initialGrouping;
  final Set<String> _collapsedFamilyIds = {};
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SessionRoster _buildRoster() {
    final allMembers = widget.families
        .expand((f) => f.members)
        .toList(growable: false);
    return SessionRoster(widget.session, allMembers);
  }

  bool _matchesQuery(String value) {
    if (_query.isEmpty) return true;
    return value.toLowerCase().contains(_query);
  }

  Future<void> _setFamilyStatus(Family family, bool present) async {
    final cb = widget.onFamilyToggle;
    if (cb != null) {
      await cb(family, present);
      return;
    }
    for (final m in family.members) {
      await widget.onToggle(m, present);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roster = _buildRoster();

    final familyMemberIds = widget.families
        .expand((f) => f.members.map((m) => m.id))
        .toSet();
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
        if (widget.showSearch || widget.showGroupingToggle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showSearch)
                  TextField(
                    key: const Key('rosterSearchField'),
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search by name or family',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                if (widget.showGroupingToggle) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<RosterGrouping>(
                      key: const Key('rosterGroupingToggle'),
                      segments: const [
                        ButtonSegment(
                          value: RosterGrouping.byFamily,
                          label: Text('By family'),
                          icon: Icon(Icons.groups_outlined),
                        ),
                        ButtonSegment(
                          value: RosterGrouping.byStatus,
                          label: Text('By status'),
                          icon: Icon(Icons.checklist),
                        ),
                      ],
                      selected: {_grouping},
                      onSelectionChanged: (sel) =>
                          setState(() => _grouping = sel.first),
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: _grouping == RosterGrouping.byFamily
              ? _buildFamilyList(roster, visitors, colorScheme, theme)
              : _buildStatusList(roster, visitors, colorScheme, theme),
        ),
      ],
    );
  }

  Widget _buildFamilyList(
    SessionRoster roster,
    List<Member> visitors,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final children = <Widget>[];
    for (final family in widget.families) {
      final familyMatch = _matchesQuery(family.displayName);
      final filteredMembers = <Member>[];
      for (final m in family.members) {
        final displayed = roster.displayMembersMap[m.id];
        if (displayed == null) continue; // excluded
        if (familyMatch || _matchesQuery(displayed.displayName)) {
          filteredMembers.add(displayed);
        }
      }
      if (filteredMembers.isEmpty && !familyMatch) continue;

      final isCollapsed = _collapsedFamilyIds.contains(family.id);
      final presentCount = filteredMembers
          .where((m) => roster.getStatus(m) == AttendanceStatus.present)
          .length;

      children.add(
        _FamilyHeader(
          key: ValueKey('family_header_${family.id}'),
          family: family,
          presentCount: presentCount,
          totalCount: filteredMembers.length,
          collapsed: isCollapsed,
          onToggleCollapse: () => setState(() {
            if (isCollapsed) {
              _collapsedFamilyIds.remove(family.id);
            } else {
              _collapsedFamilyIds.add(family.id);
            }
          }),
          onAllPresent: () => _setFamilyStatus(family, true),
          onAllAbsent: () => _setFamilyStatus(family, false),
        ),
      );
      if (!isCollapsed) {
        for (final m in filteredMembers) {
          children.add(
            _MemberRow(
              key: ValueKey('member_row_${family.id}_${m.id}'),
              member: m,
              isPresent: roster.getStatus(m) == AttendanceStatus.present,
              onToggle: (val) => widget.onToggle(m, val),
              onEdit: widget.onEdit,
              onRemove: widget.onRemove,
            ),
          );
        }
      }
    }

    final visitorMatches = visitors
        .where((v) => _matchesQuery(v.displayName))
        .toList();
    if (visitorMatches.isNotEmpty) {
      children.add(
        _SectionHeader(
          title: 'Visitors / Others',
          color: colorScheme.tertiary,
        ),
      );
      for (final m in visitorMatches) {
        children.add(
          _MemberRow(
            key: ValueKey('visitor_row_${m.id}'),
            member: m,
            isPresent: roster.getStatus(m) == AttendanceStatus.present,
            onToggle: (val) => widget.onToggle(m, val),
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        );
      }
    }

    if (children.isEmpty) {
      return _emptyState(theme, colorScheme);
    }

    return ListView(
      key: const PageStorageKey('rosterFamilyList'),
      padding: const EdgeInsets.only(bottom: 80),
      children: children,
    );
  }

  Widget _buildStatusList(
    SessionRoster roster,
    List<Member> visitors,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final allDisplayed = <Member>[];
    for (final family in widget.families) {
      for (final m in family.members) {
        final displayed = roster.displayMembersMap[m.id];
        if (displayed != null) allDisplayed.add(displayed);
      }
    }
    allDisplayed.addAll(visitors);
    allDisplayed.sort((a, b) => a.displayName.compareTo(b.displayName));

    final filtered = allDisplayed
        .where((m) => _matchesQuery(m.displayName))
        .toList();
    final present = filtered
        .where((m) => roster.getStatus(m) == AttendanceStatus.present)
        .toList();
    final absent = filtered
        .where((m) => roster.getStatus(m) == AttendanceStatus.absent)
        .toList();

    final children = <Widget>[];
    children.add(
      _SectionHeader(title: 'Marked Present', color: colorScheme.primary),
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
      _SectionHeader(title: 'Marked Absent', color: colorScheme.error),
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
      return _emptyState(theme, colorScheme);
    }

    return ListView(
      key: const PageStorageKey('rosterStatusList'),
      padding: const EdgeInsets.only(bottom: 80),
      children: children,
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          _query.isEmpty
              ? 'No members to show.'
              : 'No matches for "$_query".',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({
    super.key,
    required this.family,
    required this.presentCount,
    required this.totalCount,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onAllPresent,
    required this.onAllAbsent,
  });

  final Family family;
  final int presentCount;
  final int totalCount;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onAllPresent;
  final VoidCallback onAllAbsent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: onToggleCollapse,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$presentCount of $totalCount present',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: ValueKey('familyAllPresent_${family.id}'),
              tooltip: 'Mark all present',
              icon: Icon(Icons.done_all, color: colorScheme.primary),
              onPressed: onAllPresent,
            ),
            IconButton(
              key: ValueKey('familyAllAbsent_${family.id}'),
              tooltip: 'Mark all absent',
              icon: Icon(Icons.remove_done, color: colorScheme.error),
              onPressed: onAllAbsent,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tile = Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isPresent
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.error.withValues(alpha: 0.1),
          child: Text(
            member.displayName.isNotEmpty
                ? member.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: isPresent ? colorScheme.primary : colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: member.isVisitor
            ? Text(
                'Visitor',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Transform.scale(
          scale: 0.8,
          child: Switch(
            key: ValueKey('memberToggle_${member.id}_${member.displayName}'),
            value: isPresent,
            onChanged: onToggle,
            activeColor: colorScheme.primary,
          ),
        ),
      ),
    );

    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: tile,
    );

    if (onEdit == null && onRemove == null) return inner;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: ValueKey('dismiss_${member.id}_${member.displayName}'),
        direction: onEdit != null && onRemove != null
            ? DismissDirection.horizontal
            : (onEdit != null
                ? DismissDirection.startToEnd
                : DismissDirection.endToStart),
        background: onEdit != null
            ? _swipeBackground(
                context,
                'Edit Name',
                colorScheme.secondary,
                Icons.edit_outlined,
                true,
              )
            : null,
        secondaryBackground: onRemove != null
            ? _swipeBackground(
                context,
                'Remove',
                colorScheme.error,
                Icons.remove_circle_outline,
                false,
              )
            : null,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd && onEdit != null) {
            onEdit!(member);
          } else if (direction == DismissDirection.endToStart &&
              onRemove != null) {
            onRemove!(member);
          }
          return false;
        },
        child: tile,
      ),
    );
  }

  Widget _swipeBackground(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    bool isStart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: isStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isStart
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
