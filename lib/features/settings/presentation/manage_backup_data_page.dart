import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../../../core/logging/app_logger.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/data/local_event_repository.dart';
import '../../hub/domain/event.dart';
import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../../../data/local_session_repository.dart';
import '../../../data/session_repository.dart';
import '../../../core/maintenance/bulk_maintenance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'inspector_context.dart';

final _log = AppLogger('ManageBackup');

/// Suggestions the user marked "Not an issue" (DbRecord.uniqueKey values).
/// Device-local: dismissing never changes synced data.
const _dismissedPrefsKey = 'inspector_dismissed_suggestions';

class DbRecord {
  DbRecord({
    required this.id,
    required this.table,
    required this.title,
    required this.meta,
    this.flag,
    this.note,
    required this.fields,
  });

  final String id;
  final String table; // 'events', 'sessions', 'members', 'families', 'photos', 'attendance'
  final String title;
  final String meta;
  final String? flag; // 'hidden' | 'orphan' | 'duplicate' | null
  final String? note;
  final Map<String, String> fields;

  String get uniqueKey => '${table}_$id';

  /// Soft-deleted records are already gone from the app and are pruned by
  /// data maintenance, so only the other flags count as cleanup issues.
  bool get isIssue => flag != null && flag != 'hidden';
}

class ManageBackupDataPage extends StatefulWidget {
  const ManageBackupDataPage({
    super.key,
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    this.disableAnimations = false,
  });

  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final bool disableAnimations;

  @override
  State<ManageBackupDataPage> createState() => _ManageBackupDataPageState();
}

