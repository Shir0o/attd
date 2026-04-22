import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_shimmer.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../../data/session_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';
import '../../../data/session.dart';

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

  List<Event> _events = [];
  List<Family> _families = [];
  List<Session> _sessions = [];
  final Map<String, List<({String title, DateTime date})>> _memberUsageMap = {};

  // To track what needs to be deleted
  final Set<String> _eventsToDelete = {};
  final Set<String> _membersToDelete = {}; // member id
  final Set<String> _sessionsToDelete = {};

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final startTime = DateTime.now();
    setState(() => _isLoading = true);
    try {
      // Optimize: Load data concurrently
      final results = await Future.wait([
        widget.attendanceRepository.fetchFamilies(),
        widget.eventRepository.streamEvents().first,
        widget.sessionRepository.loadSessions(),
      ]);

      final families = results[0] as List<Family>;
      final events = results[1] as List<Event>;
      final sessions = results[2] as List<Session>;

      final totalMembersCount = families.expand((f) => f.members).length;
      debugPrint('DEBUG: ManageBackupDataPage._loadData: events=${events.length}, members=$totalMembersCount, sessions=${sessions.length}');

      final usageMap = <String, List<({String title, DateTime date})>>{};
      for (final session in sessions) {
        for (final record in session.records) {
          if (record.memberId != null) {
            usageMap
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
          _memberUsageMap.clear();
          _memberUsageMap.addAll(usageMap);
          _isLoading = false;

          _eventsToDelete.clear();
          _membersToDelete.clear();
          _sessionsToDelete.clear();
        });
      }
    } catch (e) {
      print('Failed to load backup data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _totalRecords {
    final activeEvents = _events
        .where((e) => !_eventsToDelete.contains(e.id))
        .length;
    final activeMembers = _families
        .expand((f) => f.members)
        .where((m) => !_membersToDelete.contains(m.id))
        .length;
    final activeSessions = _sessions
        .where((s) => !_sessionsToDelete.contains(s.id))
        .length;
    return activeEvents + activeMembers + activeSessions;
  }

  String get _approximateSize {
    // Rough estimation based on records
    final total = _totalRecords;
    final kb = total * 1.5; // guesstimate
    if (kb > 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(1)} KB';
  }

  Future<void> _saveCleanedBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      // Optimize: Delete events and sessions concurrently
      await Future.wait([
        ..._eventsToDelete.map((id) => widget.eventRepository.deleteEvent(id)),
        ..._sessionsToDelete.map((id) => widget.sessionRepository.deleteSession(
              id,
              actor: 'ManageBackup Data',
            )),
      ]);

      // Delete selected members
      if (_membersToDelete.isNotEmpty) {
        final currentFamilies = await widget.attendanceRepository
            .fetchFamilies();
        final updatedFamilies = currentFamilies.map((f) {
          final updatedMembers = f.members
              .where((m) => !_membersToDelete.contains(m.id))
              .toList();
          return f.copyWith(members: updatedMembers);
        }).toList();
        await widget.attendanceRepository.saveFamilies(updatedFamilies);
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Backup cleaned successfully')),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Failed to save cleaned backup: $e');
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
      _loadData(); // reload on error
    }
  }

  bool _matchesSearch(String text) {
    if (_searchQuery.isEmpty) return true;
    return text.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter out deleted items
    final displayEvents = _events
        .where(
          (e) => !_eventsToDelete.contains(e.id) && _matchesSearch(e.title),
        )
        .toList();

    final displayMembers = _families
        .expand((f) => f.members)
        .where(
          (m) =>
              !_membersToDelete.contains(m.id) && _matchesSearch(m.displayName),
        )
        .toList();

    final displaySessions = _sessions
        .where(
          (s) => !_sessionsToDelete.contains(s.id) && _matchesSearch(s.title),
        )
        .toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Manage Backup Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? _buildSkeleton(context)
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.only(
                    bottom: 100,
                  ), // Space for bottom button
                  children: [
                    _buildSummaryCard(colorScheme),
                    _buildSearchBar(colorScheme),
                    if (displayEvents.isNotEmpty)
                      _buildEventsSection(displayEvents, colorScheme),
                    if (displayMembers.isNotEmpty)
                      _buildMembersSection(displayMembers, colorScheme),
                    if (displaySessions.isNotEmpty)
                      _buildSessionsSection(displaySessions, colorScheme),
                  ],
                ),
                if (_eventsToDelete.isNotEmpty ||
                    _membersToDelete.isNotEmpty ||
                    _sessionsToDelete.isNotEmpty)
                  _buildFloatingBottomAction(colorScheme),
              ],
            ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppShimmer(
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 24),
        AppShimmer(
          width: double.infinity,
          height: 56,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 32),
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmer(
                  width: 120,
                  height: 24,
                  borderRadius: BorderRadius.circular(24),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppShimmer(
                      width: double.infinity,
                      height: 72,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              child: Icon(
                Icons.storage,
                size: 64,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BACKUP SUMMARY',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Local Records Snapshot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy').format(DateTime.now()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIZE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _approximateSize,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECORDS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '$_totalRecords',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search records in backup',
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
    required ColorScheme colorScheme,
  }) {
    return Container(
      color: colorScheme.surface,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          key: ValueKey('delete_${title}_$subtitle'),
          icon: Icon(Icons.delete, color: colorScheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }

  Widget _buildEventsSection(List<Event> events, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Events', colorScheme),
        ...events.map(
          (e) => Column(
            children: [
              _buildListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.event, color: colorScheme.primary),
                ),
                title: e.title,
                subtitle:
                    '${e.frequency} • ${DateFormat('MMM dd, yyyy').format(e.createdAt)}',
                onDelete: () {
                  setState(() => _eventsToDelete.add(e.id));
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection(List<Member> members, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Members & Roster', colorScheme),
        ...members.map(
          (m) => Column(
            children: [
              _buildListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      m.displayName.isNotEmpty
                          ? m.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: m.displayName,
                subtitle: 'ID: #${m.id.substring(0, 4)}',
                onDelete: () async {
                  final linkedSessions = _memberUsageMap[m.id] ?? [];
                  if (linkedSessions.isNotEmpty) {
                    if (!mounted) return;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        final colorScheme = Theme.of(context).colorScheme;
                        return AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange),
                              SizedBox(width: 12),
                              Text('Historical Data Alert'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.displayName} is linked to ${linkedSessions.length} past session reports:',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ...linkedSessions.take(3).map((session) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Row(
                                            children: [
                                              Icon(Icons.event_note,
                                                  size: 16,
                                                  color: colorScheme
                                                      .onSurfaceVariant),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      session.title,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    Text(
                                                      DateFormat('MMM d, yyyy')
                                                          .format(session.date),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurfaceVariant,
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Deleting them from the roster will make them appear as a "Visitor" in those reports, but their data will NOT be deleted.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Do you want to proceed?'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Continue'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true) return;
                  }
                  setState(() => _membersToDelete.add(m.id));
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsSection(
    List<Session> sessions,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Attendance History', colorScheme),
        ...sessions.map(
          (s) => Column(
            children: [
              _buildListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.history,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                title: s.title,
                subtitle: DateFormat(
                  'MMM dd, yyyy hh:mm a',
                ).format(s.sessionDate),
                onDelete: () {
                  setState(() => _sessionsToDelete.add(s.id));
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBottomAction(ColorScheme colorScheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
          ),
        ),
        child: SafeArea(
          child: FilledButton.icon(
            key: const ValueKey('save_cleaned_backup_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: _isLoading ? null : _saveCleanedBackup,
            icon: const Icon(Icons.save),
            label: const Text(
              'Save Cleaned Backup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
