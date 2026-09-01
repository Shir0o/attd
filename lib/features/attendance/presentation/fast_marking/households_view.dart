import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/family.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';
import 'fast_marking_model.dart';
import 'fast_marking_shared.dart';

/// Fast marking for people who arrive together: search returns households, and
/// one button marks a whole family present. The member sub-rows stay tappable
/// so the one person who stayed home can be dropped straight after.
///
/// Auto-singleton families (the per-member buckets) render as plain rows —
/// wrapping a household card round one person would be noise.
class HouseholdsView extends StatefulWidget {
  const HouseholdsView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onFamilyToggle,
    required this.onAddGuest,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final FamilyMarkCallback onFamilyToggle;
  final VoidCallback onAddGuest;

  @override
  State<HouseholdsView> createState() => _HouseholdsViewState();
}

class _HouseholdsViewState extends State<HouseholdsView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  static const int _maxHouseholds = 3;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Households whose own name, or any member's name, matches the query.
  /// Ordered by the best match any of their names achieves.
  List<Family> get _matches {
    if (_query.trim().isEmpty) return const [];
    final scored = <({Family family, int rank})>[];
    for (final family in widget.roster.families) {
      int? best = matchRank(family.displayName, _query);
      for (final m in family.members) {
        final r = matchRank(m.displayName, _query);
        if (r != null && (best == null || r < best)) best = r;
      }
      if (best != null) scored.add((family: family, rank: best));
    }
    scored.sort((a, b) {
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      return a.family.displayName.toLowerCase().compareTo(
            b.family.displayName.toLowerCase(),
          );
    });
    final ordered = [for (final s in scored) s.family];
    return ordered.length > _maxHouseholds
        ? ordered.sublist(0, _maxHouseholds)
        : ordered;
  }

  bool _isPlainRow(Family family) =>
      family.isAutoSingleton || family.members.length <= 1;

  Future<void> _markFamily(Family family) async {
    await widget.onFamilyToggle(family, true);
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _query = '';
    });
    _focusNode.requestFocus();
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _toggleMember(Member member) async {
    await widget.onToggle(member, !widget.roster.isPresent(member));
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_query.isNotEmpty && matches.isEmpty)
                    AddGuestRow(query: _query, onTap: widget.onAddGuest),
                  for (final family in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _isPlainRow(family)
                          ? FastMarkingRow(
                              key: Key(
                                'fastMarkingResult_'
                                '${family.members.first.id}',
                              ),
                              member: family.members.first,
                              isPresent: widget.roster.isPresent(
                                family.members.first,
                              ),
                              subtitle: widget.roster.subtitleFor(
                                family.members.first,
                              ),
                              onTap: () => _toggleMember(family.members.first),
                            )
                          : _HouseholdCard(
                              key: Key('householdCard_${family.id}'),
                              family: family,
                              roster: widget.roster,
                              onMarkAll: () => _markFamily(family),
                              onToggleMember: _toggleMember,
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
        MarkingSearchField(
          fieldKey: const Key('householdsField'),
          controller: _controller,
          focusNode: _focusNode,
          hintText: 'Type a family or a name',
          caption: 'Search finds households. A whole family in two taps.',
          trailingLabel: matches.isEmpty
              ? null
              : '${matches.length} '
                  '${matches.length == 1 ? 'household' : 'households'}',
          onChanged: (v) => setState(() => _query = v),
          onClear: () {
            _controller.clear();
            setState(() => _query = '');
            _focusNode.requestFocus();
          },
        ),
      ],
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    super.key,
    required this.family,
    required this.roster,
    required this.onMarkAll,
    required this.onToggleMember,
  });

  final Family family;
  final FastMarkingRoster roster;
  final VoidCallback onMarkAll;
  final ValueChanged<Member> onToggleMember;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final present = family.members.where(roster.isPresent).length;
    final total = family.members.length;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadii.softR,
        border: Border.all(color: c.hair),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ConvAvatar(
                letter: family.displayName.isNotEmpty
                    ? family.displayName[0].toUpperCase()
                    : '?',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      family.displayName,
                      style: AppTypography.geist(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$total ${total == 1 ? 'member' : 'members'} · '
                      '$present here',
                      style: AppTypography.geist(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              key: Key('householdMarkAll_${family.id}'),
              onPressed: onMarkAll,
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.compactR,
                ),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text('Mark all $total present'),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.hair),
          const SizedBox(height: 6),
          for (final m in family.members)
            InkWell(
              key: Key('householdMember_${m.id}'),
              onTap: () => onToggleMember(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.displayName,
                        style: AppTypography.geist(
                          fontSize: 13.5,
                          color: roster.isPresent(m) ? c.ink : c.ink4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: roster.isPresent(m)
                            ? c.present
                            : Colors.transparent,
                        border: Border.all(
                          color: roster.isPresent(m) ? c.present : c.hair,
                          width: 1.5,
                        ),
                      ),
                      child: roster.isPresent(m)
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: c.onPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
