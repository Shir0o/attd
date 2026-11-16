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
import '../models/roster_grouping.dart';
import '../utils/session_roster_utils.dart';
import '../../../data/session.dart';
import 'mark_everyone_sheet.dart';

// Re-exported so existing importers (deck page, summary) keep resolving
// RosterGrouping through this file.
export '../models/roster_grouping.dart';

typedef MemberToggle = Future<void> Function(Member member, bool isPresent);
typedef FamilyBulkToggle = Future<void> Function(Family family, bool isPresent);
typedef MarkAllToggle = Future<void> Function(BulkMarkChoice choice);
typedef MemberLateToggle = Future<void> Function(Member member);

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
    this.onToggleLate,
    this.onMarkAll,
    this.onEdit,
    this.onRemove,
    this.initialGrouping = RosterGrouping.byFamily,
    this.showGroupingToggle = true,
    this.showSearch = true,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Family> families;
  final MemberToggle onToggle;
  final FamilyBulkToggle? onFamilyToggle;

  /// Optional callback for the roster-wide bulk "Mark all present/absent"
  /// action. When non-null, an "All" pill appears next to the grouping
  /// toggle. The parent is responsible for snapshotting + showing an undo
  /// snackbar — the widget only renders the UI and the modal sheet.
  final MarkAllToggle? onMarkAll;

  /// Optional present-but-late toggle for post-session review. When null the
  /// late affordance does not render at all — only the Session Summary passes
  /// it, so the in-session deck and fast-marking surfaces stay unchanged.
  final MemberLateToggle? onToggleLate;
  final void Function(Member member)? onEdit;
  final void Function(Member member)? onRemove;
  final RosterGrouping initialGrouping;
  final bool showGroupingToggle;
  final bool showSearch;

  /// When true, skips the 800ms skeleton frame and disables shimmer animation.
  /// Set by widget tests to keep `pumpAndSettle` from hanging on the
  /// indefinitely-repeating shimmer controller.
  final bool disableAnimations;

  @override
  State<AttendanceRosterList> createState() => _AttendanceRosterListState();
}

class _AttendanceRosterListState extends State<AttendanceRosterList> {
  late RosterGrouping _grouping = widget.initialGrouping;
  final Set<String> _collapsedFamilyIds = {};
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
    return ActiveRosterIndex(members: allMembers, families: widget.families);
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

