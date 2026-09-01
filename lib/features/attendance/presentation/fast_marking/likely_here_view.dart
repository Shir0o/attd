import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/member.dart';
import 'fast_marking_model.dart';
import 'rapid_entry_view.dart';

/// Fast marking without typing: the roster as a grid of tappable names ordered
/// by how often each person has turned up lately, so the people most likely to
/// be in the room need the least scrolling. Marked names move out of the
/// unmarked run so the remaining work visibly shrinks.
///
/// Anyone the ordering buries is reachable through [RapidEntryView], which this
/// surface opens over the grid rather than reimplementing search.
class LikelyHereView extends StatefulWidget {
  const LikelyHereView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onAddGuest,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final VoidCallback onAddGuest;

  @override
  State<LikelyHereView> createState() => _LikelyHereViewState();
}

class _LikelyHereViewState extends State<LikelyHereView> {
  bool _searching = false;

  Future<void> _toggle(Member member) async {
    await widget.onToggle(member, !widget.roster.isPresent(member));
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    if (_searching) {
      return RapidEntryView(
        roster: widget.roster,
        onToggle: widget.onToggle,
        onAddGuest: widget.onAddGuest,
        onDismiss: () => setState(() => _searching = false),
      );
    }

    // Unmarked first (still in likelihood order), marked pushed to the end.
    final unmarked = widget.roster.unmarked;
    final marked = widget.roster.members
        .where(widget.roster.isPresent)
        .toList(growable: false);
    final ordered = [...unmarked, ...marked];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ConvEyebrow('Likely here'),
              const Spacer(),
              Text(
                '${unmarked.length} left · most frequent first',
                style: AppTypography.geist(fontSize: 11.5, color: c.ink4),
              ),
            ],
          ),
        ),
        Expanded(
          child: ordered.isEmpty
              ? Center(
                  child: Text(
                    'Nobody on this roster yet.',
                    style: AppTypography.geist(fontSize: 14, color: c.ink3),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisExtent: 60,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: ordered.length,
                  itemBuilder: (context, i) => _LikelyChip(
                    key: Key('likelyHereChip_${ordered[i].id}'),
                    member: ordered[i],
                    isPresent: widget.roster.isPresent(ordered[i]),
                    rate: widget.roster.rateFor(ordered[i]),
                    onTap: () => _toggle(ordered[i]),
                  ),
                ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.hair)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Material(
            color: c.cardSoft,
            borderRadius: AppRadii.compactR,
            child: InkWell(
              key: const Key('likelyHereSearch'),
              borderRadius: AppRadii.compactR,
              onTap: () => setState(() => _searching = true),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: c.ink3, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Not in the grid? Search all '
                        '${widget.roster.members.length}',
                        style: AppTypography.geist(fontSize: 14, color: c.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
              Text(
                member.displayName,
                style: AppTypography.geist(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: isPresent ? c.onPrimary : c.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              if (isPresent)
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
                )
              else
                Text(
                  rate == null ? 'NEW' : '${(rate! * 100).round()}%',
                  style: AppTypography.eyebrow(color: c.ink4, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
