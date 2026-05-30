import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_shadows.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_start_mode.dart';
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
    this.initialListMode = false,
    this.startMode,
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

  /// When true, the page opens in the roster List view instead of the
  /// speed-swipe deck. Used for "all present" / smart start modes where the
  /// user toggles exceptions rather than swiping every member.
  final bool initialListMode;

  /// How the session was started. When the user picked a bulk default
  /// (all-present / smart) the List opens in *confirm mode* — everyone arrives
  /// pre-marked, the user fixes exceptions and taps a sticky Confirm button.
  /// `null` or [AttendanceStartMode.allAbsent] is the plain mark-from-scratch
  /// flow (deck + tap-to-mark list).
  final AttendanceStartMode? startMode;

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
  bool _isListMode = false;
  final List<int> _history = [];
  final SwipeableCardController _swipeController = SwipeableCardController();
  // Bumped on every navigation so each card gets a unique key. Prevents the
  // AnimatedSwitcher from reusing a dismissed card's off-screen state when
  // returning to the same member (e.g. via undo).
  int _navSeq = 0;
  final Set<String> _touchedMemberIds = {};
  final Set<String> _touchedMemberNames = {};

  /// Live drag progress of the top card, used to fade the deck's left/right
  /// hint zones in and out without rebuilding the card itself.
  final ValueNotifier<SwipeProgress> _dragProgress = ValueNotifier(
    const SwipeProgress(dx: 0, rightProgress: 0, leftProgress: 0),
  );

  /// Status each member arrived with (the preseed). Drives the confirm-mode
  /// "changed" tally and per-row highlight — a member is "changed" when their
  /// current status differs from this baseline.
  final Map<String, AttendanceStatus> _baselineStatus = {};

  /// True when the List opened from a bulk default (all-present / smart): the
  /// user confirms exceptions rather than marking from scratch.
  bool get _confirmMode =>
      widget.initialListMode &&
      (widget.startMode == AttendanceStartMode.allPresent ||
          widget.startMode == AttendanceStartMode.perMemberDefault);

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
    _isListMode = widget.initialListMode;
    _updateSession(widget.session);
    _snapshotBaseline(widget.session);
    _currentEvent = widget.event;
    debugPrint(
        'DEBUG: AttendanceDeckPage.initState: session=${_currentSession.id}, title=${_currentSession.title}, recordsCount=${_currentSession.records.length}');
    debugPrint(
        'DEBUG: AttendanceDeckPage.initState: membersCount=${widget.members.length}, members=${widget.members.map((m) => m.displayName).toList()}');

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
    debugPrint(
        'DEBUG: AttendanceDeckPage.initState: _currentIndex=$_currentIndex');
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _eventsSubscription?.cancel();
    _dragProgress.dispose();
    super.dispose();
  }

  /// Records the status each member started with (their preseed), keyed by id
  /// (or display name for id-less entries), for confirm-mode change tracking.
  void _snapshotBaseline(Session session) {
    _baselineStatus.clear();
    for (final r in session.records) {
      final key = (r.memberId != null && r.memberId!.trim().isNotEmpty)
          ? r.memberId!
          : r.attendee;
      _baselineStatus[key] = r.status;
    }
  }

  AttendanceStatus? _baselineFor(Member m) =>
      _baselineStatus[m.id] ?? _baselineStatus[m.displayName];

  void _subscribeToMembers() {
    _membersSubscription =
        widget.attendanceRepository.streamFamilies().listen((families) {
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
    _eventsSubscription =
        widget.eventRepository.streamEvents().listen((events) {
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
        final filtered =
            f.members.where((m) => eventIds.contains(m.id)).toList();
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
        (r.attendee == attendeeName));
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
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
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
      while (next < widget.members.length &&
          _isMemberTouched(widget.members[next])) {
        next++;
      }
      _history.add(_currentIndex);
      if (next < widget.members.length) {
        setState(() {
          _currentIndex = next;
          _navSeq++;
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
    final status = present ? AttendanceStatus.present : AttendanceStatus.absent;
    for (final m in family.members) {
      final mid = (m.isVisitor || m.id.trim().isEmpty) ? null : m.id;
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
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
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
        (memberIdSet.contains(widget.members[next].id) ||
            _isMemberTouched(widget.members[next]))) {
      next++;
    }
    _history.add(_currentIndex);
    if (next >= widget.members.length) {
      _finishAndNavigate();
    } else {
      setState(() {
        _currentIndex = next;
        _navSeq++;
      });
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
        _navSeq++;
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
        availableMembers: _allMembers.isNotEmpty ? _allMembers : widget.members,
      ),
    );
  }

  /// Roll-up of the current marking state used by the header tally and the
  /// progress bar. `decided*` count only members the user has actually touched
  /// (deck semantics: 0·0·N at the start). `status*` count every current
  /// record incl. the preseed (confirm-mode semantics: everyone pre-marked).
  ({
    int decidedPresent,
    int decidedAbsent,
    int statusPresent,
    int statusAbsent,
    int remaining,
    int changed,
  }) _tally() {
    final byId = <String, SessionRecord>{};
    final byName = <String, SessionRecord>{};
    for (final r in _currentSession.records) {
      if (r.memberId != null && r.memberId!.trim().isNotEmpty) {
        byId[r.memberId!] = r;
      }
      byName[r.attendee] = r;
    }
    var decidedPresent = 0,
        decidedAbsent = 0,
        statusPresent = 0,
        statusAbsent = 0,
        touched = 0,
        changed = 0;
    for (final m in widget.members) {
      final r = byId[m.id] ?? byName[m.displayName];
      final isTouched = _isMemberTouched(m);
      if (isTouched) touched++;
      if (r != null) {
        if (r.status == AttendanceStatus.present) {
          statusPresent++;
          if (isTouched) decidedPresent++;
        } else {
          statusAbsent++;
          if (isTouched) decidedAbsent++;
        }
      }
      // Only members with a known preseed baseline can be "changed" — keeps
      // this in sync with AttendanceRosterList._isChanged (guests with no
      // baseline must not inflate the count).
      final baseline = _baselineFor(m);
      if (baseline != null && r?.status != baseline) changed++;
    }
    return (
      decidedPresent: decidedPresent,
      decidedAbsent: decidedAbsent,
      statusPresent: statusPresent,
      statusAbsent: statusAbsent,
      remaining: widget.members.length - touched,
      changed: changed,
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
              child:
                  _isListMode ? _buildListBody() : _buildDeckBody(colorScheme),
            ),
            if (!_isListMode) _buildDeckFooter(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    final c = context.conv;
    final t = _tally();
    final total = widget.members.length;

    // Tally numbers + tail differ by surface. Confirm mode (bulk default) shows
    // the live present/absent split and a "N changed" tail; deck/manual shows
    // only decisions made so far and "N left".
    final present = _confirmMode ? t.statusPresent : t.decidedPresent;
    final absent = _confirmMode ? t.statusAbsent : t.decidedAbsent;
    final tail = _confirmMode ? '${t.changed} changed' : '${t.remaining} left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balanced 3-column bar so the centered title stays dead-center
        // regardless of the side controls.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(_currentSession),
                icon: const Icon(Icons.close),
                color: c.ink2,
                tooltip: 'Cancel',
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentSession.title,
                      style: AppTypography.eyebrow(color: c.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    DefaultTextStyle(
                      style: AppTypography.geist(fontSize: 12, color: c.ink3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$present',
                            style: AppTypography.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.present,
                            ),
                          ),
                          const Text(' · '),
                          Text(
                            '$absent',
                            style: AppTypography.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.absent,
                            ),
                          ),
                          const Text(' · '),
                          Text(
                            tail,
                            style: AppTypography.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: c.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('finishSessionButton'),
                onPressed: () => _finishAndNavigate(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        // Centered Deck/List segmented control.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Center(
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
        // Contained progress bar: single present fill on the deck, two-tone
        // present/absent split in list mode.
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: total == 0
                  ? ColoredBox(color: c.cardSoft)
                  : _isListMode
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            return Row(
                              children: [
                                SizedBox(
                                  width: w * present / total,
                                  child: ColoredBox(color: c.present),
                                ),
                                SizedBox(
                                  width: w * absent / total,
                                  child: ColoredBox(color: c.absent),
                                ),
                                Expanded(child: ColoredBox(color: c.cardSoft)),
                              ],
                            );
                          },
                        )
                      : Stack(
                          children: [
                            Positioned.fill(child: ColoredBox(color: c.cardSoft)),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  ((total - t.remaining) / total).clamp(0.0, 1.0),
                              child: ColoredBox(color: c.present),
                            ),
                          ],
                        ),
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
      // The session tally now lives in the deck-style header above, so the
      // roster needn't repeat the Present/Absent/Total stat chips.
      showStats: false,
      confirmMode: _confirmMode,
      smartStart: widget.startMode == AttendanceStartMode.perMemberDefault,
      baselineStatus: _confirmMode ? _baselineStatus : null,
      onConfirm: _confirmMode ? _finishAndNavigate : null,
      onAddGuest: _showAddMemberSheet,
    );
  }

  Future<void> _markAllAttendance(bool present) async {
    final previousRecords = List<SessionRecord>.from(_currentSession.records);
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

  /// Eyebrow caption under the name on a deck card: "Loner" for a singleton /
  /// synthetic bucket, otherwise the family name suffixed with " family" (but
  /// not doubled when the name already reads like "… Family").
  String _captionFor(Family? family) {
    final isRealFamily = family != null &&
        family.id != '_synthetic_all' &&
        !(family.isAutoSingleton && family.members.length <= 1);
    if (!isRealFamily) return 'Loner';
    final name = family.displayName;
    return name.toLowerCase().contains('family') ? name : '$name family';
  }

  Widget _hintZone({required bool present}) {
    final c = context.conv;
    final color = present ? c.present : c.absent;
    return ValueListenableBuilder<SwipeProgress>(
      valueListenable: _dragProgress,
      builder: (context, p, _) {
        final amt = present ? p.rightProgress : p.leftProgress;
        return Opacity(
          opacity: (amt * 0.4 + 0.05).clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(present ? Icons.check : Icons.close, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                present ? 'Present' : 'Absent',
                style: AppTypography.eyebrow(color: color, fontSize: 9),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeckBody(ColorScheme colorScheme) {
    final c = context.conv;

    if (_currentIndex >= widget.members.length) {
      final t = _tally();
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'All marked.',
                style: AppTypography.fraunces(
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                  color: c.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${t.statusPresent} present, ${t.statusAbsent} absent. '
                'Tap Done to save.',
                style: AppTypography.geist(fontSize: 15, color: c.ink2, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentMember = widget.members[_currentIndex];
    final family = _familyForMember(currentMember);
    final showFamilyContext = family != null && family.id != '_synthetic_all';
    final familyCaption = _captionFor(family);
    final next = _currentIndex + 1 < widget.members.length
        ? widget.members[_currentIndex + 1]
        : null;

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
                    // Hint zones flanking the deck — fade in as the card drags.
                    Positioned(
                      left: 0,
                      top: 44,
                      child: _hintZone(present: false),
                    ),
                    Positioned(
                      right: 0,
                      top: 44,
                      child: _hintZone(present: true),
                    ),
                    // Next member peeking behind the current card.
                    if (next != null)
                      Positioned(
                        left: 28,
                        right: 28,
                        top: 24,
                        bottom: 12,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.55,
                            child: Transform.scale(
                              scale: 0.96,
                              child: _DeckCard(
                                member: next,
                                familyCaption:
                                    _captionFor(_familyForMember(next)),
                                progress: const SwipeProgress(
                                  dx: 0,
                                  rightProgress: 0,
                                  leftProgress: 0,
                                ),
                                small: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 6,
                      bottom: 6,
                      child: RepaintBoundary(
                        // No AnimatedSwitcher: the dismissed card flies off via
                        // its own animation, so the next member should appear
                        // immediately and centered rather than fading in (which
                        // left a blank gap while the new card ramped from 0).
                        child: SwipeableCard(
                          key: ValueKey('${currentMember.id}#$_navSeq'),
                          controller: _swipeController,
                          rightSwipeColor: c.present,
                          leftSwipeColor: c.absent,
                          onProgress: (p) => _dragProgress.value = p,
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
    final c = context.conv;
    final canMark = _currentIndex < widget.members.length;
    final canUndo = _history.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Undo — soft 52px circle.
              SizedBox(
                width: 52,
                height: 52,
                child: Material(
                  color: c.cardSoft,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('undoButton'),
                    onTap: canUndo ? _undo : null,
                    child: Icon(
                      Icons.undo,
                      size: 22,
                      color: canUndo ? c.ink2 : c.ink2.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              // Absent — 60px outlined circle.
              SizedBox(
                width: 60,
                height: 60,
                child: Material(
                  color: Colors.transparent,
                  shape: CircleBorder(side: BorderSide(color: c.absent, width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('absentButton'),
                    onTap: canMark
                        ? () => widget.disableAnimations
                            ? _processAttendance(AttendanceStatus.absent)
                            : _swipeController.swipeLeft()
                        : null,
                    child: Icon(Icons.close, size: 26, color: c.absent),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              // Present — 72px filled circle with a soft glow.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.present.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Material(
                  color: c.present,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('presentButton'),
                    onTap: canMark
                        ? () => widget.disableAnimations
                            ? _processAttendance(AttendanceStatus.present)
                            : _swipeController.swipeRight()
                        : null,
                    child: Icon(Icons.check, size: 30, color: c.onPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Add guest — quiet, low-frequency walk-in action below the actions.
          TextButton.icon(
            key: const Key('deckAddGuestButton'),
            onPressed: _showAddMemberSheet,
            style: TextButton.styleFrom(foregroundColor: c.ink3),
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Add guest'),
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
    this.small = false,
  });

  final Member member;
  final String familyCaption;
  final SwipeProgress progress;

  /// Compact variant used for the next-card peek behind the active card.
  final bool small;

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
                    ConvAvatar(letter: initial, size: small ? 70 : 88, tone: tone),
                    SizedBox(height: small ? 16 : 20),
                    Text(
                      member.displayName,
                      style: AppTypography.fraunces(
                        fontSize: small ? 26 : 32,
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
