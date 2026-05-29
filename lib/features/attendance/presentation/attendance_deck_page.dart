import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_shadows.dart';
import '../../../../core/design/app_shimmer.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/bulk_attendance.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../settings/data/drive_service.dart';
import 'add_guest_sheet.dart';
import 'attendance_roster_list.dart';
import 'session_summary_page.dart';
import 'swipeable_card.dart';

class AttendanceDeckPage extends StatefulWidget {
  const AttendanceDeckPage({
    super.key,
    required this.session,
    required this.members,
    this.families,
    required this.sessionRepository,
    required this.attendanceRepository,
    required this.eventRepository,
    this.event,
    this.driveService,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Member> members;
  final List<Family>? families;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final Event? event;
  final DriveService? driveService;
  final bool disableAnimations;

  @override
  State<AttendanceDeckPage> createState() => _AttendanceDeckPageState();
}

class _AttendanceDeckPageState extends State<AttendanceDeckPage> {
  late Session _currentSession;
  late int _currentIndex;
  final List<Member> _remainingMembers = [];
  List<Member> _allMembers = [];
  List<Family> _allFamilies = [];
  Event? _currentEvent;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _eventsSubscription;
  bool _isLoading = true;
  bool _isListMode = false;
  final List<int> _history = [];
  final SwipeableCardController _swipeController = SwipeableCardController();
  final Set<String> _touchedMemberIds = {};
  final Set<String> _touchedMemberNames = {};

  void _updateSession(Session session) {
    _currentSession = session;
    _touchedMemberIds.clear();
    _touchedMemberNames.clear();
    for (final r in _currentSession.records) {
      if (r.recordedBy != 'System (Preseed)') {
        if (r.memberId != null) {
          _touchedMemberIds.add(r.memberId!);
        }
        _touchedMemberNames.add(r.attendee);
      }
    }
  }

  bool _isMemberTouched(Member member) {
    return _touchedMemberIds.contains(member.id) ||
        _touchedMemberNames.contains(member.displayName);
  }

  @override
  void initState() {
    super.initState();
    _updateSession(widget.session);
    _currentEvent = widget.event;
    debugPrint('DEBUG: AttendanceDeckPage.initState: session=${_currentSession.id}, title=${_currentSession.title}, recordsCount=${_currentSession.records.length}');
    debugPrint('DEBUG: AttendanceDeckPage.initState: membersCount=${widget.members.length}, members=${widget.members.map((m) => m.displayName).toList()}');

    _remainingMembers.addAll(widget.members);
    _subscribeToMembers();
    _subscribeToEvents();

    int firstUnrecorded = 0;
    for (int i = 0; i < widget.members.length; i++) {
      if (!_isMemberTouched(widget.members[i])) {
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

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMembers() {
    _membersSubscription = widget.attendanceRepository.streamFamilies().listen((families) {
      if (!mounted) return;
      setState(() {
        _allFamilies = families;
        _allMembers = families.expand((f) => f.members).toList();
      });
    });
  }

  void _subscribeToEvents() {
    final eventId = widget.event?.id;
    if (eventId == null) return;
    _eventsSubscription = widget.eventRepository.streamEvents().listen((events) {
      if (!mounted) return;
      for (final e in events) {
        if (e.id == eventId) {
          setState(() => _currentEvent = e);
          return;
        }
      }
    });
  }

  /// Families restricted to the members in this event. Falls back to a single
  /// synthetic family wrapping `widget.members` if no family context exists.
  List<Family> get _sessionFamilies {
    if (widget.families != null && widget.families!.isNotEmpty) {
      return widget.families!;
    }
    if (_allFamilies.isNotEmpty) {
      final eventIds = widget.members.map((m) => m.id).toSet();
      final result = <Family>[];
      for (final f in _allFamilies) {
        final filtered = f.members.where((m) => eventIds.contains(m.id)).toList();
        if (filtered.isEmpty) continue;
        result.add(f.copyWith(members: filtered));
      }
      if (result.isNotEmpty) return result;
    }
    return [
      Family(
        id: '_synthetic_all',
        displayName: 'All members',
        members: widget.members,
      ),
    ];
  }

  Family? _familyForMember(Member member) {
    for (final f in _sessionFamilies) {
      if (f.members.any((m) => m.id == member.id)) return f;
    }
    return null;
  }

  Future<void> _ensureMemberInEvent(String memberId) async {
    final ev = _currentEvent;
    if (ev == null) return;
    if (ev.memberIds.contains(memberId)) return;

    final updated = ev.copyWith(
      memberIds: [...ev.memberIds, memberId],
      updatedAt: DateTime.now(),
    );
    setState(() => _currentEvent = updated);
    try {
      await widget.eventRepository.updateEvent(updated);
    } catch (e) {
      debugPrint('Error adding member to event: $e');
    }
  }

  Future<Member?> _createGlobalMember(String name) async {
    try {
      final family = await widget.attendanceRepository.addFamily(
        name,
        isAutoSingleton: true,
      );
      final member = Member(id: const Uuid().v4(), displayName: name);
      await widget.attendanceRepository.addMember(family.id, member);
      return member;
    } catch (e) {
      debugPrint('Error creating global member: $e');
      return null;
    }
  }

  Future<void> _addAttendee(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) async {
    Member resolved;
    if (existingMember != null) {
      resolved = existingMember;
      await _ensureMemberInEvent(existingMember.id);
    } else if (!isGuest && name.trim().isNotEmpty) {
      final trimmed = name.trim();
      final created = await _createGlobalMember(trimmed);
      if (created != null) {
        resolved = created;
        await _ensureMemberInEvent(created.id);
      } else {
        resolved = Member(id: '', displayName: trimmed, isVisitor: true);
      }
    } else {
      resolved = Member(id: '', displayName: name, isVisitor: true);
    }
    final memberIdForRecord =
        (resolved.isVisitor || resolved.id.trim().isEmpty) ? null : resolved.id;
    await _recordAttendance(
      memberIdForRecord,
      resolved.displayName,
      isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
    );
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
        _updateSession(updatedSession);
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

  Future<void> _processAttendance(AttendanceStatus status) async {
    final member = widget.members[_currentIndex];
    await _recordAttendance(member.id, member.displayName, status);

    if (mounted) {
      int next = _currentIndex + 1;
      while (next < widget.members.length && _isMemberTouched(widget.members[next])) {
        next++;
      }
      _history.add(_currentIndex);
      if (next < widget.members.length) {
        setState(() {
          _currentIndex = next;
        });
      } else {
        // Finished all members
        _finishAndNavigate();
      }
    }
  }

  /// Applies a single bulk attendance update for every member in [family]
  /// using one saveSnapshot call — much cheaper than one write per member.
  Future<void> _bulkRecordFamily(Family family, bool present) async {
    final now = DateTime.now();
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    final status =
        present ? AttendanceStatus.present : AttendanceStatus.absent;
    for (final m in family.members) {
      final mid =
          (m.isVisitor || m.id.trim().isEmpty) ? null : m.id;
      updatedRecords.removeWhere((r) =>
          (mid != null && r.memberId == mid) ||
          (mid == null && r.memberId == null && r.attendee == m.displayName) ||
          (r.attendee == m.displayName));
      updatedRecords.add(SessionRecord(
        memberId: mid,
        attendee: m.displayName,
        status: status,
        recordedAt: now,
        recordedBy: 'User',
      ));
    }
    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );
    if (mounted) {
      setState(() => _updateSession(updatedSession));
    }
    try {
      await widget.sessionRepository.saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save records: $e')),
        );
      }
    }
  }

  Future<void> _markCurrentFamilyPresent() async {
    if (_currentIndex >= widget.members.length) return;
    final currentMember = widget.members[_currentIndex];
    final family = _familyForMember(currentMember);
    if (family == null) return;
    final memberIdSet = family.members.map((m) => m.id).toSet();
    await _bulkRecordFamily(family, true);
    if (!mounted) return;
    // Advance past the entire family in the deck.
    int next = _currentIndex;
    while (next < widget.members.length &&
        (memberIdSet.contains(widget.members[next].id) || _isMemberTouched(widget.members[next]))) {
      next++;
    }
    _history.add(_currentIndex);
    if (next >= widget.members.length) {
      _finishAndNavigate();
    } else {
      setState(() => _currentIndex = next);
    }
  }

  Future<void> _toggleMemberFromList(Member member, bool isPresent) async {
    final memberIdForRecord =
        (member.isVisitor || member.id.trim().isEmpty) ? null : member.id;
    await _recordAttendance(
      memberIdForRecord,
      member.displayName,
      isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
    );
  }

  Future<void> _toggleFamilyFromList(Family family, bool isPresent) async {
    await _bulkRecordFamily(family, isPresent);
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentIndex = _history.removeLast();
      });
    }
  }

