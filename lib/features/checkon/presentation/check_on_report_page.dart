import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../domain/check_on.dart';
import '../domain/check_on_board.dart';
import 'check_on_widgets.dart';

/// "Who to check on": one card per flagged person, a line per event.
///
/// Computed on open from stored sessions; there is nothing to configure. The
/// owner can tick a person "Followed up" (they drop to the bottom, dimmed,
/// until they trigger a new flag) or "Stop flagging" them on one event.
class CheckOnReportPage extends StatefulWidget {
  const CheckOnReportPage({
    super.key,
    required this.eventRepository,
    required this.sessionRepository,
    required this.attendanceRepository,
    this.disableAnimations = false,
  });

  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
  final bool disableAnimations;

  @override
  State<CheckOnReportPage> createState() => _CheckOnReportPageState();
}

class _CheckOnReportPageState extends State<CheckOnReportPage> {
  List<Event> _events = const [];
  List<Session> _sessions = const [];
  List<Member> _members = const [];
  bool _eventsLoaded = false;
  bool _dataLoaded = false;
  bool _minElapsed = false;
  String? _eventFilter;
  StreamSubscription<List<Event>>? _eventsSub;

  bool get _loading => !(_eventsLoaded && _dataLoaded && _minElapsed);

  @override
  void initState() {
    super.initState();
    _eventsSub = widget.eventRepository.streamEvents().listen((events) {
      if (!mounted) return;
      setState(() {
        _events = events.where((e) => e.deletedAt == null).toList();
        _eventsLoaded = true;
      });
    });
    _loadData();
    // Mandatory skeleton duration (800ms), as on every page.
    if (widget.disableAnimations) {
      _minElapsed = true;
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _minElapsed = true);
      });
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final families = await widget.attendanceRepository.fetchFamilies();
      final sessions = await widget.sessionRepository.loadSessions();
      if (!mounted) return;
      setState(() {
        _members = families.expand((f) => f.members).toList();
        _sessions = sessions;
      });
    } catch (e) {
      debugPrint('Error loading who to check on: $e');
    }
    if (mounted) setState(() => _dataLoaded = true);
  }

  Event? _eventById(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Applies [updated] locally at once and persists it. The repository's own
  /// stream then confirms it.
  Future<void> _save(Iterable<Event> updated) async {
    final byId = {for (final e in updated) e.id: e};
    setState(() {
      _events = [for (final e in _events) byId[e.id] ?? e];
    });
    for (final e in updated) {
      await widget.eventRepository.updateEvent(e);
    }
  }

  Future<void> _toggleFollowedUp(CheckOnBoard board, CheckOnPerson person) {
    final done = board.isPersonFollowedUp(person);
    final byEvent = <String, List<CheckOnEntry>>{};
    for (final entry in person.entries) {
      byEvent.putIfAbsent(entry.eventId, () => []).add(entry);
    }
    final updated = <Event>[];
    for (final e in byEvent.entries) {
      final event = _eventById(e.key);
      if (event == null) continue;
      updated.add(
        done
            ? event.withoutFollowUps([person.memberId])
            : event.withFollowUps(e.value),
      );
    }
    return _save(updated);
  }

  Future<void> _stopFlagging(CheckOnEntry entry) async {
    final event = _eventById(entry.eventId);
    if (event == null) return;
    await _save([event.withStopFlagging(entry.memberId)]);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          'Stopped flagging ${entry.displayName} on ${entry.eventTitle}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final current = _eventById(entry.eventId);
            if (current != null) {
              _save([current.withoutStopFlagging(entry.memberId)]);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SkeletonSwitcher(
          loading: _loading,
          disableAnimations: widget.disableAnimations,
          skeleton: _Skeleton(disableAnimations: widget.disableAnimations),
          child: _loading ? const SizedBox.shrink() : _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final c = context.conv;
    // Reset a filter whose event has gone.
    final filter = _eventFilter != null && _eventById(_eventFilter!) != null
        ? _eventFilter
        : null;
    final board = CheckOnBoard.compute(
      events: _events,
      members: _members,
      sessions: _sessions,
    );
    final people = board.people(eventId: filter);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Header(onBack: () => Navigator.of(context).maybePop()),
        const SizedBox(height: 8),
        Text(
          'Who to check on',
          style: AppTypography.fraunces(
            fontSize: 36,
            fontWeight: FontWeight.w500,
            height: 1.05,
            color: c.ink,
          ),
        ),
        if (_events.length > 1) ...[
          const SizedBox(height: 16),
          _EventFilter(
            events: _events,
            selectedId: filter,
            onSelected: (id) => setState(() => _eventFilter = id),
          ),
        ],
        const SizedBox(height: 16),
        const CheckOnLegend(),
        const SizedBox(height: 16),
        if (people.isEmpty)
          const _AllClear()
        else
          for (final person in people)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PersonCard(
                person: person,
                done: board.isPersonFollowedUp(person),
                isLineDone: board.isFollowedUp,
                onToggle: () => _toggleFollowedUp(board, person),
                onStop: _stopFlagging,
              ),
            ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Always current. The same rules apply to every event.',
            style: TextStyle(fontSize: 13, color: c.ink2),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ConvIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 8),
        const ConvEyebrow('All events'),
      ],
    );
  }
}

