import 'package:flutter/material.dart';

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import '../models/family.dart';
import '../data/attendance_repository.dart';
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
    this.disableAnimations = false,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
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
    // Filter members that are already recorded in the session?
    // The requirement is to show the deck.
    // If we assume we want to go through everyone, let's just use the full list.
    // Or, better, start with members who don't have a record yet?
    // For now, let's load all members into _remainingMembers to iterate through.
    // Ideally we'd filter out valid records, but for "The Deck" UI flow, maybe we always want to review?
    // Let's stick to: All members, but maybe sort or filter?
    // Simple approach: Start from index 0 of the provided members list.
    _remainingMembers.addAll(widget.members);
    _currentIndex = 0;

    // Remove members already present in the session records if we want to resume?
    // The design shows a linear flow. Let's find the first member without a record.
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

    // Snappier delay to allow Hero to finish without making the app feel slow
    // Mandated minimum of 800ms for visual consistency
    final delay = widget.disableAnimations ? Duration.zero : const Duration(milliseconds: 800);
    Future.delayed(delay, () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
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

    // Update session locally
    // If record exists, replace it. If not, add it.
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    final existingIndex = updatedRecords.indexWhere(
      (r) => (r.memberId != null && r.memberId == memberId) || 
             (r.memberId == null && r.attendee == attendeeName),
    );
    if (existingIndex != -1) {
      updatedRecords[existingIndex] = newRecord;
    } else {
      updatedRecords.add(newRecord);
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    // Save to repo logic
    try {
      final saved = await widget.sessionRepository.saveSnapshot(
        updatedSession,
        actor: 'User',
      );
      if (mounted) {
        setState(() {
          _currentSession = saved;
        });
      }
    } catch (e) {
      // Handle error (show snackbar?)
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  void _processAttendance(AttendanceStatus status) {
    if (_currentIndex >= widget.members.length) return;

    final member = widget.members[_currentIndex];

    // Fire and forget attendance recording
    _recordAttendance(member.id, member.displayName, status);

    setState(() {
      _currentIndex++;
    });
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddMemberSheet(
            onAdd: (name, isPresent, isGuest, existingMember) async {
              String? finalMemberId;
              if (existingMember != null) {
                finalMemberId = existingMember.id;
              } else if (!isGuest) {
                try {
                  final families =
                      await widget.attendanceRepository.fetchFamilies();
                  Family targetFamily;
                  if (families.isEmpty) {
                    targetFamily = await widget.attendanceRepository.addFamily(
                      'General',
                    );
                  } else {
                    targetFamily = families.first;
                  }

                  finalMemberId = DateTime.now().millisecondsSinceEpoch.toString();
                  final newMember = Member(
                    id: finalMemberId,
                    displayName: name,
                  );

                  await widget.attendanceRepository.addMember(
                    targetFamily.id,
                    newMember,
                  );
                } catch (e) {
                  debugPrint('Error adding regular member: $e');
                }
              }

              _recordAttendance(
                finalMemberId,
                name,
                isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
              );

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$name added')));
              }
            },
          ),
    );
  }

  void _undo() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        // Optionally remove the record from session?
        // Or just let the user overwrite it.
        // If we want "Undo" to clear the state, we should remove it from records or not logic?
        // Let's just step back. The user will overwrite key.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentIndex >= widget.members.length) {
      return SessionSummaryPage(
        session: _currentSession,
        members: widget.members,
        sessionRepository: widget.sessionRepository,
        attendanceRepository: widget.attendanceRepository,
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
                                        child: Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainerHigh,
                                            shape: BoxShape.circle,
                                          ),
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
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Avatar
                                            Container(
                                              width: 96,
                                              height: 96,
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
                                            const SizedBox(height: 24),
                                            Text(
                                              currentMember.displayName,
                                              style: TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onSurface,
                                                height: 1.25, // leading-tight
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
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
                    width: 72,
                    height: 72,
                    child: Material(
                      color: colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('undoButton'),
                        onTap: _currentIndex > 0 ? _undo : null,
                        child: Icon(
                          Icons.undo,
                          size: 32,
                          color: _currentIndex > 0
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Absent Button (X)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Material(
                      color: colorScheme.surfaceContainerHigh,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      elevation: 1,
                      child: InkWell(
                        key: const Key('absentButton'),
                        onTap: () =>
                            _processAttendance(AttendanceStatus.absent),
                        child: Icon(
                          Icons.close,
                          size: 40,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Present Button (Check)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Hero(
                      tag: 'fab',
                      child: Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        elevation: 3,
                        child: InkWell(
                          key: const Key('presentButton'),
                          onTap: () =>
                              _processAttendance(AttendanceStatus.present),
                          child: Icon(
                            Icons.check,
                            size: 40,
                            color: colorScheme.onPrimary,
                          ),
                        ),
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
