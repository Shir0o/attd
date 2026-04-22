import 'package:flutter/material.dart';

import '../../../../core/design/app_shimmer.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../settings/data/drive_service.dart';
import 'add_guest_sheet.dart';
import 'session_summary_page.dart';
import 'swipeable_card.dart';

class AttendanceDeckPage extends StatefulWidget {
  const AttendanceDeckPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
    required this.attendanceRepository,
    required this.eventRepository,
    this.driveService,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final DriveService? driveService;
  final bool disableAnimations;

  @override
  State<AttendanceDeckPage> createState() => _AttendanceDeckPageState();
}

class _AttendanceDeckPageState extends State<AttendanceDeckPage> {
  late Session _currentSession;
  late int _currentIndex;
  final List<Member> _remainingMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    debugPrint('DEBUG: AttendanceDeckPage.initState: session=${_currentSession.id}, title=${_currentSession.title}, recordsCount=${_currentSession.records.length}');
    debugPrint('DEBUG: AttendanceDeckPage.initState: membersCount=${widget.members.length}, members=${widget.members.map((m) => m.displayName).toList()}');

    _remainingMembers.addAll(widget.members);
    _currentIndex = 0;

    final recordedIds = _currentSession.records.map((r) => r.memberId).toSet();
    final recordedNames = _currentSession.records.map((r) => r.attendee).toSet();
    
    int firstUnrecorded = 0;
    for (int i = 0; i < widget.members.length; i++) {
      final member = widget.members[i];
      if (!recordedIds.contains(member.id) && !recordedNames.contains(member.displayName)) {
        firstUnrecorded = i;
        break;
      }
    }
    _currentIndex = firstUnrecorded;
    debugPrint('DEBUG: AttendanceDeckPage.initState: _currentIndex=$_currentIndex');

    if (widget.disableAnimations) {
      _isLoading = false;
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  Future<void> _recordAttendance(
    String? memberId,
    String attendeeName,
    AttendanceStatus status,
  ) async {
    // Create new record
    final newRecord = SessionRecord(
      memberId: memberId,
      attendee: attendeeName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User', // Placeholder
    );

    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    // Remove any existing record for this attendee if exists (overwrite)
    updatedRecords.removeWhere((r) => 
      (memberId != null && r.memberId == memberId) || 
      (r.attendee == attendeeName)
    );
    updatedRecords.add(newRecord);

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _currentSession = updatedSession;
      });
    }

    try {
      await widget.sessionRepository.saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e')),
        );
      }
    }
  }

  void _processAttendance(AttendanceStatus status) {
    final member = widget.members[_currentIndex];
    _recordAttendance(member.id, member.displayName, status);

    if (_currentIndex < widget.members.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Finished all members
      _finishAndNavigate();
    }
  }

  void _undo() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _finishAndNavigate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(
          session: _currentSession,
          members: widget.members,
          sessionRepository: widget.sessionRepository,
          attendanceRepository: widget.attendanceRepository,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMemberSheet(
        onAdd: (name, isPresent, isGuest, existingMember) {
          _recordAttendance(
            existingMember?.id,
            name,
            isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
          );
        },
        availableMembers: widget.members,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentIndex >= widget.members.length) {
        return Scaffold(
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Text('Session Complete'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: _finishAndNavigate,
                            child: const Text('Finalize Report'),
                        ),
                    ],
                ),
            ),
        );
    }

    final currentMember = widget.members[_currentIndex];
    final progress = (_currentIndex + 1) / widget.members.length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header Stack (Progress + Add Guest)
            Stack(
              children: [
                // Progress Bar
                Container(
                  height: 4,
                  width: double.infinity,
                  color: colorScheme.surfaceContainerHigh,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(999),
                          bottomRight: Radius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                // Cancel Button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, left: 16),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(_currentSession),
                      icon: const Icon(Icons.close),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Cancel',
                    ),
                  ),
                ),
                // Add Person Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: IconButton(
                      onPressed: _showAddMemberSheet,
                      icon: const Icon(Icons.person_add),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Add Person',
                    ),
                  ),
                ),
              ],
            ),

            // Card Area
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Background Cards (Visual effect)
                        Positioned.fill(
                          child: Transform.translate(
                            offset: const Offset(0, 32),
                            child: Transform.scale(
                              scale: 0.9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Positioned.fill(
                          child: Transform.translate(
                            offset: const Offset(0, 16),
                            child: Transform.scale(
                              scale: 0.95,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Main Card
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: AnimatedSwitcher(
                              duration: widget.disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 600),
                              child: _isLoading
                                  ? Container(
                                      key: const ValueKey('skeleton'),
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainer.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Center(
                                        child: AppShimmer(
                                          width: 96,
                                          height: 96,
                                          borderRadius: BorderRadius.circular(48),
                                          disableAnimations: widget.disableAnimations,
                                        ),
                                      ),
                                    )
                                  : SwipeableCard(
                                      key: ValueKey(
                                        currentMember.id,
                                      ), // Important for resetting state
                                      rightSwipeColor: colorScheme.primary,
                                      leftSwipeColor: colorScheme.error,
                                      onSwipeLeft: () => _processAttendance(
                                        AttendanceStatus.absent,
                                      ),
                                      onSwipeRight: () => _processAttendance(
                                        AttendanceStatus.present,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainer,
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Avatar
                                                Flexible(
                                                  child: Container(
                                                    width: 96,
                                                    height: 96,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.surfaceContainerHigh,
                                                      shape: BoxShape.circle,
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color: Colors.black12,
                                                          blurRadius: 2,
                                                          offset: Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    clipBehavior: Clip.antiAlias,
                                                    child: Center(
                                                      child: Text(
                                                        currentMember.displayName.isNotEmpty
                                                            ? currentMember.displayName[0]
                                                                  .toUpperCase()
                                                            : '?',
                                                        style: TextStyle(
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.bold,
                                                          color: colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                Text(
                                                  currentMember.displayName,
                                                  style: theme.textTheme.displaySmall?.copyWith(
                                                    color: colorScheme.onSurface,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Undo Button
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Material(
                      color: colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('undoButton'),
                        onTap: _currentIndex > 0 ? _undo : null,
                        child: Icon(
                          Icons.undo,
                          color: _currentIndex > 0
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Absent Button
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Material(
                      color: colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('absentButton'),
                        onTap: () => _processAttendance(AttendanceStatus.absent),
                        child: Icon(Icons.close, color: colorScheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Present Button
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Material(
                      color: colorScheme.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('presentButton'),
                        onTap: () => _processAttendance(AttendanceStatus.present),
                        child: Icon(Icons.check, color: colorScheme.onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
