import 'package:flutter/material.dart';

import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../domain/check_on_board.dart';
import 'check_on_report_page.dart';

/// "3 people to check on", shown on the session summary after marking and
/// opening the report. Renders nothing when this event has nobody to check on.
///
/// The session being summarised is [session], as the summary holds it, so a
/// change made on the summary page is counted at once.
class CheckOnSummaryLine extends StatefulWidget {
  const CheckOnSummaryLine({
    super.key,
    required this.event,
    required this.session,
    required this.members,
    required this.sessionRepository,
    required this.eventRepository,
    required this.attendanceRepository,
    this.disableAnimations = false,
  });

  final Event event;
  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final bool disableAnimations;

  @override
  State<CheckOnSummaryLine> createState() => _CheckOnSummaryLineState();
}

class _CheckOnSummaryLineState extends State<CheckOnSummaryLine> {
  List<Session> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await widget.sessionRepository.loadSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      debugPrint('Error loading who to check on: $e');
    }
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckOnReportPage(
          eventRepository: widget.eventRepository,
          sessionRepository: widget.sessionRepository,
          attendanceRepository: widget.attendanceRepository,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = CheckOnBoard.compute(
      events: [widget.event],
      members: widget.members,
      sessions: [
        ..._sessions.where((s) => s.id != widget.session.id),
        widget.session,
      ],
    ).toCheck.length;
    if (count == 0) return const SizedBox.shrink();

    final c = context.conv;
    final label =
        count == 1 ? '1 person to check on' : '$count people to check on';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        key: const ValueKey('checkon_summary_line'),
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.person_search_outlined,
                      size: 20, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
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
          ),
        ),
      ),
    );
  }
}
