import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../domain/active_roster_index.dart';
import '../domain/attendance_marking_session.dart';
import '../models/member.dart';
import '../utils/session_roster_utils.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../handoff/data/handoff_service.dart';
import '../../handoff/data/handoff_sharer.dart';
import '../../handoff/presentation/send_back_page.dart';
import '../../settings/data/drive_service.dart';
import 'add_guest_sheet.dart';
import 'fast_marking/fast_marking_model.dart';
import 'fast_marking/likely_here_view.dart';
import 'session_summary_page.dart';
import 'done_progress_pill.dart';

class AttendanceDeckPage extends StatefulWidget {
  const AttendanceDeckPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
    required this.attendanceRepository,
    required this.eventRepository,
    this.event,
    this.driveService,
    this.disableAnimations = false,
    this.deleteOnCancel = false,
    this.markingSession,
    this.handoffSharer,
  });

  final AttendanceMarkingSession? markingSession;

  /// Opens the share sheet from Send back on a handed-off event. Tests pass a
  /// fake.
  final HandoffSharer? handoffSharer;
  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final Event? event;
  final DriveService? driveService;
  final bool disableAnimations;

  /// When true, abandoning the page (Cancel / system back) discards the
  /// session if nothing was marked, and asks Save-as-is vs Discard once
  /// something has been. Only set for *freshly created* sessions, which start
  /// with nobody marked — never for resuming an existing session, where backing
  /// out must preserve already-saved records.
  final bool deleteOnCancel;

  @override
  State<AttendanceDeckPage> createState() => _AttendanceDeckPageState();
}

class _AttendanceDeckPageState extends State<AttendanceDeckPage> {
  late final AttendanceMarkingSession _markingSession;
  bool _ownsMarkingSession = false;
  List<Member> _allMembers = [];
  Event? _currentEvent;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _saveErrorSubscription;

  /// Someone else's event: marks only, no changes to its roster.
  bool get _isHandedOff =>
      (_currentEvent ?? widget.event)?.isHandedOff ?? false;

  Session get _currentSession => _markingSession.session;
  List<Member> get _sessionMembers => _markingSession.sessionMembers;
  bool get _hasUserEdits => _markingSession.hasUserEdits;
  Future<void> _drainSaves() => _markingSession.drain();

  /// The Likely here "Add someone" pill, which the add sheet grows out of.
  final _addSomeoneSource = GlobalKey<ConvMorphSourceState>();

  /// Cached active roster index for [_sessionMembers]. Rebuilt only when the
  /// roster changes, never on the rebuild that follows each mark.
  ActiveRosterIndex? _activeRosterIndex;
  int _indexMembersLength = 0;

  ActiveRosterIndex get _memoisedActiveRosterIndex {
    if (_activeRosterIndex == null ||
        _indexMembersLength != _sessionMembers.length) {
      _indexMembersLength = _sessionMembers.length;
      _activeRosterIndex = ActiveRosterIndex(members: _sessionMembers);
    }
    return _activeRosterIndex!;
  }

