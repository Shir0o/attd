import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/roster_grouping.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';
import 'members_page.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({
    super.key,
    required this.eventRepository,
    required this.attendanceRepository,
    this.sessionRepository,
    this.eventToEdit,
    this.disableAnimations = false,
  });

  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final SessionRepository? sessionRepository;
  final Event? eventToEdit;
  final bool disableAnimations;

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TimeOfDay _selectedTime;
  late String _frequency;
  late DateTime _selectedDate;
  late Set<String> _selectedDays;
  late RosterGrouping _grouping;
  late Set<String> _selectedMemberIds;
  bool _isLoading = true;
  final List<String> _linkedSessions = [];

  static const List<String> _frequencies = [
    'One-time',
    'Weekly',
    'Bi-weekly',
    'Monthly',
  ];

  static const List<String> _daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  // S M T W T F S — matches JSX ordering of _daysOfWeek above.
  static const List<String> _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;

    if (event != null) {
      _nameController = TextEditingController(text: event.title);
      _selectedTime = event.time;
      _frequency = event.frequency;
      _selectedDate = event.oneTimeDate ?? DateTime.now();
      _selectedDays = event.repeatingDays.toSet();
      _grouping = event.rosterGrouping ?? RosterGrouping.byStatus;
      _selectedMemberIds = event.memberIds.toSet();
    } else {
      _nameController = TextEditingController();
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
      _frequency = 'Weekly';
      _grouping = RosterGrouping.byStatus;
      _selectedMemberIds = <String>{};
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedDays = {};

      int index = now.weekday == 7 ? 0 : now.weekday;
      if (index >= 0 && index < _daysOfWeek.length) {
        _selectedDays.add(_daysOfWeek[index]);
      }
    }

    _loadData();
  }

  Future<void> _loadData() async {
    final startTime = DateTime.now();

    if (widget.eventToEdit != null && widget.sessionRepository != null) {
      try {
        final sessions = await widget.sessionRepository!.loadSessions();
        final eventId = widget.eventToEdit!.id;
        final linked = sessions
            .where((s) => s.eventId == eventId)
            .map((s) => s.title)
            .toList();
        if (mounted) {
          setState(() {
            _linkedSessions.clear();
            _linkedSessions.addAll(linked);
          });
        }
      } catch (e) {
        debugPrint('Error loading linked sessions: $e');
      }
    }

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 800) - elapsed;
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectFrequency(BuildContext context) async {
    final c = context.conv;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.ink4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConvEyebrow('Frequency'),
                ),
              ),
              for (final option in _frequencies)
                ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: option == _frequency
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: option == _frequency ? c.primary : c.ink,
                    ),
                  ),
                  trailing: option == _frequency
                      ? Icon(Icons.check, color: c.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked != null && picked != _frequency) {
      setState(() => _frequency = picked);
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.eventToEdit != null;
      final eventId = isEditing ? widget.eventToEdit!.id : const Uuid().v4();
      final createdAt =
          isEditing ? widget.eventToEdit!.createdAt : DateTime.now();

      final event = Event(
        id: eventId,
        title: _nameController.text.trim(),
        time: _selectedTime,
        frequency: _frequency,
        oneTimeDate: _frequency == 'One-time' ? _selectedDate : null,
        repeatingDays: _frequency != 'One-time' ? _selectedDays.toList() : [],
        memberIds: _selectedMemberIds.toList(),
        defaultAttendanceStartMode:
            widget.eventToEdit?.defaultAttendanceStartMode,
        rosterGrouping: _grouping,
        createdAt: createdAt,
      );

      try {
        if (isEditing) {
          await widget.eventRepository.updateEvent(event);
        } else {
          await widget.eventRepository.createEvent(event);
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving event: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteEvent() async {
    final event = widget.eventToEdit;
    if (event == null) return;

    String warningText = '';
    if (_linkedSessions.isNotEmpty) {
      final sessionListText = _linkedSessions.take(5).join(', ') +
          (_linkedSessions.length > 5
              ? ' and ${_linkedSessions.length - 5} more'
              : '');
      warningText =
          '\n\nWARNING: This event is linked to ${_linkedSessions.length} past session reports: $sessionListText.\n\nDeleting this event will NOT delete the past reports, but they will no longer be grouped under this event history.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.title}"?$warningText',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.eventRepository.deleteEvent(event.id);
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting event: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isEditing: isEditing),
              Expanded(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: widget.disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    child: _isLoading
                        ? _buildSkeleton()
                        : _buildContent(context, isEditing: isEditing),
                  ),
                ),
              ),
              _buildBottomButton(context, isEditing: isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isEditing}) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          ConvIconButton(
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Center(
              child: ConvEyebrow(isEditing ? 'Edit event' : 'New event'),
            ),
          ),
          if (isEditing)
            ConvIconButton(
              icon: Icons.delete_outline,
              color: c.absent,
              onPressed: _deleteEvent,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isEditing}) {
    final c = context.conv;
    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        Text(
          'What are we\ntracking?',
          style: AppTypography.fraunces(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            letterSpacing: -1.08,
            height: 1.1,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 26),

        // Name
        ConvEyebrow('Name'),
        const SizedBox(height: 8),
        _NameField(controller: _nameController),

        const SizedBox(height: 18),

        // Time + Frequency row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConvEyebrow('Time'),
                  const SizedBox(height: 8),
                  ConvCardSoft(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    onTap: () => _selectTime(context),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: c.ink2),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedTime.format(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.geistTabular(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConvEyebrow('Frequency'),
                  const SizedBox(height: 8),
                  ConvCardSoft(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    onTap: () => _selectFrequency(context),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _frequency,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: c.ink3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Day / Date
        if (_frequency == 'One-time') ...[
          ConvEyebrow('Date'),
          const SizedBox(height: 8),
          ConvCardSoft(
            key: const ValueKey('date_field'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => _selectDate(context),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: c.ink2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                    style: AppTypography.geistTabular(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: c.ink3),
              ],
            ),
          ),
        ] else ...[
          ConvEyebrow('Repeats on'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_daysOfWeek.length, (i) {
              final dayName = _daysOfWeek[i];
              final letter = _dayLetters[i];
              final selected = _selectedDays.contains(dayName);
              return ConvDayChip(
                day: letter,
                active: selected,
                size: 40,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedDays.remove(dayName);
                    } else {
                      _selectedDays.add(dayName);
                    }
                  });
                },
              );
            }),
          ),
        ],

        const SizedBox(height: 22),

        // Roster
        ConvEyebrow('Roster'),
        const SizedBox(height: 8),
        ConvCardSoft(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: _openRosterPicker,
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 20, color: c.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rosterTitle(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'change later'
                          : 'change after creating',
                      style: TextStyle(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.ink3),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Grouping preset — how the marking roster sorts during a session.
        // A per-event default (also asked once on first attendance), not a
        // live in-session toggle.
        const ConvEyebrow('Group roster by'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GroupingCard(
                icon: Icons.checklist_rounded,
                label: 'Status',
                hint: 'Present · Absent',
                active: _grouping == RosterGrouping.byStatus,
                onTap: () =>
                    setState(() => _grouping = RosterGrouping.byStatus),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GroupingCard(
                icon: Icons.groups_outlined,
                label: 'Family',
                hint: 'Households together',
                active: _grouping == RosterGrouping.byFamily,
                onTap: () =>
                    setState(() => _grouping = RosterGrouping.byFamily),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Sets how people are grouped while you take attendance.',
          style: AppTypography.geist(fontSize: 12, color: c.ink3),
        ),
      ],
    );
  }

  String _rosterTitle() {
    final ids = _selectedMemberIds;
    if (ids.isEmpty) return 'All members';
    return ids.length == 1 ? '1 person' : '${ids.length} people';
  }

  Future<void> _openRosterPicker() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) => MembersPage(
          attendanceRepository: widget.attendanceRepository,
          sessionRepository: widget.sessionRepository,
          selectionMode: true,
          initialSelectedMemberIds: _selectedMemberIds.toList(),
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedMemberIds = result.toSet());
    }
  }

  Widget _buildBottomButton(BuildContext context, {required bool isEditing}) {
    final c = context.conv;
    final label = isEditing ? 'Save changes' : 'Create event';
    final btn = SizedBox(
      width: double.infinity,
      child: Material(
        color: c.primary,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('save_event_button'),
          onTap: _saveEvent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: c.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: widget.disableAnimations
            ? btn
            : Hero(tag: 'fab', child: Material(color: Colors.transparent, child: btn)),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      key: const ValueKey('skeleton'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        AppShimmer(
          width: 220,
          height: 40,
          borderRadius: BorderRadius.circular(8),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 6),
        AppShimmer(
          width: 180,
          height: 40,
          borderRadius: BorderRadius.circular(8),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 28),
        _skelField(56),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _skelField(56)),
            const SizedBox(width: 10),
            Expanded(child: _skelField(56)),
          ],
        ),
        const SizedBox(height: 22),
        _skelField(48),
        const SizedBox(height: 22),
        _skelField(56),
      ],
    );
  }

  Widget _skelField(double height) => AppShimmer(
        width: double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(14),
        disableAnimations: widget.disableAnimations,
      );
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: AppTypography.fraunces(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: c.ink,
      ),
      decoration: InputDecoration(
        hintText: "Lord's Table",
        hintStyle: AppTypography.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          color: c.ink3,
        ),
        filled: true,
        fillColor: c.cardSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter an event name';
        }
        return null;
      },
    );
  }
}

/// One of the two "Group roster by" preset option cards in the event editor.
class _GroupingCard extends StatelessWidget {
  const _GroupingCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Material(
      color: active
          ? Color.alphaBlend(c.primary.withValues(alpha: 0.08), c.cardSoft)
          : c.cardSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? c.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: active ? c.primary : c.ink3),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.geist(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                hint,
                style: AppTypography.geist(fontSize: 11.5, color: c.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
