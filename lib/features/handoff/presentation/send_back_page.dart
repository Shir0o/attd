import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../../data/session_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../hub/domain/event.dart';
import '../data/handoff_service.dart';
import '../data/handoff_sharer.dart';
import '../domain/handoff_builder.dart';
import '../domain/handoff_file.dart';
import 'handoff_widgets.dart';

/// What the helper sees after marking a handed-off session: the tally, an
/// optional name, and "Send back", which opens the share sheet with the result
/// file. Also where they can remove the handed-off event afterwards.
class SendBackPage extends StatefulWidget {
  const SendBackPage({
    super.key,
    required this.event,
    required this.session,
    required this.sessionRepository,
    required this.service,
    this.sharer,
    this.disableAnimations = false,
  });

  final Event event;
  final Session session;
  final SessionRepository sessionRepository;
  final HandoffService service;
  final HandoffSharer? sharer;
  final bool disableAnimations;

  @override
  State<SendBackPage> createState() => _SendBackPageState();
}

class _SendBackPageState extends State<SendBackPage> {
  final _nameController = TextEditingController();
  Session? _session;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final started = DateTime.now();
    // The marks were just written; read them back so what is sent is what is
    // stored.
    final fresh = await widget.sessionRepository.findSessionById(
      widget.session.id,
    );
    final remaining =
        handoffSkeletonMinimum - DateTime.now().difference(started);
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    setState(() {
      _session = fresh ?? widget.session;
      _loading = false;
    });
  }

  Session get _marked => _session ?? widget.session;

  int get _guests => _marked.records.where((r) => r.memberId == null).length;
  int get _present => _marked.records
      .where((r) => r.memberId != null && r.status == AttendanceStatus.present)
      .length;
  int get _absent => _marked.records
      .where((r) => r.memberId != null && r.status != AttendanceStatus.present)
      .length;

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final session = _marked;
      final result = HandoffBuilder.buildResult(
        eventId: widget.event.handoffEventId!,
        sessionDate: session.sessionDate,
        records: session.records,
        helperName: _nameController.text,
      );
      await (widget.sharer ?? HandoffSharer()).send(
        document: result,
        fileName: HandoffSharer.fileNameFor(
          widget.event.title,
          session.sessionDate,
          suffix: 'marks',
        ),
        text: 'Attendance marks for ${widget.event.title}, '
            '${DateFormat('MMM d').format(session.sessionDate)}. '
            'Open this file in Attendance Tracker and choose Add to session.',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not prepare the file to send. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove() async {
    final navigator = Navigator.of(context);
    final ok = await confirmRemoveHandedOff(context, widget.event);
    if (!ok) return;
    await widget.service.remove(widget.event);
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: const ConvEyebrow('Send back'),
      ),
      body: SafeArea(
        child: SkeletonSwitcher(
          loading: _loading,
          disableAnimations: widget.disableAnimations,
          skeleton:
              HandoffSkeleton(disableAnimations: widget.disableAnimations),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConvEyebrow(
                  DateFormat('EEEE · MMM d').format(_marked.sessionDate),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.event.title,
                  style: AppTypography.fraunces(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Marked. Now send the marks back so they can be added to '
                  'the owner\'s session.',
                  style: AppTypography.geist(
                    fontSize: 15,
                    color: c.ink2,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                HandoffStatRow(
                  present: _present,
                  absent: _absent,
                  guests: _guests,
                ),
                const SizedBox(height: 24),
                const ConvEyebrow('Your name (optional)'),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('sendBackNameField'),
                  controller: _nameController,
                  maxLength: HandoffLimits.maxHelperNameLength,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: AppTypography.geist(fontSize: 17, color: c.ink),
                  decoration: InputDecoration(
                    hintText: 'So they know who marked it',
                    counterText: '',
                    hintStyle: AppTypography.geist(fontSize: 17, color: c.ink3),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('sendBackButton'),
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Send back'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('removeHandedOffButton'),
                  onPressed: _remove,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Remove from my phone'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send first. Removing deletes this event, its roster and '
                  'your marks from this phone.',
                  textAlign: TextAlign.center,
                  style: AppTypography.geist(fontSize: 12, color: c.ink3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before removing a handed-off event from this phone.
Future<bool> confirmRemoveHandedOff(BuildContext context, Event event) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove from this phone?'),
      content: Text(
        'This deletes "${event.title}", its roster and the marks you '
        'recorded from this phone. Make sure you have sent them back first. '
        'Your own events and members are not touched.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirmRemoveHandedOff'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
