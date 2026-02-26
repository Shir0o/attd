import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/session.dart';
import '../../data/session_repository.dart';
import '../../data/session_version.dart';
import '../../data/session_record.dart';
import '../attendance/models/attendance_status.dart';

class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({
    super.key,
    required this.session,
    required this.repository,
  });

  final Session session;
  final SessionRepository repository;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  late Future<Session> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadLatest();
  }

  Future<Session> _loadLatest() async {
    final sessions = await widget.repository.loadSessions(includeDeleted: true);
    return sessions.firstWhere(
      (element) => element.id == widget.session.id,
      orElse: () => widget.session,
    );
  }

  Future<void> _revert(Session session) async {
    final reverted = await widget.repository.revertToPrevious(
      session.id,
      actor: 'You',
    );
    if (reverted == null) return;
    setState(() {
      _sessionFuture = Future.value(reverted);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reverted to previous version')),
    );
  }

  Future<void> _restoreToVersion(SessionVersion version) async {
    final restored = await widget.repository.restoreToVersion(
      version.sessionId,
      version.version,
      actor: 'You',
    );
    if (restored == null) return;
    setState(() {
      _sessionFuture = Future.value(restored);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored to version #${version.version}')),
    );
  }

  Future<void> _duplicate(Session session) async {
    final duplicated = await widget.repository.duplicate(
      session.id,
      actor: 'You',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Session duplicated as redo')));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: duplicated,
          repository: widget.repository,
        ),
      ),
    );
  }

  Widget _buildRecordTile(SessionRecord record) {
    return ListTile(
      leading: CircleAvatar(child: Text(record.attendee.characters.first)),
      title: Text(record.attendee),
      subtitle: Text(
        '${record.status.label} · ${DateFormat('HH:mm:ss').format(record.recordedAt)} '
        'by ${record.recordedBy}',
      ),
      trailing: Icon(
        record.status == AttendanceStatus.present
            ? Icons.check_circle
            : Icons.remove_circle_outline,
        color: record.status == AttendanceStatus.present
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  Widget _buildHistory(List<SessionVersion> versions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Revision history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...versions.map(
          (version) => ListTile(
            leading: CircleAvatar(child: Text('#${version.version}')),
            title: Text('Saved by ${version.actor}'),
            subtitle: Text(
              '${DateFormat('yyyy-MM-dd HH:mm:ss').format(version.recordedAt)} · ${version.isDeleted ? 'Deleted' : 'Active'}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.settings_backup_restore),
              tooltip: 'Restore to this version',
              onPressed: () => _restoreToVersion(version),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(session.title),
            actions: [
              IconButton(
                tooltip: 'Revert to previous',
                onPressed: session.currentVersion > 1
                    ? () => _revert(session)
                    : null,
                icon: const Icon(Icons.restore),
              ),
              IconButton(
                tooltip: 'Duplicate/redo session',
                onPressed: () => _duplicate(session),
                icon: const Icon(Icons.copy_all_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _sessionFuture = _loadLatest();
              });
              await _sessionFuture;
            },
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session date: ${session.sessionDate.toLocal().toString().split(' ').first}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Chip(
                            avatar: const Icon(Icons.calendar_today, size: 18),
                            label: Text('Version ${session.currentVersion}'),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            avatar: const Icon(Icons.person_outline, size: 18),
                            label: Text('Created by ${session.createdBy}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Attendance records',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                ...session.records.map(_buildRecordTile),
                const Divider(height: 1),
                FutureBuilder<List<SessionVersion>>(
                  future: widget.repository.history(session.id),
                  builder: (context, historySnapshot) {
                    if (!historySnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _buildHistory(historySnapshot.data!);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
