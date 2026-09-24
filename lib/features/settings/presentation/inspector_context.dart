import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/widgets/conv_theme.dart';
import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';

/// Lookups the storage inspector uses to explain a record in context: the
/// session a mark sits in, what else was recorded for the same event and
/// date, and which live members a dangling mark could belong to.
class InspectorIndex {
  InspectorIndex({
    required this.events,
    required this.sessions,
    required this.families,
  });

  final List<Event> events;
  final List<Session> sessions;
  final List<Family> families;

  static String slotOf(Session s) =>
      '${s.title.trim().toLowerCase()}|${DateFormat('yyyy-MM-dd').format(s.sessionDate)}';

  Session? session(String? id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Event? event(String? id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Other live sessions for the same event title and date.
  List<Session> siblings(Session s) => sessions
      .where((o) => o.id != s.id && o.deletedAt == null && slotOf(o) == slotOf(s))
      .toList();

  bool isLiveMember(String? id) => liveMembers().any((m) => m.$1.id == id);

  List<(Member, Family)> liveMembers() => [
        for (final f in families)
          if (f.deletedAt == null)
            for (final m in f.members)
              if (m.deletedAt == null) (m, f),
      ];

  /// Live members whose display or canonical name matches [name].
  List<(Member, Family)> liveMembersNamed(String name) {
    final n = name.trim().toLowerCase();
    return liveMembers()
        .where((e) =>
            e.$1.displayName.trim().toLowerCase() == n ||
            e.$1.canonicalName.trim().toLowerCase() == n)
        .toList();
  }

  /// Index of the mark in [s] identified by its person and recorded-at time.
  static int markIndex(Session s, {String? memberId, required String attendee, required int recordedAtMs}) =>
      s.records.indexWhere((r) =>
          (memberId != null ? r.memberId == memberId : r.attendee == attendee) &&
          r.recordedAt.millisecondsSinceEpoch == recordedAtMs);
}

String _sessionLine(Session s) =>
    '${s.title} · ${DateFormat('MMM d, yyyy').format(s.sessionDate)} · '
    'by ${s.createdBy} ${DateFormat('MMM d HH:mm').format(s.createdAt)} · ${s.records.length} marks';

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.conv.ink3),
        ),
      );
}

/// A session summary line plus every mark in it; [highlight] marks the mark
/// being inspected, [person] bolds any mark for the same person.
class _SessionMarks extends StatelessWidget {
  const _SessionMarks({required this.session, this.highlight, this.person});

  final Session session;
  final SessionRecord? highlight;
  final String? person;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_sessionLine(session), style: TextStyle(fontSize: 11.5, color: c.ink2)),
          const SizedBox(height: 6),
          if (session.records.isEmpty)
            Text('No marks', style: TextStyle(fontSize: 11.5, color: c.ink4))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in session.records)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: identical(r, highlight)
                          ? c.primary.withValues(alpha: 0.16)
                          : c.cardSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${r.attendee} · ${r.status == AttendanceStatus.present ? 'P' : 'A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: r.status == AttendanceStatus.present ? c.ink : c.ink3,
                        fontWeight: r.attendee.trim().toLowerCase() == person ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Context for one attendance mark: its status, its session, other sessions
/// for the same event and date, and — when its member is gone — who it could
/// be linked to instead.
class MarkContext extends StatelessWidget {
  const MarkContext({
    super.key,
    required this.recordKey,
    required this.session,
    required this.mark,
    required this.index,
    required this.onStatus,
    required this.onLink,
    required this.onGuest,
  });

  final String recordKey;
  final Session session;
  final SessionRecord mark;
  final InspectorIndex index;
  final ValueChanged<AttendanceStatus> onStatus;
  final ValueChanged<Member> onLink;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final person = mark.attendee.trim().toLowerCase();
    final others = index
        .siblings(session)
        .where((s) => s.records.any((r) =>
            r.attendee.trim().toLowerCase() == person ||
            (mark.memberId != null && r.memberId == mark.memberId)))
        .toList();
    final dangling = mark.memberId != null && !index.isLiveMember(mark.memberId);

    return Column(
      key: ValueKey('context_$recordKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Status'),
        Row(
          children: [
            for (final status in AttendanceStatus.values) ...[
              ChoiceChip(
                key: ValueKey('status_btn_${recordKey}_${status.name}'),
                label: Text(status.label),
                selected: mark.status == status,
                onSelected: mark.status == status ? null : (_) => onStatus(status),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        if (dangling) ...[
          const _Heading('Who is this?'),
          Text(
            'The member this mark was linked to no longer exists.',
            style: TextStyle(fontSize: 12, color: c.ink3),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (member, family) in index.liveMembersNamed(mark.attendee))
                OutlinedButton.icon(
                  key: ValueKey('link_btn_${recordKey}_${member.id}'),
                  onPressed: () => onLink(member),
                  icon: const Icon(Icons.link, size: 16),
                  label: Text('Link to ${member.displayName} (${family.displayName})'),
                ),
              OutlinedButton.icon(
                key: ValueKey('guest_btn_$recordKey'),
                onPressed: onGuest,
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Keep as guest'),
              ),
            ],
          ),
        ],
        const _Heading('In this session'),
        _SessionMarks(session: session, highlight: mark, person: person),
        if (others.isNotEmpty) ...[
          _Heading('Also recorded in ${others.length} other session${others.length == 1 ? '' : 's'}'),
          for (final s in others) _SessionMarks(session: s, person: person),
        ],
      ],
    );
  }
}

/// Context for one session: its event, its marks, and other sessions for the
/// same event and date.
class SessionContext extends StatelessWidget {
  const SessionContext({super.key, required this.session, required this.index});

  final Session session;
  final InspectorIndex index;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final event = index.event(session.eventId);
    final eventText = session.eventId == null
        ? 'No event'
        : event == null
            ? 'Event missing (id ${session.eventId})'
            : event.deletedAt != null
                ? 'Event deleted: ${event.title}'
                : 'Event: ${event.title}';
    final siblings = index.siblings(session);

    return Column(
      key: ValueKey('context_${session.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Event'),
        Text(eventText, style: TextStyle(fontSize: 12.5, color: c.ink2)),
        const _Heading('Marks'),
        _SessionMarks(session: session),
        if (siblings.isNotEmpty) ...[
          _Heading('${siblings.length} other session${siblings.length == 1 ? '' : 's'} on this date'),
          for (final s in siblings) _SessionMarks(session: s),
        ],
      ],
    );
  }
}
