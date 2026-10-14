import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../../../core/design/widgets/skeleton_switcher.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/maintenance/bulk_maintenance_service.dart';
import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../domain/storage_inspector.dart';
import 'inspector_context.dart';

export '../domain/storage_inspector.dart' show DbRecord, StorageInspector;

final _log = AppLogger('ManageBackup');

class ManageBackupDataPage extends StatefulWidget {
  const ManageBackupDataPage({
    super.key,
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    this.inspector,
    this.disableAnimations = false,
  });

  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final StorageInspector? inspector;
  final bool disableAnimations;

  @override
  State<ManageBackupDataPage> createState() => _ManageBackupDataPageState();
}

class _ManageBackupDataPageState extends State<ManageBackupDataPage> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  late final StorageInspector _inspector;

  String _selectedTable = 'all';
  bool _issuesOnly = false;
  String _searchQuery = '';
  String? _openRecordId;

  @override
  void initState() {
    super.initState();
    _inspector = widget.inspector ??
        StorageInspector(
          attendanceRepository: widget.attendanceRepository,
          eventRepository: widget.eventRepository,
          sessionRepository: widget.sessionRepository,
        );
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
      await _inspector.scan();

      // Minimum loading duration for visual consistency
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 800) - elapsed;
      if (remaining > Duration.zero && !widget.disableAnimations) {
        await Future.delayed(remaining);
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, st) {
      _log.error('Failed to load backup data', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _needsReview(DbRecord r) => _inspector.needsReview(r);

  Future<void> _setDismissed(DbRecord r, bool dismissed) async {
    await _inspector.setDismissed(r, dismissed);
    if (mounted) setState(() {});
  }

  Future<void> _mutate(String message, Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Undo', onPressed: _undo),
        ));
    } catch (e, st) {
      _log.error('Failed to update records', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update records: $e')),
      );
    }
  }

  Future<void> _undo() async {
    try {
      await _inspector.undo();
      if (mounted) setState(() {});
    } catch (e, st) {
      _log.error('Failed to undo', e, st);
    }
  }

  Future<void> _delete(DbRecord r) =>
      _mutate(r.table == 'attendance' ? 'Mark deleted' : 'Deleted ${r.title}',
          () => _inspector.deleteRecord(r));

  Future<void> _restore(DbRecord r) =>
      _mutate('Restored ${r.title}', () => _inspector.restoreRecord(r));

  Future<void> _editMark(
          DbRecord r, String message, SessionRecord Function(SessionRecord mark) change) =>
      _mutate(message, () => _inspector.editMark(r, change));

  int _markIndex(Session s, DbRecord r) => _inspector.markIndex(s, r);

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
      final linkedSessions = _inspector.memberUsageMap[r.id] ?? [];
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
    final live = _inspector.allRecords.toList();

    // Counts mapping
    final counts = <String, int>{'all': live.length};
    for (final tableId in ['events', 'sessions', 'members', 'families', 'attendance']) {
      counts[tableId] = live.where((r) => r.table == tableId).length;
    }
    counts['photos'] = 0;

    final issueTotal = live.where(_needsReview).length;
    final inspectorIndex = _inspector.index;

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
      body: SkeletonSwitcher(
        loading: _isLoading,
        disableAnimations: widget.disableAnimations,
        skeleton: _buildSkeleton(context),
        child: Column(
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
      final families = await attRepo.fetchAllFamilies();

      final members = families
          .expand((f) => f.members)
          .where((m) => m.deletedAt == null)
          .toList()
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      final sesRepo = widget.sessionRepository;
      final sessions = await sesRepo.fetchAllSessions();

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