class _ManageBackupDataPageState extends State<ManageBackupDataPage> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  List<Family> _families = [];
  List<Event> _events = [];
  List<Session> _sessions = [];
  List<DbRecord> _allRecords = [];
  final Map<String, List<({String title, DateTime date})>> _memberUsageMap = {};

  String _selectedTable = 'all';
  bool _issuesOnly = false;
  String _searchQuery = '';
  String? _openRecordId;
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final startTime = DateTime.now();
    setState(() => _isLoading = true);
    try {
      List<Family> families = [];
      List<Event> events = [];
      List<Session> sessions = [];

      // Load using dynamic invocations or concrete casts
      final attRepo = widget.attendanceRepository;
      if (attRepo is LocalJsonAttendanceRepository) {
        families = await attRepo.fetchAllFamilies();
      } else {
        try {
          families = await (attRepo as dynamic).fetchAllFamilies();
        } catch (_) {
          families = await attRepo.fetchFamilies();
        }
      }

      final evRepo = widget.eventRepository;
      if (evRepo is LocalJsonEventRepository) {
        events = await evRepo.fetchAllEvents();
      } else {
        try {
          events = await (evRepo as dynamic).fetchAllEvents();
        } catch (_) {
          events = await evRepo.streamEvents().first;
        }
      }

      final sesRepo = widget.sessionRepository;
      if (sesRepo is LocalJsonSessionRepository) {
        sessions = await sesRepo.fetchAllSessions();
      } else {
        try {
          sessions = await (sesRepo as dynamic).fetchAllSessions();
        } catch (_) {
          sessions = await sesRepo.loadSessions();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList(_dismissedPrefsKey) ?? const <String>[];

      // Minimum loading duration for visual consistency
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 800) - elapsed;
      if (remaining > Duration.zero && !widget.disableAnimations) {
        await Future.delayed(remaining);
      }

      if (mounted) {
        setState(() {
          _dismissed
            ..clear()
            ..addAll(dismissed);
          _applyData(families, events, sessions);
          _isLoading = false;
        });
      }
    } catch (e, st) {
      _log.error('Failed to load backup data', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyData(List<Family> families, List<Event> events, List<Session> sessions) {
    _families = families;
    _events = events;
    _sessions = sessions;
    _memberUsageMap.clear();
    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      for (final record in session.records) {
        if (record.memberId != null) {
          _memberUsageMap
              .putIfAbsent(record.memberId!, () => [])
              .add((title: session.title, date: session.sessionDate));
        }
      }
    }
    _rebuildDbRecords();
  }

  void _rebuildDbRecords() {
    final List<DbRecord> records = [];

    // Map Events
    for (final event in _events) {
      final isDeleted = event.deletedAt != null;
      records.add(DbRecord(
        id: event.id,
        table: 'events',
        title: event.title,
        meta: '${event.repeatingDays.isNotEmpty ? event.repeatingDays.map((d) => d.substring(0, 3)).join(', ') : event.frequency} · ${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
        flag: isDeleted ? 'hidden' : null,
        note: isDeleted ? 'This event is soft-deleted and hidden in the main app.' : null,
        fields: {
          'id': event.id,
          'title': event.title,
          'frequency': event.frequency,
          'days': event.repeatingDays.toString(),
          'time': '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
          'members': '${event.memberIds.length}',
          'date': DateFormat('yyyy-MM-dd').format(event.createdAt),
          'created': DateFormat('yyyy-MM-dd HH:mm').format(event.createdAt),
          'deletedAt': event.deletedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(event.deletedAt!) : 'null',
        },
      ));
    }

    // Map Sessions
    for (final session in _sessions) {
      final isDeleted = session.deletedAt != null;
      final eventExists = session.eventId == null || _events.any((e) => e.id == session.eventId && e.deletedAt == null);

      String? flag;
      String? note;
      if (isDeleted) {
        flag = 'hidden';
        note = 'This session is soft-deleted and hidden in the main app.';
      } else if (!eventExists) {
        flag = 'orphan';
        note = 'This session references event ID ${session.eventId}, which is not in the database or is deleted.';
      } else if (session.records.isEmpty) {
        flag = 'orphan';
        note = 'This session is empty and has no attendance records.';
      }

      records.add(DbRecord(
        id: session.id,
        table: 'sessions',
        title: session.title,
        meta: '${session.records.length} marks · ${DateFormat('MMM dd, yyyy').format(session.sessionDate)}',
        flag: flag,
        note: note,
        fields: {
          'id': session.id,
          'event_id': session.eventId ?? '—',
          'date': DateFormat('yyyy-MM-dd').format(session.sessionDate),
          'formatted_date': DateFormat('MMM dd, yyyy').format(session.sessionDate),
          'records': '${session.records.length}',
          'created_by': session.createdBy,
          'deletedAt': session.deletedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(session.deletedAt!) : 'null',
        },
      ));
    }

    // Helper set for member exist check
    final activeMemberIds = _families
        .expand((f) => f.members)
        .where((m) => m.deletedAt == null && (_families.firstWhere((fam) => fam.members.contains(m)).deletedAt == null))
        .map((m) => m.id)
        .toSet();

    // Map Members
    final seenMemberIds = <String>{};
    for (final family in _families) {
      for (final member in family.members) {
        if (!seenMemberIds.add(member.id)) continue;
        final isDeleted = member.deletedAt != null || family.deletedAt != null;
        records.add(DbRecord(
          id: member.id,
          table: 'members',
          title: member.displayName,
          meta: 'Family: ${family.displayName}',
          flag: isDeleted ? 'hidden' : null,
          note: isDeleted ? 'This member is soft-deleted or belongs to a soft-deleted family.' : null,
          fields: {
            'id': member.id,
            'name': member.displayName,
            'family_id': family.id,
            'isVisitor': '${member.isVisitor}',
            'deletedAt': member.deletedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(member.deletedAt!) : 'null',
          },
        ));
      }
    }

    // Map Families
    for (final family in _families) {
      final isDeleted = family.deletedAt != null;
      final isEmpty = family.members.isEmpty;

      String? flag;
      String? note;
      if (isDeleted) {
        flag = 'hidden';
        note = 'This family is soft-deleted and hidden in the main app.';
      } else if (isEmpty) {
        flag = 'orphan';
        note = 'This family group has no members.';
      }

      records.add(DbRecord(
        id: family.id,
        table: 'families',
        title: family.displayName,
        meta: '${family.members.length} members',
        flag: flag,
        note: note,
        fields: {
          'id': family.id,
          'name': family.displayName,
          'isAutoSingleton': '${family.isAutoSingleton}',
          'members': '${family.members.length}',
          'deletedAt': family.deletedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(family.deletedAt!) : 'null',
        },
      ));
    }

    // Map Attendance (marks) & Track Duplicates (event name + date + attendant name match)
    final Map<String, String> seenAttendanceKeys = {};
    for (final session in _sessions) {
      final sessionDateStr = DateFormat('yyyy-MM-dd').format(session.sessionDate);
      final sessionDateFormatted = DateFormat('MMM dd, yyyy').format(session.sessionDate);

      for (final record in session.records) {
        final isSessionDeleted = session.deletedAt != null;
        final isMemberDeleted = record.memberId != null && !activeMemberIds.contains(record.memberId);
        final compositeKey = '${session.title.trim().toLowerCase()}|$sessionDateStr|${record.attendee.trim().toLowerCase()}';

        String? flag;
        String? note;
        if (isSessionDeleted) {
          flag = 'hidden';
          note = 'This attendance mark belongs to a soft-deleted session.';
        } else if (isMemberDeleted) {
          flag = 'orphan';
          note = 'This attendance mark references member ID ${record.memberId}, who has been deleted or is missing from the roster.';
        } else if (seenAttendanceKeys.containsKey(compositeKey)) {
          flag = 'duplicate';
          note = 'Duplicate attendance entry detected: matches event "${session.title}", date "$sessionDateStr", and attendant "${record.attendee}".';
        } else {
          seenAttendanceKeys[compositeKey] = '${session.id}_${record.memberId ?? record.attendee}';
        }

        final recordKey = '${session.id}_${record.memberId ?? record.attendee}_${record.recordedAt.millisecondsSinceEpoch}';

        records.add(DbRecord(
          id: recordKey,
          table: 'attendance',
          title: 'mark · ${record.status.name}',
          meta: '${session.title} · ${record.attendee} · $sessionDateFormatted',
          flag: flag,
          note: note,
          fields: {
            'session_id': session.id,
            'member_id': record.memberId ?? '—',
            'attendee': record.attendee,
            'status': record.status.name,
            'date': sessionDateStr,
            'formatted_date': sessionDateFormatted,
            'recordedAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(record.recordedAt),
            'recordedAtMs': '${record.recordedAt.millisecondsSinceEpoch}',
            'recordedBy': record.recordedBy,
          },
        ));
      }
    }

    _allRecords = records;
  }

  bool _needsReview(DbRecord r) => r.isIssue && !_dismissed.contains(r.uniqueKey);

  Future<void> _setDismissed(DbRecord r, bool dismissed) async {
    setState(() {
      if (dismissed) {
        _dismissed.add(r.uniqueKey);
      } else {
        _dismissed.remove(r.uniqueKey);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedPrefsKey, _dismissed.toList());
  }

  Future<void> _save(_Draft d) async {
    final saves = <Future<void>>[];
    if (d.touchedEvents.isNotEmpty) {
      final evRepo = widget.eventRepository;
      if (evRepo is LocalJsonEventRepository) {
        saves.add(evRepo.saveEvents(d.events));
      } else {
        saves.add((evRepo as dynamic).saveEvents(d.events));
      }
    }
    if (d.touchedSessions.isNotEmpty) {
      final sesRepo = widget.sessionRepository;
      if (sesRepo is LocalJsonSessionRepository) {
        saves.add(sesRepo.saveSessions(d.sessions));
      } else {
        saves.add((sesRepo as dynamic).saveSessions(d.sessions));
      }
    }
    if (d.touchedFamilies.isNotEmpty) {
      saves.add(widget.attendanceRepository.saveFamilies(d.families));
    }
    await Future.wait(saves);
    if (mounted) {
      setState(() => _applyData(d.families, d.events, d.sessions));
    }
  }

  /// Applies [edit] to working copies of the data, saves what it touched, and
  /// offers Undo. Edits bump updatedAt (and deletions leave tombstones) so the
  /// change wins the next Drive merge instead of being re-added from the cloud.
  Future<void> _mutate(String message, void Function(_Draft d) edit) async {
    final before = _Draft(_events, _sessions, _families);
    final after = _Draft(_events, _sessions, _families);
    try {
      edit(after);
      await _save(after);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Undo', onPressed: () => _undo(before, after)),
        ));
    } catch (e, st) {
      _log.error('Failed to update records', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update records: $e')),
      );
    }
  }

  /// Puts back the entities [after] touched as they were in [before], with a
  /// fresh updatedAt so the restore also wins the next Drive merge.
  Future<void> _undo(_Draft before, _Draft after) async {
    final now = DateTime.now();
    final d = _Draft(_events, _sessions, _families);
    for (final id in after.touchedEvents) {
      final prev = before.events.where((e) => e.id == id).firstOrNull;
      prev == null ? d.removeEvent(id) : d.putEvent(prev.copyWith(updatedAt: now));
    }
    for (final id in after.touchedSessions) {
      final prev = before.sessions.where((s) => s.id == id).firstOrNull;
      prev == null ? d.removeSession(id) : d.putSession(prev.copyWith(updatedAt: now));
    }
    for (final id in after.touchedFamilies) {
      final prev = before.families.where((f) => f.id == id).firstOrNull;
      prev == null ? d.removeFamily(id) : d.putFamily(prev.copyWith(updatedAt: now));
    }
    try {
      await _save(d);
    } catch (e, st) {
      _log.error('Failed to undo', e, st);
    }
  }

  Future<void> _delete(DbRecord r) {
    final now = DateTime.now();
    return _mutate(r.table == 'attendance' ? 'Mark deleted' : 'Deleted ${r.title}', (d) {
      switch (r.table) {
        case 'events':
          final e = d.events.firstWhere((e) => e.id == r.id);
          e.deletedAt == null ? d.putEvent(e.copyWith(deletedAt: now, updatedAt: now)) : d.removeEvent(e.id);
        case 'sessions':
          final s = d.sessions.firstWhere((s) => s.id == r.id);
          s.deletedAt == null ? d.putSession(s.copyWith(deletedAt: now, updatedAt: now)) : d.removeSession(s.id);
        case 'families':
          final f = d.families.firstWhere((f) => f.id == r.id);
          f.deletedAt == null ? d.putFamily(f.copyWith(deletedAt: now, updatedAt: now)) : d.removeFamily(f.id);
        case 'members':
          for (final f in d.families.where((f) => f.members.any((m) => m.id == r.id)).toList()) {
            d.putFamily(f.copyWith(
              members: [
                for (final m in f.members)
                  if (m.id != r.id)
                    m
                  else if (m.deletedAt == null)
                    m.copyWith(deletedAt: now, updatedAt: now),
              ],
              updatedAt: now,
            ));
          }
        case 'attendance':
          final s = d.sessions.firstWhere((s) => s.id == r.fields['session_id']);
          final i = _markIndex(s, r);
          if (i != -1) {
            d.putSession(s.copyWith(records: [...s.records]..removeAt(i), updatedAt: now));
          }
      }
    });
  }

  Future<void> _restore(DbRecord r) {
    final now = DateTime.now();
    return _mutate('Restored ${r.title}', (d) {
      switch (r.table) {
        case 'events':
          final e = d.events.firstWhere((e) => e.id == r.id);
          d.putEvent(e.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'sessions':
          final s = d.sessions.firstWhere((s) => s.id == r.id);
          d.putSession(s.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'families':
          final f = d.families.firstWhere((f) => f.id == r.id);
          d.putFamily(f.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'members':
          final f = d.families.firstWhere((f) => f.members.any((m) => m.id == r.id));
          d.putFamily(f.copyWith(
            clearDeletedAt: true,
            updatedAt: now,
            members: [
              for (final m in f.members)
                m.id == r.id ? m.copyWith(clearDeletedAt: true, updatedAt: now) : m,
            ],
          ));
      }
    });
  }

  Future<void> _editMark(DbRecord r, String message, SessionRecord Function(SessionRecord mark) change) {
    return _mutate(message, (d) {
      final s = d.sessions.firstWhere((s) => s.id == r.fields['session_id']);
      final i = _markIndex(s, r);
      if (i == -1) return;
      d.putSession(s.copyWith(
        records: [...s.records]..[i] = change(s.records[i]),
        updatedAt: DateTime.now(),
      ));
    });
  }

  int _markIndex(Session s, DbRecord r) => InspectorIndex.markIndex(
        s,
        memberId: r.fields['member_id'] == '—' ? null : r.fields['member_id'],
        attendee: r.fields['attendee']!,
        recordedAtMs: int.parse(r.fields['recordedAtMs']!),
      );

  Widget? _detailsFor(DbRecord r, InspectorIndex index) {
    if (r.table == 'sessions') {
      final s = index.session(r.id);
      return s == null ? null : SessionContext(session: s, index: index);
    }
    if (r.table != 'attendance') return null;
    final s = index.session(r.fields['session_id']);
    if (s == null) return null;
    final i = _markIndex(s, r);
    if (i == -1) return null;
    return MarkContext(
      recordKey: r.id,
      session: s,
      mark: s.records[i],
      index: index,
      onStatus: (status) => _editMark(
        r,
        'Marked ${status.label.toLowerCase()}',
        (m) => m.copyWith(status: status),
      ),
      onLink: (member) => _editMark(
        r,
        'Linked to ${member.displayName}',
        (m) => m.copyWith(memberId: member.id, attendee: member.displayName),
      ),
      onGuest: () => _editMark(
        r,
        'Kept as guest',
        (m) => SessionRecord(
          attendee: m.attendee,
          status: m.status,
          recordedAt: m.recordedAt,
          recordedBy: m.recordedBy,
          isLate: m.isLate,
        ),
      ),
    );
  }

  List<Widget> _actionsFor(DbRecord r) {
    final c = context.conv;
    final hidden = r.flag == 'hidden';
    Widget action(String key, IconData icon, String label, VoidCallback onPressed, {bool destructive = false}) {
      final color = destructive ? c.absent : c.ink;
      return TextButton.icon(
        key: ValueKey(key),
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(
          backgroundColor: destructive ? c.absent.withValues(alpha: 0.12) : c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      );
    }

    return [
      if (_needsReview(r))
        action('dismiss_btn_${r.id}', Icons.check, 'Not an issue', () => _setDismissed(r, true)),
      if (r.isIssue && !_needsReview(r))
        action('undismiss_btn_${r.id}', Icons.flag_outlined, 'Review again', () => _setDismissed(r, false)),
      if (hidden && r.table != 'attendance')
        action('restore_btn_${r.id}', Icons.restore, 'Restore', () => _restore(r)),
      action(
        'delete_btn_${r.id}',
        Icons.delete_outline,
        hidden && r.table != 'attendance' ? 'Delete permanently' : 'Delete record',
        () => _handleDeleteRecord(r),
        destructive: true,
      ),
    ];
  }

  void _showBulkMergeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _BulkMaintenanceModal(
          attendanceRepository: widget.attendanceRepository,
          sessionRepository: widget.sessionRepository,
          onComplete: () async {
            await _loadData();
          },
        );
      },
    );
  }

  Future<void> _handleDeleteRecord(DbRecord r) async {
    if (r.table != 'members') {
      final what = r.table == 'attendance'
          ? 'the attendance mark for "${r.fields['attendee']}" from "${r.fields['formatted_date'] ?? r.fields['date']}"'
          : '"${r.title}"';
      final permanent = r.flag == 'hidden' && r.table != 'attendance';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final c = context.conv;
          return AlertDialog(
            backgroundColor: c.card,
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: c.absent),
                const SizedBox(width: 12),
                Text(
                  r.table == 'attendance' ? 'Delete attendance mark?' : 'Delete record?',
                  style: TextStyle(color: c.ink),
                ),
              ],
            ),
            content: Text(
              permanent
                  ? 'This permanently removes $what, which is already deleted in the app.'
                  : 'This deletes $what. You can undo it right after.',
              style: TextStyle(color: c.ink3, fontSize: 13.5, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: c.ink2)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: c.absent),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    } else if (r.table == 'members') {
      final linkedSessions = _memberUsageMap[r.id] ?? [];
      if (linkedSessions.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            final c = context.conv;
            return AlertDialog(
              backgroundColor: c.card,
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.absent),
                  const SizedBox(width: 12),
                  Text(
                    'Historical Data Alert',
                    style: TextStyle(color: c.ink),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.title} is linked to ${linkedSessions.length} past session reports:',
                    style: TextStyle(color: c.ink, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: c.cardSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...linkedSessions.take(3).map((session) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.event_note, size: 16, color: c.ink3),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: c.ink,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(session.date),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.ink3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (linkedSessions.length > 3)
                          Text(
                            '... and ${linkedSessions.length - 3} more',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: c.ink3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deleting them from the roster will make them appear as a "Visitor" in those reports, but their data will NOT be deleted.',
                    style: TextStyle(color: c.ink3, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text('Do you want to proceed?', style: TextStyle(color: c.ink, fontSize: 14)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TextStyle(color: c.ink2)),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: c.absent),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
        if (confirmed != true) return;
      }
    }

    await _delete(r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    // Filter out locally deleted records
    final live = _allRecords.toList();

    // Counts mapping
    final counts = <String, int>{'all': live.length};
    for (final tableId in ['events', 'sessions', 'members', 'families', 'attendance']) {
      counts[tableId] = live.where((r) => r.table == tableId).length;
    }
    counts['photos'] = 0;

    final issueTotal = live.where(_needsReview).length;
    final inspectorIndex = InspectorIndex(events: _events, sessions: _sessions, families: _families);

    // Filter results
    final ql = _searchQuery.trim().toLowerCase();
    final results = live.where((r) {
      if (_selectedTable != 'all' && r.table != _selectedTable) return false;
      if (_issuesOnly && !_needsReview(r)) return false;
      if (ql.isEmpty) return true;
      final hay = [r.id, r.table, r.title, r.meta, r.flag ?? '', ...r.fields.values].join(' ').toLowerCase();
      return hay.contains(ql);
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const ConvEyebrow('Backup data'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('bulk_merge_names_button'),
            tooltip: 'Bulk Rename & Merge',
            icon: Icon(Icons.merge_type_rounded, color: c.ink),
            onPressed: _showBulkMergeDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildSkeleton(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header title & subtitle
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Storage inspector',
                        style: AppTypography.fraunces(
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Every record in the on-device database — including rows the app doesn\'t display. Search to find something you saw in an export but not in the app.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.ink3,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search field
                      Container(
                        decoration: BoxDecoration(
                          color: c.cardSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: c.ink3, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: c.ink, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search records, ids, fields…',
                                  hintStyle: TextStyle(color: c.ink3),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                child: Icon(Icons.close, color: c.ink3, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Table filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    children: [
                      _buildTableChip('All', 'all', counts['all'] ?? 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Events', 'events', counts['events'] ?? 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Sessions', 'sessions', counts['sessions'] ?? 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Members', 'members', counts['members'] ?? 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Families', 'families', counts['families'] ?? 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Photos', 'photos', 0),
                      const SizedBox(width: 8),
                      _buildTableChip('Attendance', 'attendance', counts['attendance'] ?? 0),
                    ],
                  ),
                ),

                // Results counter and Issues toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${results.length} ',
                                style: TextStyle(
                                  color: c.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: results.length == 1 ? 'record' : 'records',
                                style: TextStyle(color: c.ink3),
                              ),
                              if (issueTotal > 0) ...[
                                TextSpan(
                                  text: ' · ',
                                  style: TextStyle(color: c.ink3),
                                ),
                                TextSpan(
                                  text: '$issueTotal to review',
                                  style: TextStyle(
                                    color: c.absent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _issuesOnly = !_issuesOnly;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _issuesOnly
                                ? c.absent.withValues(alpha: 0.14)
                                : Colors.transparent,
                            border: Border.all(
                              color: _issuesOnly
                                  ? c.absent.withValues(alpha: 0.4)
                                  : c.hair,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _issuesOnly ? c.absent : c.ink3,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Only issues',
                                style: TextStyle(
                                  color: _issuesOnly ? c.absent : c.ink3,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Records List
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          0,
                          22,
                          32,
                        ),
                        children: [
                          results.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 46),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: c.cardSoft,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(Icons.search, color: c.ink4, size: 24),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          'No records match',
                                          style: TextStyle(
                                            color: c.ink2,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Try another table or clear the search.',
                                          style: TextStyle(color: c.ink3, fontSize: 12.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  children: results.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final r = entry.value;
                                    final key = r.uniqueKey;
                                    return _RecordRow(
                                      key: ValueKey('${r.table}_${r.id}_$index'),
                                      record: r,
                                      isExpanded: _openRecordId == key,
                                      onTap: () {
                                        setState(() {
                                          _openRecordId = _openRecordId == key ? null : key;
                                        });
                                      },
                                      onCopy: () {
                                        Clipboard.setData(ClipboardData(text: r.id));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Copied ${r.id}'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      details: _openRecordId == key ? _detailsFor(r, inspectorIndex) : null,
                                      actions: _openRecordId == key ? _actionsFor(r) : const [],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTableChip(String label, String tableId, int count) {
    final c = context.conv;
    final isSelected = _selectedTable == tableId;
    final bg = isSelected ? c.primary : c.cardSoft;
    final fg = isSelected ? c.onPrimary : c.ink2;

    return GestureDetector(
      key: ValueKey('chip_$tableId'),
      onTap: () {
        setState(() {
          _selectedTable = tableId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? fg.withValues(alpha: 0.85) : c.ink3,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      children: [
        AppShimmer(
          width: 200,
          height: 36,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 10),
        AppShimmer(
          width: double.infinity,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 6),
        AppShimmer(
          width: double.infinity,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 20),
        AppShimmer(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.circular(14),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              4,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppShimmer(
                  width: 70 + (index * 10).toDouble(),
                  height: 32,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppShimmer(
              width: 120,
              height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
            AppShimmer(
              width: 100,
              height: 28,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppShimmer(
              width: double.infinity,
              height: 72,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    super.key,
    required this.record,
    required this.isExpanded,
    required this.onTap,
    required this.onCopy,
    this.details,
    this.actions = const [],
  });

  final DbRecord record;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  /// Context that explains the record (session, duplicates, link candidates).
  final Widget? details;

  /// Record actions (dismiss, restore, delete), shown beside Copy ID.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    final isOrphan = record.flag == 'orphan';
    final isHidden = record.flag == 'hidden';
    final isDuplicate = record.flag == 'duplicate';
    final isFlagged = record.flag != null;

    Color iconColor = c.ink3;
    Color iconBg = c.card;
    Color labelColor = c.ink3;
    String badgeText = '';
    Color badgeBg = Colors.transparent;
    Color badgeFg = Colors.transparent;

    if (isOrphan) {
      iconColor = c.absent;
      labelColor = c.absent;
      badgeText = 'ORPHANED';
      badgeFg = c.absent;
      badgeBg = c.absent.withValues(alpha: 0.15);
    } else if (isHidden) {
      iconColor = c.clayDeep;
      labelColor = c.clayDeep;
      badgeText = 'HIDDEN';
      badgeFg = c.clayDeep;
      badgeBg = c.clayDeep.withValues(alpha: 0.15);
    } else if (isDuplicate) {
      const amber = Color(0xFFD97706);
      iconColor = amber;
      labelColor = amber;
      badgeText = 'DUPLICATE';
      badgeFg = amber;
      badgeBg = amber.withValues(alpha: 0.15);
    }

    IconData icon;
    switch (record.table) {
      case 'events':
        icon = Icons.access_time;
        break;
      case 'sessions':
        icon = Icons.check_circle_outline;
        break;
      case 'members':
        icon = Icons.person_outline;
        break;
      case 'families':
        icon = Icons.people_outline;
        break;
      case 'attendance':
        icon = Icons.list_alt;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? c.hair : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              record.table.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: c.ink4,
                              ),
                            ),
                            if (isFlagged) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: badgeFg,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.title.isEmpty ? '(empty)' : record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              record.id.length > 10
                                  ? '${record.id.substring(0, 10)}...'
                                  : record.id,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: c.ink3,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 6),
                            Text('·', style: TextStyle(color: c.ink4)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                record.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: c.ink3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Transform.rotate(
                    angle: isExpanded ? 1.57 : 0.0,
                    child: Icon(
                      Icons.chevron_right,
                      color: c.ink4,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.hair, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (record.note != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: labelColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        record.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: labelColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Column(
                      children: record.fields.entries.map((entry) {
                        final isLast = record.fields.keys.last == entry.key;
                        final isEmpty = entry.value == '' || entry.value == '—';
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: isLast
                                  ? BorderSide.none
                                  : BorderSide(color: c.hair, width: 1.0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: c.ink3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  entry.value.isEmpty ? 'null' : entry.value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: isEmpty ? c.ink4 : c.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (details != null) ...[
                    details!,
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy ID'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.ink,
                          side: BorderSide(color: c.hair),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Working copies of the inspector's data for one edit, recording which
/// entities the edit touched so only those files are saved (and undone).
class _Draft {
  _Draft(List<Event> events, List<Session> sessions, List<Family> families)
      : events = List.of(events),
        sessions = List.of(sessions),
        families = List.of(families);

  final List<Event> events;
  final List<Session> sessions;
  final List<Family> families;
  final touchedEvents = <String>{};
  final touchedSessions = <String>{};
  final touchedFamilies = <String>{};

  static void _put<T>(List<T> list, T item, bool Function(T) same) {
    final i = list.indexWhere(same);
    i == -1 ? list.add(item) : list[i] = item;
  }

  void putEvent(Event e) {
    _put(events, e, (x) => x.id == e.id);
    touchedEvents.add(e.id);
  }

  void removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    touchedEvents.add(id);
  }

  void putSession(Session s) {
    _put(sessions, s, (x) => x.id == s.id);
    touchedSessions.add(s.id);
  }

  void removeSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    touchedSessions.add(id);
  }

  void putFamily(Family f) {
    _put(families, f, (x) => x.id == f.id);
    touchedFamilies.add(f.id);
  }

  void removeFamily(String id) {
    families.removeWhere((f) => f.id == id);
    touchedFamilies.add(id);
  }
}

enum _BulkMode { merge, rename }

class _BulkMaintenanceModal extends StatefulWidget {
  const _BulkMaintenanceModal({
    required this.attendanceRepository,
    required this.sessionRepository,
    required this.onComplete,
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository sessionRepository;
  final Future<void> Function() onComplete;

  @override
  State<_BulkMaintenanceModal> createState() => _BulkMaintenanceModalState();
}

class _BulkMaintenanceModalState extends State<_BulkMaintenanceModal> {
  _BulkMode _mode = _BulkMode.merge;
  bool _isLoading = true;
  bool _isExecuting = false;

  List<Member> _rosterMembers = [];
  List<String> _attendeeNames = [];

  String? _selectedSourceMemberId;
  String _sourceName = '';
  String? _selectedTargetMemberId;
  String _targetName = '';
  String _renameNewName = '';
  bool _updateRoster = true;

  BulkDryRunResult? _dryRunResult;
  String? _dryRunError;

  late final BulkMaintenanceService _service;

  @override
  void initState() {
    super.initState();
    _service = BulkMaintenanceService(
      attendanceRepository: widget.attendanceRepository,
      sessionRepository: widget.sessionRepository,
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final attRepo = widget.attendanceRepository;
      final families = attRepo is LocalJsonAttendanceRepository
          ? await attRepo.fetchAllFamilies()
          : await attRepo.fetchFamilies();

      final members = families
          .expand((f) => f.members)
          .where((m) => m.deletedAt == null)
          .toList()
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      final sesRepo = widget.sessionRepository;
      final sessions = sesRepo is LocalJsonSessionRepository
          ? await sesRepo.fetchAllSessions()
          : await sesRepo.loadSessions();

      final attendees = <String>{};
      for (final s in sessions) {
        for (final r in s.records) {
          final trimmed = r.attendee.trim();
          if (trimmed.isNotEmpty) attendees.add(trimmed);
        }
      }
      for (final m in members) {
        attendees.add(m.displayName.trim());
      }
      final sortedAttendees = attendees.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _rosterMembers = members;
          _attendeeNames = sortedAttendees;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runDryRun() async {
    setState(() {
      _dryRunResult = null;
      _dryRunError = null;
    });

    if (_mode == _BulkMode.merge) {
      if (_sourceName.trim().isEmpty || _targetName.trim().isEmpty) {
        setState(() => _dryRunError = 'Please select both source and target names.');
        return;
      }
      if (_sourceName.trim().toLowerCase() == _targetName.trim().toLowerCase()) {
        setState(() => _dryRunError = 'Source and target names cannot be identical.');
        return;
      }

      try {
        final result = await _service.simulateMerge(
          sourceIdentifier: _selectedSourceMemberId,
          sourceName: _sourceName.trim(),
          targetMemberId: _selectedTargetMemberId,
          targetName: _targetName.trim(),
          updateRoster: _updateRoster,
        );
        if (mounted) setState(() => _dryRunResult = result);
      } catch (e) {
        if (mounted) setState(() => _dryRunError = 'Dry run simulation failed: $e');
      }
    } else {
      if (_sourceName.trim().isEmpty || _renameNewName.trim().isEmpty) {
        setState(() => _dryRunError = 'Please provide an old name and a new name.');
        return;
      }
      if (_sourceName.trim().toLowerCase() == _renameNewName.trim().toLowerCase()) {
        setState(() => _dryRunError = 'Old name and new name cannot be identical.');
        return;
      }

      try {
        final result = await _service.simulateRename(
          oldName: _sourceName.trim(),
          newName: _renameNewName.trim(),
          memberId: _selectedSourceMemberId,
          updateRoster: _updateRoster,
        );
        if (mounted) setState(() => _dryRunResult = result);
      } catch (e) {
        if (mounted) setState(() => _dryRunError = 'Dry run simulation failed: $e');
      }
    }
  }

  Future<void> _execute() async {
    setState(() => _isExecuting = true);
    try {
      if (_mode == _BulkMode.merge) {
        await _service.executeMerge(
          sourceIdentifier: _selectedSourceMemberId,
          sourceName: _sourceName.trim(),
          targetMemberId: _selectedTargetMemberId,
          targetName: _targetName.trim(),
          updateRoster: _updateRoster,
        );
      } else {
        await _service.executeRename(
          oldName: _sourceName.trim(),
          newName: _renameNewName.trim(),
          memberId: _selectedSourceMemberId,
          updateRoster: _updateRoster,
        );
      }

      await widget.onComplete();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mode == _BulkMode.merge
                  ? 'Successfully merged "$_sourceName" into "$_targetName"'
                  : 'Successfully renamed "$_sourceName" to "$_renameNewName"',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExecuting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
        ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.hair,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.merge_type_rounded, color: c.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bulk Update & Merge',
                              style: AppTypography.fraunces(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: c.ink,
                              ),
                            ),
                            Text(
                              'Static history safe · Dry-run verified',
                              style: TextStyle(fontSize: 12, color: c.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Mode Selector Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: c.cardSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey('bulk_mode_merge_tab'),
                            onTap: () {
                              setState(() {
                                _mode = _BulkMode.merge;
                                _dryRunResult = null;
                                _dryRunError = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mode == _BulkMode.merge ? c.card : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Merge Two Names',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _mode == _BulkMode.merge
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _mode == _BulkMode.merge ? c.ink : c.ink3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            key: const ValueKey('bulk_mode_rename_tab'),
                            onTap: () {
                              setState(() {
                                _mode = _BulkMode.rename;
                                _dryRunResult = null;
                                _dryRunError = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mode == _BulkMode.rename ? c.card : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Rename Name',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _mode == _BulkMode.rename
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: _mode == _BulkMode.rename ? c.ink : c.ink3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Source Name Input
                  Text(
                    _mode == _BulkMode.merge ? 'Source Person (to be merged):' : 'Current Name:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink2),
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return _attendeeNames;
                      return _attendeeNames.where((n) => n
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (val) {
                      final match = _rosterMembers.cast<Member?>().firstWhere(
                            (m) => m?.displayName.toLowerCase() == val.toLowerCase(),
                            orElse: () => null,
                          );
                      setState(() {
                        _sourceName = val;
                        _selectedSourceMemberId = match?.id;
                        _dryRunResult = null;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        key: const ValueKey('bulk_source_name_input'),
                        controller: controller,
                        focusNode: focusNode,
                        style: TextStyle(color: c.ink, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. Bob Smith',
                          hintStyle: TextStyle(color: c.ink3),
                          filled: true,
                          fillColor: c.cardSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) {
                          final match = _rosterMembers.cast<Member?>().firstWhere(
                                (m) => m?.displayName.toLowerCase() == val.trim().toLowerCase(),
                                orElse: () => null,
                              );
                          setState(() {
                            _sourceName = val;
                            _selectedSourceMemberId = match?.id;
                            _dryRunResult = null;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  if (_mode == _BulkMode.merge) ...[
                    // Target Name Input
                    Text(
                      'Target Person (to keep):',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink2),
                    ),
                    const SizedBox(height: 6),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return _attendeeNames;
                        return _attendeeNames.where((n) => n
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (val) {
                        final match = _rosterMembers.cast<Member?>().firstWhere(
                              (m) => m?.displayName.toLowerCase() == val.toLowerCase(),
                              orElse: () => null,
                            );
                        setState(() {
                          _targetName = val;
                          _selectedTargetMemberId = match?.id;
                          _dryRunResult = null;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          key: const ValueKey('bulk_target_name_input'),
                          controller: controller,
                          focusNode: focusNode,
                          style: TextStyle(color: c.ink, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. Robert Smith',
                            hintStyle: TextStyle(color: c.ink3),
                            filled: true,
                            fillColor: c.cardSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onChanged: (val) {
                            final match = _rosterMembers.cast<Member?>().firstWhere(
                                  (m) => m?.displayName.toLowerCase() == val.trim().toLowerCase(),
                                  orElse: () => null,
                                );
                            setState(() {
                              _targetName = val;
                              _selectedTargetMemberId = match?.id;
                              _dryRunResult = null;
                            });
                          },
                        );
                      },
                    ),
                  ] else ...[
                    // Rename Target Input
                    Text(
                      'New Display Name:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink2),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('bulk_rename_new_name_input'),
                      style: TextStyle(color: c.ink, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Robert Smith',
                        hintStyle: TextStyle(color: c.ink3),
                        filled: true,
                        fillColor: c.cardSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        _renameNewName = val;
                        _dryRunResult = null;
                      },
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Option to also apply to active roster
                  InkWell(
                    key: const ValueKey('bulk_update_roster_checkbox'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _updateRoster = !_updateRoster;
                        _dryRunResult = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _updateRoster,
                              activeColor: c.primary,
                              onChanged: (val) {
                                setState(() {
                                  _updateRoster = val ?? true;
                                  _dryRunResult = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _mode == _BulkMode.merge
                                  ? 'Also remove source member from roster'
                                  : 'Also rename matching roster member',
                              style: TextStyle(fontSize: 13, color: c.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Dry Run Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('bulk_dry_run_button'),
                      onPressed: _runDryRun,
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Calculate Dry Run'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.primary,
                        side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  if (_dryRunError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.absent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dryRunError!,
                        style: TextStyle(color: c.absent, fontSize: 12.5),
                      ),
                    ),
                  ],

                  if (_dryRunResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      key: const ValueKey('bulk_dry_run_results_card'),
                      decoration: BoxDecoration(
                        color: c.cardSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: c.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Dry-Run Validation Preview',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: c.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDryRunRow('Past sessions affected:', '${_dryRunResult!.sessionsAffected}'),
                          _buildDryRunRow('Historical marks updated:', '${_dryRunResult!.marksUpdated}'),
                          if (_dryRunResult!.collisionsPruned > 0)
                            _buildDryRunRow(
                              'Intra-session collisions pruned:',
                              '${_dryRunResult!.collisionsPruned}',
                              highlightColor: const Color(0xFFD97706),
                            ),
                          if (_dryRunResult!.rosterMembersRemoved > 0)
                            _buildDryRunRow('Roster members removed:', '${_dryRunResult!.rosterMembersRemoved}'),
                          if (_dryRunResult!.rosterMembersUpdated > 0)
                            _buildDryRunRow('Roster members renamed:', '${_dryRunResult!.rosterMembersUpdated}'),

                          if (_dryRunResult!.affectedSessionTitles.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Sample Sessions Affected:',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.ink3),
                            ),
                            const SizedBox(height: 4),
                            ...(_dryRunResult!.affectedSessionTitles.take(3).map((title) {
                              return Text(
                                '• $title',
                                style: TextStyle(fontSize: 11.5, color: c.ink2),
                              );
                            })),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('bulk_execute_button'),
                        onPressed: _isExecuting ? null : _execute,
                        icon: _isExecuting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.done_all, size: 18),
                        label: Text(
                          _isExecuting
                              ? 'Applying...'
                              : 'Confirm & Apply (${_dryRunResult!.totalOperations} changes)',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildDryRunRow(String label, String value, {Color? highlightColor}) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: c.ink2)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlightColor ?? c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