  /// Cancel (X / system back) on a freshly created session that the user has
  /// already marked: ask whether to keep those marks or throw the session away,
  /// rather than silently discarding edited work or leaving a phantom session.
  Future<void> _confirmCancel() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard attendance?'),
        content: const Text(
          'You\'ve marked some attendance for this session. '
          'Save it as is, or discard the session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save as is'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return; // dismissed → stay on the grid
    if (choice == 'discard') {
      await _markingSession.discardSession(actor: 'System (Cleanup)');
    } else {
      await _markingSession.recordAbsencesForUnmarked();
      await _drainSaves();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    if (widget.markingSession != null) {
      _markingSession = widget.markingSession!;
      _ownsMarkingSession = false;
    } else {
      _markingSession = AttendanceMarkingSession(
        session: widget.session,
        baseMembers: widget.members,
        event: widget.event,
        sessionRepository: widget.sessionRepository,
        attendanceRepository: widget.attendanceRepository,
        eventRepository: widget.eventRepository,
        defaultActor: 'User',
      );
      _ownsMarkingSession = true;
    }

    _markingSession.addListener(_onMarkingSessionChanged);
    _saveErrorSubscription = _markingSession.saveErrors.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save record: $error')),
      );
    });

    _currentEvent = widget.event;
    debugPrint(
        'DEBUG: AttendanceDeckPage.initState: session=${_currentSession.id}, title=${_currentSession.title}, recordsCount=${_currentSession.records.length}');
    debugPrint(
        'DEBUG: AttendanceDeckPage.initState: membersCount=${widget.members.length}, members=${widget.members.map((m) => m.displayName).toList()}');

    _subscribeToMembers();
    _subscribeToEvents();
  }

  void _onMarkingSessionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _markingSession.removeListener(_onMarkingSessionChanged);
    _saveErrorSubscription?.cancel();
    if (_ownsMarkingSession) {
      _markingSession.dispose();
    }
    _membersSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMembers() {
    _membersSubscription =
        widget.attendanceRepository.streamFamilies().listen((families) {
      if (!mounted) return;
      setState(() {
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
          _markingSession.updateEvent(e);
          setState(() => _currentEvent = e);
          return;
        }
      }
    });
  }

  Future<Member> _addAttendee(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) async {
    // On a handed-off event everyone added is a guest, whatever asks.
    final handedOff = _isHandedOff;
    final resolved = await _markingSession.addAttendee(
      name,
      isPresent: isPresent,
      isGuest: isGuest || handedOff,
      existingMember: handedOff ? null : existingMember,
    );
    if (mounted) {
      setState(() {
        _activeRosterIndex = null;
      });
    }
    return resolved;
  }

  Future<void> _toggleMember(Member member, bool isPresent) async {
    await _markingSession.toggleMember(member, isPresent);
  }

  void _finishAndNavigate() {
    // Flush any in-flight background writes first so the summary (which
    // re-reads the session from disk) always reflects every mark. Anyone left
    // unmarked is recorded absent so the saved session is complete.
    _markingSession
        .recordAbsencesForUnmarked()
        .then((_) => _drainSaves())
        .then((_) {
      if (!mounted) return;
      if (_isHandedOff) {
        // The helper's next step is sending the marks back, not a summary.
        final event = _currentEvent ?? widget.event!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SendBackPage(
              event: event,
              session: _currentSession,
              sessionRepository: widget.sessionRepository,
              service: HandoffService(
                attendanceRepository: widget.attendanceRepository,
                eventRepository: widget.eventRepository,
                sessionRepository: widget.sessionRepository,
              ),
              sharer: widget.handoffSharer,
              disableAnimations: widget.disableAnimations,
            ),
          ),
        );
        return;
      }
      _ownsMarkingSession = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionSummaryPage(
            session: _currentSession,
            members: _sessionMembers,
            sessionRepository: widget.sessionRepository,
            attendanceRepository: widget.attendanceRepository,
            eventRepository: widget.eventRepository,
            event: _currentEvent ?? widget.event,
            disableAnimations: widget.disableAnimations,
            markingSession: _markingSession,
          ),
        ),
      );
    });
  }

  /// Adds the person from the add sheet and confirms it in a snackbar.
  /// Returns who was added.
  Future<Member> _addFromSheet(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) async {
    final member = await _addAttendee(name, isPresent, isGuest, existingMember);
    if (!mounted) return member;
    // A newcomer's tile sorts in alphabetically with everyone, often
    // off-screen; confirm it happened.
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    // A fresh key per snackbar: the previous one may still be animating out.
    _addedSnackBarText = GlobalKey();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // Park it above the Add someone pill so a second add needn't wait.
        margin: LikelyHereView.snackBarMarginAbove(_addSomeoneSource),
        content: Text(
          '${name.trim()} added · Here',
          key: _addedSnackBarText,
        ),
      ),
    );
    return member;
  }

  /// Opens the add sheet. It grows out of [morphFrom] (the "Add someone"
  /// pill) and a submit flies the control used to where the person landed.
  Future<void> _showAddMemberSheet({
    required GlobalKey<ConvMorphSourceState> morphFrom,
  }) async {
    Future<Member>? added;
    String? addedName;
    Widget sheet(BuildContext context) => AddMemberSheet(
          onAdd: (name, isPresent, isGuest, existingMember) {
            addedName = name.trim();
            added = _addFromSheet(name, isPresent, isGuest, existingMember);
          },
          availableMembers:
              _allMembers.isNotEmpty ? _allMembers : widget.members,
          rosterMemberIds: {
            for (final m in _sessionMembers)
              if (m.id.isNotEmpty) m.id,
          },
          disableAnimations: widget.disableAnimations,
          guestOnly: _isHandedOff,
        );
    // Submits pop with an AddMemberSheetResult (the control used and its
    // rect) as the sheet starts to slide away.
    final result = await showConvMorphSheet<AddMemberSheetResult>(
      context: context,
      source: morphFrom,
      builder: sheet,
      disableAnimations: widget.disableAnimations,
    );
    if (result != null && added != null && mounted) {
      await _flyToLanding(result, added!, addedName!);
    }
  }

  /// Last "added · Here" snackbar's text, for finding where it landed.
  GlobalKey _addedSnackBarText = GlobalKey();

  /// The landing flight (#222 M3): the sheet control that was used flies to
  /// the person's Likely here tile when it is fully on screen, otherwise to
  /// the "added · Here" snackbar. The grid is never scrolled to the tile.
  Future<void> _flyToLanding(
    AddMemberSheetResult result,
    Future<Member> added,
    String name,
  ) {
    final c = context.conv;
    final label = switch (result.control) {
      AddMemberSheetControl.addToRoster => 'Add to roster',
      AddMemberSheetControl.markGuest => 'Mark as guest',
      AddMemberSheetControl.existingMember => name,
    };
    Future<Rect Function()?> landing() async {
      final member = await added;
      // Let the new tile and the snackbar lay out first.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      // A guest's tile is keyed by its name snapshot, not its (empty) id.
      final tileId = SessionRoster.keyFor(member);
      final tile = LikelyHereView.visibleTileRect(context, tileId);
      if (tile != null) {
        var last = tile;
        return () =>
            last = LikelyHereView.visibleTileRect(context, tileId) ?? last;
      }
      // The snackbar may still be queued behind the previous one; aim at
      // where it will sit until it is laid out.
      var snackBar = _addedSnackBarRect() ?? _snackBarFallbackRect();
      return () => snackBar = _addedSnackBarRect() ?? snackBar;
    }

    return showConvLandingFlight(
      context: context,
      from: result.rect,
      target: landing(),
      color: c.primary,
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: AppTypography.geist(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.onPrimary,
        ),
      ),
      disableAnimations: widget.disableAnimations,
    );
  }

  /// Global rect of the "added · Here" snackbar's bubble, once laid out.
  Rect? _addedSnackBarRect() {
    final text = _addedSnackBarText.currentContext;
    if (text == null || !text.mounted) return null;
    RenderBox? bubble;
    text.visitAncestorElements((element) {
      if (element.widget is! Material) return true;
      bubble = element.findRenderObject() as RenderBox?;
      return false;
    });
    final box = bubble;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Where a floating snackbar sits: across the bottom of the page, inside
  /// the default 15/10 margins.
  Rect _snackBarFallbackRect() {
    final page = context.findRenderObject()! as RenderBox;
    final r = page.localToGlobal(Offset.zero) & page.size;
    return Rect.fromLTRB(
      r.left + 15,
      r.bottom - 58,
      r.right - 15,
      r.bottom - 10,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roster = FastMarkingRoster(
      session: _currentSession,
      members: _sessionMembers,
      index: _memoisedActiveRosterIndex,
    );

    // Confirming the session uses pushReplacement (grid → summary), so the
    // page is only ever *popped* when the user cancels — via the X button
    // or system back. For a freshly created session ([deleteOnCancel]):
    //   - untouched → discard silently (a phantom empty session, nothing to
    //     keep);
    //   - already marked → intercept the pop and ask Save-as-is vs Discard.
    // Resuming an existing session never sets the flag, so backing out always
    // keeps its records.
    final interceptCancel = widget.deleteOnCancel && _hasUserEdits;
    return PopScope(
      canPop: !interceptCancel,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if (widget.deleteOnCancel && !_hasUserEdits) {
            // Drain background writes first so a pending saveSnapshot can't
            // recreate the session after we delete it.
            _drainSaves().then((_) {
              widget.sessionRepository.deleteSession(
                _currentSession.id,
                actor: 'System (Cleanup)',
              );
            });
          }
        } else {
          _confirmCancel();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(roster),
              Expanded(child: _buildGrid(roster)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FastMarkingRoster roster) {
    final c = context.conv;
    final total = roster.alphabetical.length;
    // Everyone shown as marked counts, however they got that way (tapped now,
    // pre-marked at the start, or recorded in a past session). "Left" is the
    // grid's own meaning: people not marked present yet.
    final left = roster.unmarked.length;
    final present = total - left;

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
                // maybePop (not pop) so the PopScope intercept runs — a hard
                // pop would bypass the Save-as-is / Discard prompt.
                onPressed: () => Navigator.of(context).maybePop(),
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
                      // Scales down rather than overflows between the close button and the
                      // Done pill at large text.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConvRollingNumber(
                              key: const Key('headerTallyPresent'),
                              value: present,
                              disableAnimations: widget.disableAnimations,
                              style: AppTypography.geist(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.present,
                              ),
                            ),
                            const Text(' · '),
                            ConvRollingNumber(
                              key: const Key('headerTallyTail'),
                              value: left,
                              suffix: ' left',
                              disableAnimations: widget.disableAnimations,
                              style: AppTypography.geist(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DoneProgressPill(
                  key: const Key('finishSessionButton'),
                  progress: total == 0 ? 0.0 : present / total,
                  complete: total > 0 && left == 0,
                  onPressed: () => _finishAndNavigate(),
                  disableAnimations: widget.disableAnimations,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The marking surface: the name grid, whatever the event's stored marking
  /// mode says. It writes through the same per-member callback every mark uses.
  Widget _buildGrid(FastMarkingRoster roster) {
    return LikelyHereView(
      roster: roster,
      onToggle: _toggleMember,
      onAddGuest: () => _showAddMemberSheet(morphFrom: _addSomeoneSource),
      addSomeoneKey: _addSomeoneSource,
      disableAnimations: widget.disableAnimations,
    );
  }
}
