import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../../../core/logging/app_logger.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/data/local_event_repository.dart';
import '../../hub/domain/event.dart';
import '../../../data/session.dart';
import '../../../data/local_session_repository.dart';
import '../../../data/session_repository.dart';

final _log = AppLogger('ManageBackup');

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
  final String? flag; // 'hidden' | 'orphan' | null
  final String? note;
  final Map<String, String> fields;
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

      // Minimum loading duration for visual consistency
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 800) - elapsed;
      if (remaining > Duration.zero && !widget.disableAnimations) {
        await Future.delayed(remaining);
      }

      if (mounted) {
        setState(() {
          _families = families;
          _events = events;
          _sessions = sessions;
          _rebuildDbRecords();
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
    for (final family in _families) {
      for (final member in family.members) {
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

    // Map Attendance (marks)
    for (final session in _sessions) {
      for (final record in session.records) {
        final isSessionDeleted = session.deletedAt != null;
        final isMemberDeleted = record.memberId != null && !activeMemberIds.contains(record.memberId);

        String? flag;
        String? note;
        if (isSessionDeleted) {
          flag = 'hidden';
          note = 'This attendance mark belongs to a soft-deleted session.';
        } else if (isMemberDeleted) {
          flag = 'orphan';
          note = 'This attendance mark references member ID ${record.memberId}, who has been deleted or is missing from the roster.';
        }

        final recordKey = '${session.id}_${record.memberId ?? record.attendee}';

        records.add(DbRecord(
          id: recordKey,
          table: 'attendance',
          title: 'mark · ${record.status.name}',
          meta: '${session.title} · ${record.attendee}',
          flag: flag,
          note: note,
          fields: {
            'session_id': session.id,
            'member_id': record.memberId ?? '—',
            'attendee': record.attendee,
            'status': record.status.name,
            'recordedAt': DateFormat('yyyy-MM-dd HH:mm:ss').format(record.recordedAt),
            'recordedBy': record.recordedBy,
          },
        ));
      }
    }

    _allRecords = records;
  }

  Future<void> _deleteRecords(Set<DbRecord> recordsToDelete) async {
    setState(() => _isLoading = true);

    try {
      final List<Event> updatedEvents = List<Event>.from(_events);
      final List<Session> updatedSessions = List<Session>.from(_sessions);
      final List<Family> updatedFamilies = _families.map((f) {
        return f.copyWith(members: List<Member>.from(f.members));
      }).toList();

      bool eventsChanged = false;
      bool sessionsChanged = false;
      bool familiesChanged = false;

      for (final r in recordsToDelete) {
        if (r.table == 'events') {
          updatedEvents.removeWhere((e) => e.id == r.id);
          eventsChanged = true;
        } else if (r.table == 'sessions') {
          updatedSessions.removeWhere((s) => s.id == r.id);
          sessionsChanged = true;
        } else if (r.table == 'families') {
          updatedFamilies.removeWhere((f) => f.id == r.id);
          familiesChanged = true;
        } else if (r.table == 'members') {
          // Remove member from any family
          for (int i = 0; i < updatedFamilies.length; i++) {
            final f = updatedFamilies[i];
            final members = f.members;
            if (members.any((m) => m.id == r.id)) {
              final newMembers = members.where((m) => m.id != r.id).toList();
              updatedFamilies[i] = f.copyWith(members: newMembers);
              familiesChanged = true;
            }
          }
        } else if (r.table == 'attendance') {
          final sessionId = r.fields['session_id'];
          final memberId = r.fields['member_id'] == '—' ? null : r.fields['member_id'];
          final attendeeName = r.fields['attendee'];

          final sessionIndex = updatedSessions.indexWhere((s) => s.id == sessionId);
          if (sessionIndex != -1) {
            final s = updatedSessions[sessionIndex];
            final records = s.records.where((rec) {
              if (memberId != null) {
                return rec.memberId != memberId;
              } else {
                return rec.attendee != attendeeName;
              }
            }).toList();
            updatedSessions[sessionIndex] = s.copyWith(records: records);
            sessionsChanged = true;
          }
        }
      }

      // Save changes back to repositories
      final List<Future<void>> saveFutures = [];

      if (eventsChanged) {
        final evRepo = widget.eventRepository;
        if (evRepo is LocalJsonEventRepository) {
          saveFutures.add(evRepo.saveEvents(updatedEvents));
        } else {
          try {
            saveFutures.add((evRepo as dynamic).saveEvents(updatedEvents));
          } catch (_) {}
        }
      }

      if (sessionsChanged) {
        final sesRepo = widget.sessionRepository;
        if (sesRepo is LocalJsonSessionRepository) {
          saveFutures.add(sesRepo.saveSessions(updatedSessions));
        } else {
          try {
            saveFutures.add((sesRepo as dynamic).saveSessions(updatedSessions));
          } catch (_) {}
        }
      }

      if (familiesChanged) {
        saveFutures.add(widget.attendanceRepository.saveFamilies(updatedFamilies));
      }

      await Future.wait(saveFutures);

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recordsToDelete.length == 1
                  ? 'Record deleted'
                  : 'Cleaned up ${recordsToDelete.length} flagged records',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      _log.error('Failed to delete records', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete records: $e')),
        );
      }
    }
  }

  void _cleanupAllFlagged() {
    final flagged = _allRecords.where((r) => r.flag != null).toSet();
    if (flagged.isNotEmpty) {
      _deleteRecords(flagged);
    }
  }

  void _showCleanupConfirmation(int issueTotal) {
    final c = context.conv;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hair,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.absent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.cleaning_services, color: c.absent, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Clean up $issueTotal records?',
                style: AppTypography.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This deletes every hidden and orphaned record from the on-device database. It can\'t be undone — but no visible members, families or marked sessions are affected.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.ink3,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.ink,
                        side: BorderSide(color: c.hair),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _cleanupAllFlagged();
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Clean up'),
                      style: FilledButton.styleFrom(
                        backgroundColor: c.absent,
                        foregroundColor: c.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleDeleteRecord(DbRecord r) async {
    if (r.table == 'members') {
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

    await _deleteRecords({r});
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

    final issueTotal = live.where((r) => r.flag != null).length;

    // Filter results
    final ql = _searchQuery.trim().toLowerCase();
    final results = live.where((r) {
      if (_selectedTable != 'all' && r.table != _selectedTable) return false;
      if (_issuesOnly && r.flag == null) return false;
      if (ql.isEmpty) return true;
      final hay = [r.id, r.table, r.title, r.meta, ...r.fields.values].join(' ').toLowerCase();
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
      ),
      body: _isLoading
          ? _buildSkeleton(context)
          : Stack(
              children: [
                ListView(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: issueTotal > 0 ? 120 : 32,
                  ),
                  children: [
                    // Header title & subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
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
                          Text.rich(
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
                                    text: '$issueTotal flagged',
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
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _issuesOnly = !_issuesOnly;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _issuesOnly ? c.absent : c.ink3,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: results.isEmpty
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
                              children: results.map((r) {
                                return _RecordRow(
                                  key: ValueKey(r.id),
                                  record: r,
                                  isExpanded: _openRecordId == r.id,
                                  onTap: () {
                                    setState(() {
                                      _openRecordId = _openRecordId == r.id ? null : r.id;
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
                                  onDelete: () => _handleDeleteRecord(r),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
                if (issueTotal > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            c.bg,
                            c.bg,
                            c.bg.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.62, 1.0],
                        ),
                      ),
                      child: TextButton.icon(
                        key: const ValueKey('cleanup_flagged_records_button'),
                        onPressed: () => _showCleanupConfirmation(issueTotal),
                        icon: Icon(Icons.cleaning_services, color: c.absent),
                        label: Text(
                          'Clean up $issueTotal flagged records',
                          style: TextStyle(
                            color: c.absent,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: c.absent.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: c.absent.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
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
        Row(
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
    required this.onDelete,
    required this.onCopy,
  });

  final DbRecord record;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    final isOrphan = record.flag == 'orphan';
    final isHidden = record.flag == 'hidden';
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy ID'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.ink,
                            side: BorderSide(color: c.hair),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (isFlagged) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            key: ValueKey('delete_btn_${record.id}'),
                            onPressed: onDelete,
                            icon: Icon(Icons.delete_outline, size: 16, color: c.absent),
                            label: Text(
                              'Delete record',
                              style: TextStyle(color: c.absent, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: c.absent.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: c.absent.withValues(alpha: 0.26),
                                  width: 1.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
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