  Future<void> _openMarkEveryone(
    BuildContext context,
    SessionRoster roster,
  ) async {
    final cb = widget.onMarkAll;
    if (cb == null) return;
    final choice = await MarkEveryoneSheet.show(
      context,
      memberCount: roster.displayMembersMap.length,
    );
    if (choice == null) return;
    await cb(choice);
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
                  hintText: 'Search by name or family',
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ],
              // Live grouping toggle + bulk sheet (e.g. session summary).
              // A Wrap, so at large text All drops below the toggle instead
              // of overflowing; the toggle scales down rather than overflow
              // on its own, as the marking-mode toggle does.
              if (widget.showGroupingToggle || widget.onMarkAll != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  // All alone still sits at the end, as it did after a Spacer.
                  alignment: widget.showGroupingToggle
                      ? WrapAlignment.spaceBetween
                      : WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.showGroupingToggle)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConvSegmented(
                          key: const Key('rosterGroupingToggle'),
                          options: const [
                            ConvSegmentOption(
                              label: 'By family',
                              icon: Icons.groups_outlined,
                            ),
                            ConvSegmentOption(
                              label: 'By status',
                              icon: Icons.checklist,
                            ),
                          ],
                          selectedIndex:
                              _grouping == RosterGrouping.byFamily ? 0 : 1,
                          onChanged: (i) => setState(() {
                            _grouping = i == 0
                                ? RosterGrouping.byFamily
                                : RosterGrouping.byStatus;
                          }),
                          disableAnimations: widget.disableAnimations,
                        ),
                      ),
                    if (widget.onMarkAll != null)
                      ConvPill(
                        key: const Key('rosterMarkAllMenu'),
                        label: 'All',
                        leading: const Icon(Icons.check_rounded),
                        onTap: () => _openMarkEveryone(context, roster),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _grouping == RosterGrouping.byFamily
              ? _buildFamilyList(roster, visitors, c)
              : _buildStatusList(roster, visitors, c),
        ),
      ],
    );
  }

  /// The late flag of [member]'s record in the current session. A member with
  /// no record reads as not-late.
  bool _isLate(SessionRoster roster, Member m) {
    final record = roster.recordByMemberId[m.id] ??
        roster.recordByVisitorName[m.displayName];
    return record?.isLate ?? false;
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
          if (widget.showGroupingToggle) ...[
            AppShimmer(
              width: double.infinity,
              height: 40,
              borderRadius: BorderRadius.circular(999),
              disableAnimations: disable,
            ),
            const SizedBox(height: 16),
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

  Widget _buildFamilyList(
    SessionRoster roster,
    List<Member> visitors,
    ConvocationColors c,
  ) {
    final children = <Widget>[];
    final singletonMembers = <Member>[];
    // A member can belong to more than one family (e.g. a real family and an
    // auto-singleton); render each member only once, under the first family.
    final seen = <String>{};
    for (final family in widget.families) {
      // Auto-created singleton families (member added without a real family)
      // render as flat rows under a single "Members" section — the family
      // header would otherwise look like a last name.
      if (family.isAutoSingleton && family.members.length == 1) {
        final m = family.members.first;
        final displayed = roster.displayMembersMap[m.id];
        if (displayed == null) continue;
        if (!seen.add(displayed.id)) continue;
        if (_matchesQuery(displayed.displayNameLowercase)) {
          singletonMembers.add(displayed);
        }
        continue;
      }
      final familyMatch = _matchesQuery(family.displayNameLowercase);
      final filteredMembers = <Member>[];
      for (final m in family.members) {
        final displayed = roster.displayMembersMap[m.id];
        if (displayed == null) continue; // excluded
        if (!seen.add(displayed.id)) {
          continue; // already shown under another family
        }
        if (familyMatch || _matchesQuery(displayed.displayNameLowercase)) {
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
              isLate: _isLate(roster, m),
              onToggle: (val) => widget.onToggle(m, val),
              onToggleLate: widget.onToggleLate,
              onEdit: widget.onEdit,
              onRemove: widget.onRemove,
            ),
          );
        }
      }
    }

    if (singletonMembers.isNotEmpty) {
      singletonMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ConvSectionLabel(label: 'Members'),
        ),
      );
      for (final m in singletonMembers) {
        children.add(
          _MemberRow(
            key: ValueKey('singleton_row_${m.id}'),
            member: m,
            isPresent: roster.getStatus(m) == AttendanceStatus.present,
            isLate: _isLate(roster, m),
            onToggle: (val) => widget.onToggle(m, val),
            onToggleLate: widget.onToggleLate,
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        );
      }
    }

    final visitorMatches =
        visitors.where((v) => _matchesQuery(v.displayNameLowercase)).toList();
    if (visitorMatches.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: ConvSectionLabel(
            label: 'Visitors / Others',
            tone: ConvTone.absent,
          ),
        ),
      );
      for (final m in visitorMatches) {
        children.add(
          _MemberRow(
            key: ValueKey('visitor_row_${m.id}'),
            member: m,
            isPresent: roster.getStatus(m) == AttendanceStatus.present,
            isLate: _isLate(roster, m),
            onToggle: (val) => widget.onToggle(m, val),
            onToggleLate: widget.onToggleLate,
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        );
      }
    }

    if (children.isEmpty) {
      return _emptyState(c);
    }

    return ListView.builder(
      key: const PageStorageKey('rosterFamilyList'),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
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

    final filtered =
        allDisplayed.where((m) => _matchesQuery(m.displayNameLowercase)).toList();
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
          isLate: _isLate(roster, m),
          onToggle: (val) => widget.onToggle(m, val),
          onToggleLate: widget.onToggleLate,
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
          isLate: _isLate(roster, m),
          onToggle: (val) => widget.onToggle(m, val),
          onToggleLate: widget.onToggleLate,
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
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.cardSoft,
          borderRadius: AppRadii.compactR,
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
                  color: c.ink2,
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
                      style: AppTypography.geist(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$presentCount of $totalCount present',
                      style: AppTypography.geist(
                        fontSize: 12,
                        color: c.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ConvIconButton(
              key: ValueKey('familyAllPresent_${family.id}'),
              icon: Icons.done_all_rounded,
              color: c.present,
              onPressed: onAllPresent,
            ),
            ConvIconButton(
              key: ValueKey('familyAllAbsent_${family.id}'),
              icon: Icons.remove_done_rounded,
              color: c.absent,
              onPressed: onAllAbsent,
            ),
          ],
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
    this.isLate = false,
    this.onToggleLate,
    this.onEdit,
    this.onRemove,
  });

  final Member member;
  final bool isPresent;
  final ValueChanged<bool> onToggle;

  /// Present-but-late state for this row. Only rendered when [onToggleLate]
  /// is supplied; a late attendee stays a present attendee everywhere.
  final bool isLate;

  /// Null on the in-session deck and fast-marking surfaces — the affordance
  /// (and its spacer slot) only exists on the Session Summary roster.
  final MemberLateToggle? onToggleLate;
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
                Text.rich(
                  member.isVisitor
                      ? const TextSpan(text: 'Visitor')
                      : !isPresent
                          ? const TextSpan(text: 'Marked absent')
                          : TextSpan(
                              text: 'Marked present',
                              children: [
                                if (isLate)
                                  TextSpan(
                                    text: ' · late',
                                    style: TextStyle(
                                      color: c.clayDeep,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
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
          // Late affordance: a 32px clock dot inside a 44px tap target,
          // between the name column and the 56×32 ConvToggle. Absent rows
          // keep an empty 44px slot so the toggles stay in a column. Only
          // rendered when onToggleLate is supplied (Session Summary only).
          if (onToggleLate != null) ...[
            if (isPresent)
              GestureDetector(
                key: ValueKey('memberLate_${member.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggleLate!(member),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLate
                            ? Color.alphaBlend(
                                c.clayDeep.withValues(alpha: 0.18),
                                c.card,
                              )
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.schedule_outlined,
                        size: 18,
                        color: isLate ? c.clayDeep : c.ink4,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
          if (onToggleLate != null) const SizedBox(width: 8),
          ConvToggle(
            key: ValueKey('memberToggle_${member.id}_${member.displayName}'),
            value: isPresent,
            onChanged: onToggle,
          ),
        ],
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
                c.clayDeep,
                Icons.edit_outlined,
                true,
              )
            : null,
        secondaryBackground: onRemove != null
            ? _swipeBackground(
                context,
                'Remove',
                c.absent,
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
        borderRadius: AppRadii.compactR,
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
