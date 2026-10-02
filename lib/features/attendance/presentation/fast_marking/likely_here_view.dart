import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_shadows.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';
import 'fast_marking_model.dart';

/// Fast marking without typing: the roster as a grid of tappable names ordered
/// by how often each person has turned up lately, so the people most likely to
/// be in the room need the least scrolling. Marked names stay in place and turn
/// to "Here" so the remaining work visibly shrinks.
///
/// The grid has no search: anyone the ordering buries is a scroll away, and the
/// List surface owns searching. The one extra action is a floating "Add
/// someone" pill for a person who is not on the grid at all.
class LikelyHereView extends StatelessWidget {
  const LikelyHereView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onAddGuest,
    this.addSomeoneKey,
    this.disableAnimations = false,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final VoidCallback onAddGuest;

  /// Lets the add sheet grow out of the "Add someone" pill (#222 M1); pass the
  /// same key to `showConvMorphSheet`.
  final GlobalKey<ConvMorphSourceState>? addSomeoneKey;
  final bool disableAnimations;

  Future<void> _toggle(Member member) async {
    await onToggle(member, !roster.isPresent(member));
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    // Stable order (likelihood ranking), does not shuffle when marked.
    final unmarked = roster.unmarked;
    final ordered = roster.members;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ConvEyebrow('Likely here'),
              const SizedBox(width: 12),
              // Expanded, not a Spacer + bare Text: the eyebrow's wide letter
              // spacing plus this caption is more than a phone's width.
              Expanded(
                child: Text(
                  '${unmarked.length} left · most frequent first',
                  style: AppTypography.geist(fontSize: 11.5, color: c.ink4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ordered.isEmpty
                    ? Center(
                        child: Text(
                          'Nobody on this roster yet.',
                          style:
                              AppTypography.geist(fontSize: 14, color: c.ink3),
                        ),
                      )
                    : GridView.builder(
                        // Bottom padding clears the floating pill so the last
                        // row can scroll out from under it.
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: 64,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: ordered.length,
                        itemBuilder: (context, i) => _LikelyChip(
                          key: Key('likelyHereChip_${ordered[i].id}'),
                          member: ordered[i],
                          isPresent: roster.isPresent(ordered[i]),
                          rate: roster.rateFor(ordered[i]),
                          onTap: () => _toggle(ordered[i]),
                        ),
                      ),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: _AddSomeonePill(
                  sourceKey: addSomeoneKey,
                  onTap: onAddGuest,
                  disableAnimations: disableAnimations,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddSomeonePill extends StatelessWidget {
  const _AddSomeonePill({
    required this.sourceKey,
    required this.onTap,
    required this.disableAnimations,
  });

  final GlobalKey<ConvMorphSourceState>? sourceKey;
  final VoidCallback onTap;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ConvMorphSource(
      key: sourceKey,
      color: c.primary,
      label: const _AddSomeoneLabel(),
      child: ConvPressable.builder(
        disableAnimations: disableAnimations,
        builder: (context, pressed) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.fab(c.primary, pressed: pressed),
          ),
          child: Material(
            color: c.primary,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: const Key('likelyHereAddGuest'),
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: _AddSomeoneLabel(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSomeoneLabel extends StatelessWidget {
  const _AddSomeoneLabel();

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_add_alt_1_outlined,
          color: c.onPrimary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Add someone',
          style: AppTypography.geist(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _LikelyChip extends StatelessWidget {
  const _LikelyChip({
    super.key,
    required this.member,
    required this.isPresent,
    required this.rate,
    required this.onTap,
  });

  final Member member;
  final bool isPresent;
  final double? rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final isUnranked = !isPresent && rate == null;
    final attendeeSurname = memberLastName(member.displayName);
    final hasDistinctSurname =
        isUnranked && attendeeSurname.isNotEmpty && attendeeSurname != member.displayName.trim();

    final titleText =
        hasDistinctSurname ? memberGivenName(member.displayName) : member.displayName;

    return Material(
      color: isPresent ? c.present : c.card,
      borderRadius: AppRadii.compactR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.compactR,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.compactR,
            border: Border.all(color: isPresent ? c.present : c.hair),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flexible, not a bare Text: a name that wraps to two lines (or
              // a large system text scale) must eat into its own space and
              // ellipsize rather than push the meta line out of the tile.
              Flexible(
                child: Text(
                  titleText,
                  style: AppTypography.geist(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    color: isPresent ? c.onPrimary : c.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPresent) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 11, color: c.onPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Here',
                      style: AppTypography.eyebrow(
                        color: c.onPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ] else if (rate != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${(rate! * 100).round()}%',
                  style: AppTypography.eyebrow(color: c.ink4, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (hasDistinctSurname) ...[
                const SizedBox(height: 2),
                Text(
                  attendeeSurname.toUpperCase(),
                  style: AppTypography.eyebrow(color: c.ink4, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
