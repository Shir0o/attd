import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({
    super.key,
    required this.eventRepository,
    this.eventToEdit,
  });

  final EventRepository eventRepository;
  final Event? eventToEdit;

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
  bool _isLoading = true;

  final List<String> _frequencies = [
    'One-time',
    'Weekly',
    'Bi-weekly',
    'Monthly',
  ];

  final List<String> _daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;

    if (event != null) {
      // Editing existing event
      _nameController = TextEditingController(text: event.title);
      _selectedTime = event.time;
      _frequency = event.frequency;
      _selectedDate = event.oneTimeDate ?? DateTime.now();
      _selectedDays = event.repeatingDays.toSet();
    } else {
      // Creating new event
      _nameController = TextEditingController();
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
      _frequency = 'Weekly';
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedDays = {};

      // Set default day(s) to current day
      int index = now.weekday == 7 ? 0 : now.weekday;
      if (index >= 0 && index < _daysOfWeek.length) {
        _selectedDays.add(_daysOfWeek[index]);
      }
    }

    _loadData();
  }

  Future<void> _loadData() async {
    final startTime = DateTime.now();
    
    // Ensure minimum loading duration for visual consistency
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 250) - elapsed;
    if (remaining > Duration.zero) {
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.eventToEdit != null;
      final eventId = isEditing ? widget.eventToEdit!.id : const Uuid().v4();
      final createdAt = isEditing
          ? widget.eventToEdit!.createdAt
          : DateTime.now();

      final event = Event(
        id: eventId,
        title: _nameController.text.trim(),
        time: _selectedTime,
        frequency: _frequency,
        oneTimeDate: _frequency == 'One-time' ? _selectedDate : null,
        repeatingDays: _frequency != 'One-time' ? _selectedDays.toList() : [],
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving event: $e')));
        }
      }
    }
  }

  Future<void> _deleteEvent() async {
    final event = widget.eventToEdit;
    if (event == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event'),
            content: Text('Are you sure you want to delete "${event.title}"?'),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting event: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... rest of build method
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Event' : 'New Event',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
              onPressed: _deleteEvent,
              tooltip: 'Delete Event',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Column(
                key: ValueKey(_isLoading),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Name
                  _isLoading
                      ? _buildSkeletonInput(showRequired: true)
                      : _buildInputContainer(
                          label: 'Event Name',
                          child: TextFormField(
                            controller: _nameController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            style: TextStyle(
                              fontSize: 18,
                              color: colorScheme.onSurface,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Enter event name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an event name';
                              }
                              return null;
                            },
                          ),
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          onSurfaceVariantColor: colorScheme.onSurfaceVariant,
                          textColor: colorScheme.onSurface,
                        ),
                  if (!_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 4,
                        bottom: 24,
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                  // Event Time
                  _isLoading
                      ? _buildSkeletonInput()
                      : GestureDetector(
                          onTap: () => _selectTime(context),
                          child: _buildInputContainer(
                            label: 'Event Time',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.schedule,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                            backgroundColor: colorScheme.surfaceContainerHigh,
                            onSurfaceVariantColor: colorScheme.onSurfaceVariant,
                            textColor: colorScheme.onSurface,
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Frequency
                  _isLoading
                      ? _buildSkeletonInput()
                      : _buildInputContainer(
                          label: 'Frequency',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _frequency,
                              isExpanded: true,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurface,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _frequency = newValue;
                                  });
                                }
                              },
                              items: _frequencies
                                  .map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          onSurfaceVariantColor: colorScheme.onSurfaceVariant,
                          textColor: colorScheme.onSurface,
                        ),

                  const SizedBox(height: 24),

                  // Day / Date
                  if (_isLoading)
                    _buildSkeletonInput()
                  else if (_frequency == 'One-time')
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: _buildInputContainer(
                        label: 'Date',
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'yyyy-MM-dd',
                                ).format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        onSurfaceVariantColor: colorScheme.onSurfaceVariant,
                        textColor: colorScheme.onSurface,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8),
                          child: Text(
                            'Repeats on',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: List.generate(_daysOfWeek.length, (
                            index,
                          ) {
                            final dayName = _daysOfWeek[index];
                            final isSelected = _selectedDays.contains(
                              dayName,
                            );
                            final label = dayName.substring(0, 1);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDays.remove(dayName);
                                  } else {
                                    _selectedDays.add(dayName);
                                  }
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHigh,
                                ),
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Hero(
              tag: 'fab',
              child: ElevatedButton(
                key: const ValueKey('save_event_button'),
                onPressed: _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Event',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonInput({bool showRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        if (showRequired)
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 4, bottom: 24),
            child: SizedBox(
              width: 60,
              height: 16,
            ), // Spacer to match 'Required' text height and padding
          ),
      ],
    );
  }

  Widget _buildInputContainer({
    required String label,
    required Widget child,
    required Color backgroundColor,
    required Color onSurfaceVariantColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: Border(bottom: BorderSide(color: onSurfaceVariantColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: textColor.withAlpha(179), // ~70% opacity
            ),
          ),
          child,
        ],
      ),
    );
  }
}
