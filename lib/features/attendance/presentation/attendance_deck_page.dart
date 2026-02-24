import 'package:flutter/material.dart';

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import 'add_guest_sheet.dart';
import 'swipeable_card.dart';

class AttendanceDeckPage extends StatefulWidget {
  const AttendanceDeckPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;

  @override
  State<AttendanceDeckPage> createState() => _AttendanceDeckPageState();
}

class _AttendanceDeckPageState extends State<AttendanceDeckPage> {
  late Session _currentSession;
  late int _currentIndex;
  final List<Member> _remainingMembers = [];
  bool _isLoading = true;

  // Stitch Colors
  static const primaryColor = Color(0xFF6750A4);
  static const onPrimaryColor = Color(0xFFFFFFFF);
  static const surfaceColor = Color(0xFFFEF7FF);
  static const onSurfaceColor = Color(0xFF1D1B20);
  static const onSurfaceVariantColor = Color(0xFF49454F);
  static const surfaceContainerColor = Color(0xFFF3EDF7);
  static const surfaceContainerHighColor = Color(0xFFECE6F0);
  static const errorColor = Color(0xFFB3261E);

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
    final recordedIds = _currentSession.records.map((r) => r.attendee).toSet();
    // Assuming member.displayName matches attendee for now (basic string matching as per current data/model)
    // Wait, the Member model has an ID, but SessionRecord stores 'attendee' as String (name?).
    // Checking SessionRecord in previous turn... it has 'attendee' string.
    // Checking SessionRepository seed... 'Alana Rivera'. It uses names.
    // WE SHOULD probably use IDs if possible, but the existing code uses names.
    // For now, I will match by displayName.

    // Logic: Find first index where member.displayName is NOT in recordedIds.
    // Actually, maybe we just want to iterate through everyone regardless.
    // But if I back out and return, I probably want to resume.
    int firstUnrecorded = 0;
    for (int i = 0; i < widget.members.length; i++) {
      if (!recordedIds.contains(widget.members[i].displayName)) {
        firstUnrecorded = i;
        break;
      }
    }
    _currentIndex = firstUnrecorded;

    // Snappier delay to allow Hero to finish without making the app feel slow
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _recordAttendance(
    String attendeeName,
    AttendanceStatus status,
  ) async {
    // Create new record
    final newRecord = SessionRecord(
      attendee: attendeeName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User', // Placeholder
    );

    // Update session locally
    // If record exists, replace it. If not, add it.
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    final existingIndex = updatedRecords.indexWhere(
      (r) => r.attendee == attendeeName,
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
      await widget.sessionRepository.saveSnapshot(
        updatedSession,
        actor: 'User',
      );
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
    _recordAttendance(member.displayName, status);

    setState(() {
      _currentIndex++;
    });
  }

  void _showAddGuestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddGuestSheet(
            onAdd: (name, isPresent) {
              _recordAttendance(
                name,
                isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$name added')));
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
    if (_currentIndex >= widget.members.length) {
      // Done state
      return Scaffold(
        backgroundColor: surfaceColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'All caught up!',
                style: TextStyle(fontSize: 24, color: onSurfaceColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Hub'),
              ),
            ],
          ),
        ),
      );
    }

    final currentMember = widget.members[_currentIndex];
    final progress = (_currentIndex + 1) / widget.members.length;

    return Scaffold(
      backgroundColor: surfaceColor,
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
                  color: surfaceContainerHighColor,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.only(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: onSurfaceVariantColor,
                      tooltip: 'Cancel',
                    ),
                  ),
                ),
                // Add Guest Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16),
                    child: OutlinedButton.icon(
                      onPressed: _showAddGuestSheet,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Add Guest'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurfaceVariantColor,
                        backgroundColor: surfaceColor,
                        side: BorderSide(
                          color: onSurfaceVariantColor.withValues(alpha: 0.2),
                        ),
                        shape: const StadiumBorder(),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        elevation: WidgetStateProperty.all(
                          2,
                        ), // To mimic shadow-sm
                        shadowColor: WidgetStateProperty.all(Colors.black12),
                      ),
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
                                  color: surfaceContainerColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
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
                                  color: surfaceContainerColor.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
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
                              duration: const Duration(milliseconds: 400),
                              child: _isLoading
                                  ? Container(
                                      key: const ValueKey('skeleton'),
                                      width: double.infinity,
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: surfaceContainerColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    )
                                  : SwipeableCard(
                                      key: ValueKey(
                                        currentMember.id,
                                      ), // Important for resetting state
                                      rightSwipeColor: primaryColor,
                                      leftSwipeColor: errorColor,
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
                                          color: surfaceContainerColor,
                                          borderRadius: BorderRadius.circular(16),
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
                                                color: surfaceContainerHighColor,
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
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              currentMember.displayName,
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w500,
                                                color: onSurfaceColor,
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  // Undo Button
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Material(
                      color: surfaceContainerHighColor,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _currentIndex > 0 ? _undo : null,
                        child: Icon(
                          Icons.undo,
                          size: 40,
                          color: _currentIndex > 0
                              ? onSurfaceVariantColor
                              : onSurfaceVariantColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),

                  // Absent Button (X)
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Material(
                      color: surfaceContainerHighColor,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      elevation: 1,
                      child: InkWell(
                        onTap: () =>
                            _processAttendance(AttendanceStatus.absent),
                        child: const Icon(
                          Icons.close,
                          size: 48,
                          color: errorColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),

                  // Present Button (Check)
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Hero(
                      tag: 'fab',
                      child: Material(
                        color: primaryColor,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        elevation: 3,
                        child: InkWell(
                          onTap: () =>
                              _processAttendance(AttendanceStatus.present),
                          child: const Icon(
                            Icons.check,
                            size: 48,
                            color: onPrimaryColor,
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
