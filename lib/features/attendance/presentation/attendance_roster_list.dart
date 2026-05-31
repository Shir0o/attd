import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
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
typedef MarkAllToggle = Future<void> Function(bool isPresent);

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
    this.onMarkAll,
    this.onEdit,
    this.onRemove,
    this.initialGrouping = RosterGrouping.byFamily,
    this.showGroupingToggle = true,
    this.showGroupingPreset = false,
    this.showSearch = true,
    this.showStats = true,
    this.disableAnimations = false,
    this.confirmMode = false,
    this.smartStart = false,
    this.baselineStatus,
    this.onConfirm,
    this.onReset,
    this.onAddGuest,
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
  final void Function(Member member)? onEdit;
  final void Function(Member member)? onRemove;
  final RosterGrouping initialGrouping;
  final bool showGroupingToggle;

  /// When true, the live By-family/By-status toggle is replaced by a read-only
  /// "Grouped by …" indicator — grouping is fixed to [initialGrouping] (the
  /// event's preset). Used by the in-session marking list.
  final bool showGroupingPreset;
  final bool showSearch;

  /// Show the Present/Absent/Total stat strip above the search input. Callers
  /// that already render their own summary stats (e.g. session summary page)
  /// pass `false` to avoid duplication.
  final bool showStats;

  /// When true, skips the 800ms skeleton frame and disables shimmer animation.
  /// Set by widget tests to keep `pumpAndSettle` from hanging on the
  /// indefinitely-repeating shimmer controller.
  final bool disableAnimations;

  /// Confirm mode — the list opened from a bulk default (all-present / smart).
  /// Shows a confirm banner, highlights rows whose status differs from the
  /// preseed ([baselineStatus]), and pins a sticky "Confirm N present" CTA.
  final bool confirmMode;

  /// In confirm mode, whether the bulk default was the smart guess (vs. plain
  /// all-present). Only affects the banner copy.
  final bool smartStart;

  /// The status each member arrived with (keyed by member id, or display name
  /// for id-less entries). Drives the confirm-mode "changed" highlight.
  final Map<String, AttendanceStatus>? baselineStatus;

  /// Tapped by the sticky confirm CTA (confirm mode only).
  final VoidCallback? onConfirm;

  /// Confirm mode: restores every member to their preseed status. When set, a
  /// subtle "Reset" action appears (in place of the bulk "All" pill) once the
  /// user has changed something.
  final VoidCallback? onReset;

  /// When non-null, a trailing dashed "Add guest" row is appended to the
  /// roster for adding a walk-in not on the list.
  final VoidCallback? onAddGuest;

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

  Future<void> _openMarkEveryone(
    BuildContext context,
    SessionRoster roster,
  ) async {
    final cb = widget.onMarkAll;
    if (cb == null) return;
    final result = await MarkEveryoneSheet.show(
      context,
      memberCount: roster.displayMembersMap.length,
    );
    if (result == null) return;
    await cb(result);
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
    final c = context.conv;
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

    if (_isLoading) {
      return _buildSkeleton(c);
    }

    // Stat counts: every displayed person (family members + visitors).
    final displayedMembers = roster.displayMembersMap.values.toList();
    var presentCount = 0;
    var absentCount = 0;
    for (final m in displayedMembers) {
      final s = roster.getStatus(m);
      if (s == AttendanceStatus.present) presentCount++;
      if (s == AttendanceStatus.absent) absentCount++;
    }
    final totalCount = displayedMembers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.confirmMode) ...[
                _ConfirmBanner(smartStart: widget.smartStart),
                const SizedBox(height: 12),
              ],
              if (widget.showStats)
                Row(
                  children: [
                    Expanded(
                      child: ConvStatChip(
                        label: 'Present',
                        value: '$presentCount',
                        tone: ConvTone.present,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ConvStatChip(
                        label: 'Absent',
                        value: '$absentCount',
                        tone: ConvTone.absent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ConvStatChip(
                        label: 'Total',
                        value: '$totalCount',
                        tone: ConvTone.neutral,
                      ),
                    ),
                  ],
                ),
              if (widget.showSearch) ...[
                if (widget.showStats) const SizedBox(height: 12),
                _SearchField(
                  controller: _searchController,
                  query: _query,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
              ],
              // Read-only grouping indicator (preset) + context bulk action.
              if (widget.showGroupingPreset) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _GroupingIndicator(grouping: _grouping),
                    const Spacer(),
                    if (widget.confirmMode)
                      if (widget.onReset != null && _changedCount(roster) > 0)
                        TextButton(
                          key: const Key('rosterResetButton'),
                          onPressed: widget.onReset,
                          style: TextButton.styleFrom(
                            foregroundColor: c.ink3,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Reset'),
                        )
                      else
                        const SizedBox.shrink()
                    else if (widget.onMarkAll != null)
                      ConvPill(
                        key: const Key('rosterMarkAllPresent'),
                        label: 'All present',
                        leading: const Icon(Icons.done_all_rounded),
                        onTap: () => widget.onMarkAll!(true),
                      ),
                  ],
                ),
              ]
              // Live grouping toggle + bulk sheet (e.g. session summary).
              else if (widget.showGroupingToggle || widget.onMarkAll != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.showGroupingToggle)
                      ConvSegmented(
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
                        selectedIndex: _grouping == RosterGrouping.byFamily
                            ? 0
                            : 1,
                        onChanged: (i) => setState(() {
                          _grouping = i == 0
                              ? RosterGrouping.byFamily
                              : RosterGrouping.byStatus;
                        }),
                      ),
                    const Spacer(),
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
        if (widget.confirmMode && widget.onConfirm != null)
          _buildConfirmCta(c, presentCount, roster),
      ],
    );
  }

  Widget _buildConfirmCta(
    ConvocationColors c,
    int presentCount,
    SessionRoster roster,
  ) {
    final changed = _changedCount(roster);
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.hair)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('rosterConfirmButton'),
            onPressed: widget.onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.compactR),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(
              changed > 0
                  ? 'Confirm $presentCount present · $changed changed'
                  : 'Confirm $presentCount present',
              style: AppTypography.geist(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// True when [m]'s current status differs from the preseed baseline.
  bool _isChanged(SessionRoster roster, Member m) {
    final base = widget.baselineStatus;
    if (base == null) return false;
    final b = base[m.id] ?? base[m.displayName];
    if (b == null) return false;
    return roster.getStatus(m) != b;
  }

  int _changedCount(SessionRoster roster) {
    if (widget.baselineStatus == null) return 0;
    var n = 0;
    for (final m in roster.displayMembersMap.values) {
      if (_isChanged(roster, m)) n++;
    }
    return n;
  }

  Widget _buildSkeleton(ConvocationColors c) {
    final disable = widget.disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showStats) ...[
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: AppShimmer(
                      width: double.infinity,
                      height: 64,
                      borderRadius: AppRadii.compactR,
                      disableAnimations: disable,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
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
    for (final family in widget.families) {
      // Auto-created singleton families (member added without a real family)
      // render as flat rows under a single "Members" section — the family
      // header would otherwise look like a last name.
      if (family.isAutoSingleton && family.members.length == 1) {
        final m = family.members.first;
        final displayed = roster.displayMembersMap[m.id];
        if (displayed == null) continue;
        if (_matchesQuery(displayed.displayName)) {
          singletonMembers.add(displayed);
        }
        continue;
      }
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
              changed: _isChanged(roster, m),
              isPresent: roster.getStatus(m) == AttendanceStatus.present,
              onToggle: (val) => widget.onToggle(m, val),
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
            changed: _isChanged(roster, m),
            isPresent: roster.getStatus(m) == AttendanceStatus.present,
            onToggle: (val) => widget.onToggle(m, val),
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        );
      }
    }

    final visitorMatches = visitors
        .where((v) => _matchesQuery(v.displayName))
        .toList();
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
            changed: _isChanged(roster, m),
            isPresent: roster.getStatus(m) == AttendanceStatus.present,
            onToggle: (val) => widget.onToggle(m, val),
            onEdit: widget.onEdit,
            onRemove: widget.onRemove,
          ),
        );
      }
    }

    if (children.isEmpty) {
      return _emptyState(c);
    }

    if (widget.onAddGuest != null) {
      children.add(_AddGuestRow(onTap: widget.onAddGuest!));
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
          changed: _isChanged(roster, m),
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
          changed: _isChanged(roster, m),
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

    if (widget.onAddGuest != null) {
      children.add(_AddGuestRow(onTap: widget.onAddGuest!));
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
          _query.isEmpty
              ? 'No members to show.'
              : 'No matches for "$_query".',
          style: AppTypography.geist(fontSize: 14, color: c.ink2),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: AppRadii.compactR,
      ),
      child: TextField(
        key: const Key('rosterSearchField'),
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.geist(fontSize: 14, color: c.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Icon(Icons.search_rounded, color: c.ink3, size: 20),
          hintText: 'Search by name or family',
          hintStyle: AppTypography.geist(fontSize: 14, color: c.ink3),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.clear_rounded, color: c.ink3, size: 18),
                  onPressed: onClear,
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
    this.onEdit,
    this.onRemove,
    this.changed = false,
  });

  final Member member;
  final bool isPresent;
  final ValueChanged<bool> onToggle;
  final void Function(Member)? onEdit;
  final void Function(Member)? onRemove;

  /// Confirm mode: this member's status differs from the preseed — the row gets
  /// a primary-tinted background and a "Changed" subtitle.
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final tone = isPresent ? ConvTone.present : ConvTone.absent;
    final bg = changed
        ? Color.alphaBlend(c.primary.withValues(alpha: 0.09), c.card)
        : isPresent
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
                  changed
                      ? 'Changed'
                      : member.isVisitor
                          ? 'Visitor'
                          : (isPresent ? 'Marked present' : 'Marked absent'),
                  style: AppTypography.geist(
                    fontSize: 12,
                    fontWeight: changed ? FontWeight.w500 : FontWeight.w400,
                    color: changed
                        ? c.primary
                        : isPresent
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

/// Confirm-mode banner shown when the list opened from a bulk default — it
/// explains what was pre-filled and what the user needs to do.
class _ConfirmBanner extends StatelessWidget {
  const _ConfirmBanner({required this.smartStart});

  final bool smartStart;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final lead = smartStart ? 'Pre-filled' : 'All present';
    final rest = smartStart
        ? '· here ≥80% of last 8 — fix exceptions'
        : '· switch off anyone missing';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.primary.withValues(alpha: 0.07), c.cardSoft),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(
            smartStart ? Icons.auto_awesome : Icons.check_rounded,
            size: 14,
            color: c.primary,
          ),
          const SizedBox(width: 8),
          Text(
            lead,
            style: AppTypography.geist(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              rest,
              style: AppTypography.geist(fontSize: 12, color: c.ink3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only "Grouped by status/family" indicator shown on the marking list,
/// where grouping is a per-event preset rather than a live toggle.
class _GroupingIndicator extends StatelessWidget {
  const _GroupingIndicator({required this.grouping});

  final RosterGrouping grouping;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final byFamily = grouping == RosterGrouping.byFamily;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          byFamily ? Icons.groups_outlined : Icons.checklist_rounded,
          size: 16,
          color: c.ink3,
        ),
        const SizedBox(width: 6),
        Text(
          byFamily ? 'Grouped by family' : 'Grouped by status',
          style: AppTypography.geist(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.ink3,
          ),
        ),
      ],
    );
  }
}

/// Trailing dashed roster row for adding a walk-in not on the list.
class _AddGuestRow extends StatelessWidget {
  const _AddGuestRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        key: const Key('rosterAddGuestRow'),
        onTap: onTap,
        borderRadius: AppRadii.compactR,
        child: _DashedBorderBox(
          color: c.hair,
          radius: AppRadii.compactR,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.cardSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_alt, size: 20, color: c.ink3),
                ),
                const SizedBox(width: 10),
                Text(
                  'Add guest',
                  style: AppTypography.geist(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded box with a dashed outline — used as the affordance frame for the
/// trailing "Add guest" roster row.
class _DashedBorderBox extends StatelessWidget {
  const _DashedBorderBox({
    required this.child,
    required this.color,
    required this.radius,
  });

  final Widget child;
  final Color color;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = radius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
