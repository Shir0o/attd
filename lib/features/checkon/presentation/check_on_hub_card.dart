import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';
import '../domain/check_on.dart';
import '../domain/check_on_board.dart';
import 'check_on_widgets.dart';

/// Most people the hub card lists; the rest are behind "+N more".
const int kCheckOnHubCardMax = 6;

/// The hub's "Who to check on" card: the few people who most need attention
/// across all events, or a calm note that nobody does.
///
/// People already followed up on, or set to "stop flagging", are not listed.
class CheckOnHubCard extends StatelessWidget {
  const CheckOnHubCard({
    super.key,
    required this.events,
    required this.members,
    required this.sessions,
    required this.onOpenReport,
  });

  final List<Event> events;
  final List<Member> members;
  final List<Session> sessions;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final people = CheckOnBoard.compute(
      events: events,
      members: members,
      sessions: sessions,
    ).toCheck;
    final shown = people.take(kCheckOnHubCardMax).toList();
    final more = people.length - shown.length;

    return ConvCard(
      key: const ValueKey('checkon_hub_card'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: ConvEyebrow('Who to check on', color: c.ink2)),
              ],
            ),
          ),
          if (shown.isEmpty)
            const _AllClear()
          else
            for (final person in shown)
              _PersonRow(person: person, onTap: onOpenReport),
          if (more > 0)
            _TapRow(
              key: const ValueKey('checkon_more'),
              onTap: onOpenReport,
              child: Text(
                '+$more more',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.primary,
                ),
              ),
            ),
          const SizedBox(height: 4),
          _TapRow(
            key: const ValueKey('checkon_open_report'),
            onTap: onOpenReport,
            tonal: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'See why, and mark who you reached',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: c.ink2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width tap target of at least 48dp.
class _TapRow extends StatelessWidget {
  const _TapRow({
    super.key,
    required this.onTap,
    required this.child,
    this.tonal = false,
  });

  final VoidCallback onTap;
  final Widget child;

  /// Sits on a tonal pill instead of the card: no hairline.
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final radius = tonal ? BorderRadius.circular(999) : AppRadii.compactR;
    return Material(
      color: tonal ? c.cardSoft : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tonal ? 16 : 4),
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final CheckOnPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final entry = person.entries.first;
    return InkWell(
      key: ValueKey('checkon_row_${person.memberId}'),
      onTap: onTap,
      borderRadius: AppRadii.compactR,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.geist(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Text(' · ', style: TextStyle(color: c.ink2)),
                        Flexible(child: CheckOnFlagLabel(entry.flag)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CheckOnDots(history: entry.history),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  const _AllClear();

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 22, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Everyone's accounted for",
              style: AppTypography.geist(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