class _EventFilter extends StatelessWidget {
  const _EventFilter({
    required this.events,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Event> events;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final e in events)
            _FilterChip(
              label: e.title,
              selected: selectedId == e.id,
              onTap: () => onSelected(e.id),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? c.primary : c.cardSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? c.onPrimary : c.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.done,
    required this.isLineDone,
    required this.onToggle,
    required this.onStop,
  });

  final CheckOnPerson person;
  final bool done;
  final bool Function(CheckOnEntry) isLineDone;
  final VoidCallback onToggle;
  final ValueChanged<CheckOnEntry> onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Opacity(
      opacity: done ? 0.72 : 1,
      child: ConvCard(
        key: ValueKey('checkon_card_${person.memberId}'),
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      person.displayName,
                      style: AppTypography.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                        color: c.ink,
                      ).copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: c.ink2,
                      ),
                    ),
                  ),
                  for (final entry in person.entries)
                    _EntryLine(entry: entry, onStop: () => onStop(entry)),
                ],
              ),
            ),
            _TickButton(
              memberId: person.memberId,
              name: person.displayName,
              done: done,
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.entry, required this.onStop});

  final CheckOnEntry entry;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                entry.eventTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              CheckOnFlagLabel(entry.flag),
            ],
          ),
          const SizedBox(height: 6),
          CheckOnDots(history: entry.history),
          const SizedBox(height: 6),
          Text(entry.reason, style: TextStyle(fontSize: 12, color: c.ink2)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: ValueKey('checkon_stop_${entry.eventId}_${entry.memberId}'),
              onPressed: onStop,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: c.primary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Stop flagging'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickButton extends StatelessWidget {
  const _TickButton({
    required this.memberId,
    required this.name,
    required this.done,
    required this.onPressed,
  });

  final String memberId;
  final String name;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Semantics(
      container: true,
      button: true,
      toggled: done,
      label: done
          ? 'Followed up with $name, tap to undo'
          : 'Mark $name followed up',
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          key: ValueKey('checkon_tick_$memberId'),
          color: done ? c.primary : c.cardSoft,
          borderRadius: AppRadii.compactR,
          child: InkWell(
            borderRadius: AppRadii.compactR,
            onTap: onPressed,
            child: Icon(
              Icons.check_rounded,
              size: 22,
              color: done ? c.onPrimary : c.ink2,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 36, color: c.primary),
          const SizedBox(height: 12),
          Text(
            "Everyone's accounted for",
            textAlign: TextAlign.center,
            style: AppTypography.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nobody has dropped off lately.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.ink2),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.disableAnimations});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    Widget box(double w, double h) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppShimmer(
            width: w,
            height: h,
            borderRadius: radius,
            disableAnimations: disableAnimations,
          ),
        );
    return ListView(
      key: const ValueKey('checkon_report_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        box(48, 48),
        box(220, 40),
        box(double.infinity, 40),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ConvCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(140, 22),
                  box(180, 14),
                  box(124, 12),
                  box(220, 12),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
