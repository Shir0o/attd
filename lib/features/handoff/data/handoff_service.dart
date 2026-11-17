import 'package:flutter/material.dart' show TimeOfDay;

import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../domain/handoff_file.dart';
import '../domain/handoff_import.dart';

/// What the owner sees before a result changes anything.
class ResultPreview {
  const ResultPreview({required this.result, required this.event});

  final HandoffResult result;
  final Event event;
}

/// What an import did.
class ResultImportOutcome {
  const ResultImportOutcome({
    required this.sessionCreated,
    required this.changed,
    required this.unknownMemberMarks,
  });

  final bool sessionCreated;

  /// False when the session already held every mark (a repeated import).
  final bool changed;
  final int unknownMemberMarks;
}

/// Repository work for both ends of a handoff. All the rules about what a file
/// may contain live in the domain module; this only reads and writes records.
class HandoffService {
  HandoffService({
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
  });

  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;

  // ---- Helper: receive, find marks, remove -------------------------------

  /// Adds the handed-off event to this phone.
  ///
  /// Everything the file brings is stored under ids prefixed
  /// [handoffIdPrefix], which this app never generates and a file can never
  /// name, so it cannot overwrite the helper's own events, members or
  /// sessions. The roster is one family, with the same namespaced id as the
  /// event, holding one member per person; [remove] deletes exactly that.
  /// Receiving the same file again refreshes the event and its roster.
  Future<Event> receive(HandoffRoster doc) async {
    final eventId = doc.localEventId;
    final existing = await eventRepository.findEventById(eventId);
    if (existing != null && !existing.isHandedOff) {
      throw const HandoffFormatException(
        'This handoff clashes with an event on this phone and was not added.',
      );
    }

    final now = DateTime.now();
    final memberIds = [
      for (final p in doc.roster) HandoffRoster.localMemberId(p.id),
    ];
    final family = Family(
      id: eventId,
      displayName: '${doc.eventTitle} Roster',
      members: [
        for (final p in doc.roster)
          Member(
            id: HandoffRoster.localMemberId(p.id),
            displayName: p.name,
            updatedAt: now,
          ),
      ],
      updatedAt: now,
    );
    final families = await attendanceRepository.fetchAllFamilies();
    await attendanceRepository.saveFamilies([
      for (final f in families)
        if (f.id != eventId) f,
      family,
    ]);

    final event = Event(
      id: eventId,
      title: doc.eventTitle,
      time: const TimeOfDay(hour: 0, minute: 0),
      frequency: 'One-time',
      oneTimeDate: doc.sessionDate,
      memberIds: memberIds,
      handoffEventId: doc.eventId,
      createdAt: existing?.createdAt ?? now,
    );
    if (existing == null) {
      await eventRepository.createEvent(event);
    } else {
      await eventRepository.updateEvent(event);
    }
    return event;
  }

  /// Removes a handed-off event and everything it brought: the event, its
  /// roster family and members, and the marks recorded for it. Nothing else is
  /// touched. Deletions follow the app's soft-delete convention.
  Future<void> remove(Event event) async {
    if (!event.isHandedOff) {
      throw ArgumentError('Only a handed-off event can be removed here.');
    }
    final sessions = await sessionRepository.loadSessions();
    for (final s in sessions) {
      if (s.eventId == event.id) {
        await sessionRepository.deleteSession(s.id, actor: 'Handoff removal');
      }
    }

    final now = DateTime.now();
    final families = await attendanceRepository.fetchAllFamilies();
    if (families.any((f) => f.id == event.id)) {
      await attendanceRepository.saveFamilies([
        for (final f in families)
          if (f.id == event.id)
            f.copyWith(
              deletedAt: now,
              updatedAt: now,
              members: [
                for (final m in f.members)
                  m.copyWith(deletedAt: now, updatedAt: now),
              ],
            )
          else
            f,
      ]);
    }
    await eventRepository.deleteEvent(event.id);
  }

  /// The session marked on this phone for a handed-off event, if any.
  Future<Session?> sessionFor(Event event) async {
    final sessions = await sessionRepository.loadSessions();
    final mine = sessions.where((s) => s.eventId == event.id).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return mine.isEmpty ? null : mine.first;
  }

  // ---- Owner: import a result --------------------------------------------

  Future<Event> _eventFor(HandoffResult result) async {
    final event = await eventRepository.findEventById(result.eventId);
    if (event == null || event.deletedAt != null || event.isHandedOff) {
      throw const HandoffFormatException(
        'This result is for an event that is not on this phone, so nothing '
        'was added.',
      );
    }
    return event;
  }

  /// Finds the event a result belongs to without changing anything. Refuses
  /// a result for an event that is not on this phone.
  Future<ResultPreview> preview(HandoffResult result) async =>
      ResultPreview(result: result, event: await _eventFor(result));

  /// Merges a result into the session for its event and date, creating it if
  /// absent. Repeating it adds nothing.
  Future<ResultImportOutcome> apply(HandoffResult result) async {
    final event = await _eventFor(result);
    final families = await attendanceRepository.fetchFamilies();
    final known = <String, String>{
      for (final f in families)
        for (final m in f.members)
          if (m.deletedAt == null) m.id: m.displayName,
    };

    final sessions = await sessionRepository.loadSessions();
    Session? existing;
    for (final s in sessions) {
      if (s.eventId == event.id &&
          s.deletedAt == null &&
          s.sessionDate.year == result.sessionDate.year &&
          s.sessionDate.month == result.sessionDate.month &&
          s.sessionDate.day == result.sessionDate.day) {
        existing = s;
        break;
      }
    }

    final plan = HandoffImport.plan(
      result: result,
      knownMembers: known,
      existing: existing?.records ?? const [],
    );

    if (existing == null) {
      if (plan.records.isEmpty) {
        return const ResultImportOutcome(
          sessionCreated: false,
          changed: false,
          unknownMemberMarks: 0,
        );
      }
      await sessionRepository.createSession(
        title: event.title,
        eventId: event.id,
        sessionDate: DateTime(
          result.sessionDate.year,
          result.sessionDate.month,
          result.sessionDate.day,
        ),
        actor: result.actor,
        records: plan.records,
      );
      return ResultImportOutcome(
        sessionCreated: true,
        changed: true,
        unknownMemberMarks: plan.unknownMemberMarks,
      );
    }

    if (plan.changed) {
      await sessionRepository.saveSnapshot(
        existing.copyWith(records: plan.records),
        actor: result.actor,
      );
    }
    return ResultImportOutcome(
      sessionCreated: false,
      changed: plan.changed,
      unknownMemberMarks: plan.unknownMemberMarks,
    );
  }
}
