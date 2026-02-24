import 'package:flutter/material.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;

  // Colors from design spec
  static const primaryColor = Color(0xFF6750A4);
  static const onPrimaryColor = Color(0xFFFFFFFF);
  static const primaryContainerColor = Color(0xFFEADDFF);
  static const onPrimaryContainerColor = Color(0xFF4F378B);
  static const surfaceColor = Color(0xFFFEF7FF);
  static const onSurfaceColor = Color(0xFF1D1B20);
  static const surfaceVariantColor = Color(0xFFE7E0EC);
  static const onSurfaceVariantColor = Color(0xFF49454F);
  static const errorColor = Color(0xFFB3261E);

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    final status = isPresent ? AttendanceStatus.present : AttendanceStatus.absent;
    final attendeeName = member.displayName;

    final newRecord = SessionRecord(
      attendee: attendeeName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User', // Placeholder
    );

    // Update session locally
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

    // Save to repo
    try {
      await widget.sessionRepository.saveSnapshot(
        updatedSession,
        actor: 'User',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  AttendanceStatus _getStatus(Member member) {
    // Check if member has a record in the session
    try {
      final record = _currentSession.records.firstWhere(
        (r) => r.attendee == member.displayName,
      );
      return record.status;
    } catch (e) {
      // If no record, default to absent? Or defaultStatus?
      // Since deck flow forces a choice, we assume Absent if not found for summary.
      return AttendanceStatus.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentMembers = <Member>[];
    final absentMembers = <Member>[];

    for (final member in widget.members) {
      if (_getStatus(member) == AttendanceStatus.present) {
        presentMembers.add(member);
      } else {
        absentMembers.add(member);
      }
    }

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: surfaceColor.withValues(alpha: 0.95),
                surfaceTintColor: Colors.transparent,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: onSurfaceColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                title: const Text(
                  'Session Summary',
                  style: TextStyle(
                    color: onSurfaceColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
              ),

              // Stats Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: primaryContainerColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'PRESENT',
                                    style: TextStyle(
                                      color: onPrimaryContainerColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${presentMembers.length}',
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 45,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: onPrimaryContainerColor.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'ABSENT',
                                    style: TextStyle(
                                      color: onPrimaryContainerColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${absentMembers.length}',
                                    style: const TextStyle(
                                      color: errorColor,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w500,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Attendance Roster',
                            style: TextStyle(
                              color: onSurfaceColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${widget.members.length} Total',
                            style: TextStyle(
                              color: onSurfaceVariantColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Marked Present Header
              SliverPersistentHeader(
                pinned: true,
                delegate: _SectionHeaderDelegate(
                  title: 'Marked Present',
                  color: primaryColor,
                ),
              ),

              // Present List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final member = presentMembers[index];
                  return _MemberListItem(
                    member: member,
                    isPresent: true,
                    onToggle:
                        (value) => _toggleAttendance(member, value),
                  );
                }, childCount: presentMembers.length),
              ),

              // Marked Absent Header
              SliverPersistentHeader(
                pinned: true,
                delegate: _SectionHeaderDelegate(
                  title: 'Marked Absent',
                  color: errorColor,
                ),
              ),

              // Absent List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final member = absentMembers[index];
                  return _MemberListItem(
                    member: member,
                    isPresent: false,
                    onToggle:
                        (value) => _toggleAttendance(member, value),
                  );
                }, childCount: absentMembers.length),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Finalize Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: surfaceVariantColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: onPrimaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 1,
                ).copyWith(
                  overlayColor: WidgetStateProperty.resolveWith(
                    (states) {
                       if (states.contains(WidgetState.pressed)) {
                          return onPrimaryColor.withValues(alpha: 0.2);
                       }
                       return null;
                    }
                  )
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Finalize Report',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Color color;

  _SectionHeaderDelegate({required this.title, required this.color});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFFEF7FF).withValues(alpha: 0.95), // Surface color with opacity
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
         decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE7E0EC), width: 0.5))
         ),
         width: double.infinity,
         padding: const EdgeInsets.only(bottom: 8),
         child: Text(
           title,
           style: TextStyle(
             color: color,
             fontSize: 14,
             fontWeight: FontWeight.w500,
           ),
         ),
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.color != color;
  }
}

class _MemberListItem extends StatelessWidget {
  final Member member;
  final bool isPresent;
  final ValueChanged<bool> onToggle;

  const _MemberListItem({
    required this.member,
    required this.isPresent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Colors
    const onSurfaceColor = Color(0xFF1D1B20);
    const onSurfaceVariantColor = Color(0xFF49454F);
    const surfaceVariantColor = Color(0xFFE7E0EC);
    const secondaryContainerColor = Color(0xFFE8DEF8);
    const onSecondaryContainerColor = Color(0xFF1D192B);
    const primaryColor = Color(0xFF6750A4);
    const surfaceColor = Color(0xFFFEF7FF);

    return InkWell(
      onTap: () => onToggle(!isPresent),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: surfaceColor,
          border: Border(
            bottom: BorderSide(color: surfaceVariantColor),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: member.isVisitor ? secondaryContainerColor : surfaceVariantColor,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: member.isVisitor ? onSecondaryContainerColor : onSurfaceVariantColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      color: onSurfaceColor,
                    ),
                  ),
                  if (member.isVisitor)
                     const Text(
                       'Added today',
                       style: TextStyle(
                         fontSize: 14,
                         color: primaryColor,
                         fontWeight: FontWeight.w500
                       ),
                     ),
                ],
              ),
            ),
            // Toggle Switch
            Switch(
              value: isPresent,
              onChanged: onToggle,
              activeThumbColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