  void _finishAndNavigate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(
          session: _currentSession,
          members: widget.members,
          families: widget.families,
          sessionRepository: widget.sessionRepository,
          attendanceRepository: widget.attendanceRepository,
          eventRepository: widget.eventRepository,
          event: _currentEvent ?? widget.event,
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
          _addAttendee(name, isPresent, isGuest, existingMember);
        },
        availableMembers:
            _allMembers.isNotEmpty ? _allMembers : widget.members,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colorScheme),
            Expanded(
              child: _isListMode
                  ? _buildListBody()
                  : _buildDeckBody(colorScheme),
            ),
            if (!_isListMode) _buildDeckFooter(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final progress = widget.members.isEmpty
        ? 0.0
        : (_currentIndex.clamp(0, widget.members.length)) /
            widget.members.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              color: colorScheme.surfaceContainerHigh,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _isListMode ? 0.0 : progress,
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
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      key: const Key('finishSessionButton'),
                      onPressed: () => _finishAndNavigate(),
                      child: const Text('Done'),
                    ),
                    IconButton(
                      onPressed: _showAddMemberSheet,
                      icon: const Icon(Icons.person_add),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Add Person',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              key: const Key('deckListModeToggle'),
              style: const ButtonStyle(
                side: WidgetStatePropertyAll(BorderSide.none),
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Deck'),
                  icon: Icon(Icons.style_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('List'),
                  icon: Icon(Icons.list_alt),
                ),
              ],
              selected: {_isListMode},
              onSelectionChanged: (sel) =>
                  setState(() => _isListMode = sel.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListBody() {
    return AttendanceRosterList(
      session: _currentSession,
      families: _sessionFamilies,
      onToggle: _toggleMemberFromList,
      onFamilyToggle: _toggleFamilyFromList,
      onMarkAll: _markAllAttendance,
      initialGrouping: RosterGrouping.byFamily,
      disableAnimations: widget.disableAnimations,
    );
  }

  Future<void> _markAllAttendance(bool present) async {
    final previousRecords =
        List<SessionRecord>.from(_currentSession.records);
    final now = DateTime.now();
    final allMembers =
        _sessionFamilies.expand((f) => f.members).toList(growable: false);
    final updatedRecords = applyBulkRecords(
      previousRecords: previousRecords,
      members: allMembers,
      present: present,
      recordedAt: now,
    );
    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );
    if (mounted) setState(() => _updateSession(updatedSession));
    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save records: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          'Marked ${allMembers.length} ${allMembers.length == 1 ? 'member' : 'members'} '
          '${present ? 'present' : 'absent'}.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restoreSessionRecords(previousRecords),
        ),
      ),
    );
  }

  Future<void> _restoreSessionRecords(
      List<SessionRecord> previousRecords) async {
    final restored = _currentSession.copyWith(
      records: previousRecords,
      updatedAt: DateTime.now(),
    );
    if (mounted) setState(() => _updateSession(restored));
    try {
      await widget.sessionRepository.saveSnapshot(restored, actor: 'User');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to undo: $e')),
        );
      }
    }
  }

  Widget _buildDeckBody(ColorScheme colorScheme) {
    if (_currentIndex >= widget.members.length) {
      return Center(
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
      );
    }

    final currentMember = widget.members[_currentIndex];
    final family = _familyForMember(currentMember);
    final showFamilyContext =
        family != null && family.id != '_synthetic_all';
    final familyCaption = showFamilyContext ? family.displayName : 'Loner';
    final c = context.conv;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Transform.translate(
                      offset: const Offset(0, 32),
                      child: Transform.scale(
                        scale: 0.9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.cardSoft.withValues(alpha: 0.55),
                            borderRadius: AppRadii.cardR,
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
                            color: c.cardSoft,
                            borderRadius: AppRadii.cardR,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedSwitcher(
                        duration: widget.disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 600),
                        child: _isLoading
                            ? _DeckSkeleton(
                                key: const ValueKey('skeleton'),
                                disableAnimations: widget.disableAnimations,
                              )
                            : SwipeableCard(
                                key: ValueKey(currentMember.id),
                                controller: _swipeController,
                                rightSwipeColor: c.present,
                                leftSwipeColor: c.absent,
                                onSwipeLeft: () => _processAttendance(
                                  AttendanceStatus.absent,
                                ),
                                onSwipeRight: () => _processAttendance(
                                  AttendanceStatus.present,
                                ),
                                childBuilder: (ctx, p) => _DeckCard(
                                  member: currentMember,
                                  familyCaption: familyCaption,
                                  progress: p,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            if (showFamilyContext && family.members.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.tonalIcon(
                  key: const Key('markFamilyPresentButton'),
                  onPressed: _markCurrentFamilyPresent,
                  icon: const Icon(Icons.groups),
                  label: Text('Mark ${family.displayName} all present'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckFooter(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('undoButton'),
                onTap: _history.isNotEmpty ? _undo : null,
                child: Icon(
                  Icons.undo,
                  color: _history.isNotEmpty
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 80,
            height: 80,
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('absentButton'),
                onTap: _currentIndex < widget.members.length
                    ? () => widget.disableAnimations
                        ? _processAttendance(AttendanceStatus.absent)
                        : _swipeController.swipeLeft()
                    : null,
                child: Icon(Icons.close, color: colorScheme.error),
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 80,
            height: 80,
            child: Material(
              color: colorScheme.primary,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('presentButton'),
                onTap: _currentIndex < widget.members.length
                    ? () => widget.disableAnimations
                        ? _processAttendance(AttendanceStatus.present)
                        : _swipeController.swipeRight()
                    : null,
                child: Icon(Icons.check, color: colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.member,
    required this.familyCaption,
    required this.progress,
  });

  final Member member;
  final String familyCaption;
  final SwipeProgress progress;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final tone = progress.rightProgress >= 0.5
        ? ConvTone.present
        : progress.leftProgress >= 0.5
            ? ConvTone.absent
            : ConvTone.neutral;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadii.cardR,
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ConvAvatar(letter: initial, size: 88, tone: tone),
                    const SizedBox(height: 20),
                    Text(
                      member.displayName,
                      style: AppTypography.fraunces(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      familyCaption.toUpperCase(),
                      style: AppTypography.eyebrow(color: c.ink3),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 28,
            right: 28,
            child: Opacity(
              opacity: progress.rightProgress,
              child: const ConvStamp(
                label: 'Present',
                tone: ConvTone.present,
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 28,
            child: Opacity(
              opacity: progress.leftProgress,
              child: const ConvStamp(
                label: 'Absent',
                tone: ConvTone.absent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton({super.key, required this.disableAnimations});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadii.cardR,
        boxShadow: AppShadows.card,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShimmer(
              width: 88,
              height: 88,
              borderRadius: BorderRadius.circular(44),
              disableAnimations: disableAnimations,
            ),
            const SizedBox(height: 20),
            AppShimmer(
              width: 180,
              height: 28,
              borderRadius: BorderRadius.circular(6),
              disableAnimations: disableAnimations,
            ),
            const SizedBox(height: 8),
            AppShimmer(
              width: 110,
              height: 12,
              borderRadius: BorderRadius.circular(4),
              disableAnimations: disableAnimations,
            ),
          ],
        ),
      ),
    );
  }
}
