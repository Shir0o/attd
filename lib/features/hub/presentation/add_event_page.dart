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
      _selectedDate = DateTime.now();
      _selectedDays = {};

      // Set default day(s) to current day
      final now = DateTime.now();
      int index = now.weekday == 7 ? 0 : now.weekday;
      if (index >= 0 && index < _daysOfWeek.length) {
        _selectedDays.add(_daysOfWeek[index]);
      }
    }

    // Deliberate artificial delay to ensure skeleton is visible and Hero finishes smoothly
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
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
        title: _nameController.text,
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

  @override
  Widget build(BuildContext context) {
    // Stitch Colors matching HubPage
    const primaryColor = Color(0xFF6750A4);
    const onPrimaryColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFFEF7FF);
    const onSurfaceColor = Color(0xFF1D1B20);
    const onSurfaceVariantColor = Color(0xFF49454F);
    const surfaceContainerHighColor = Color(0xFFECE6F0);

    final isEditing = widget.eventToEdit != null;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Event' : 'New Event',
          style: const TextStyle(
            color: onSurfaceColor,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveEvent,
            child: Text(
              isEditing ? 'Save' : 'Save',
              style: const TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(_isLoading),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event Name
                      _isLoading
                          ? _buildSkeletonInput()
                          : _buildInputContainer(
                              label: 'Event Name',
                              child: TextFormField(
                                controller: _nameController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: onSurfaceColor,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Enter event name',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an event name';
                                  }
                                  return null;
                                },
                              ),
                              backgroundColor: surfaceContainerHighColor,
                              onSurfaceVariantColor: onSurfaceVariantColor,
                              textColor: onSurfaceColor,
                            ),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 4, bottom: 24),
                        child: Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: onSurfaceVariantColor,
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
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: onSurfaceColor,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.schedule,
                                      color: onSurfaceVariantColor,
                                    ),
                                  ],
                                ),
                                backgroundColor: surfaceContainerHighColor,
                                onSurfaceVariantColor: onSurfaceVariantColor,
                                textColor: onSurfaceColor,
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
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: onSurfaceVariantColor,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: onSurfaceColor,
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
                              backgroundColor: surfaceContainerHighColor,
                              onSurfaceVariantColor: onSurfaceVariantColor,
                              textColor: onSurfaceColor,
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
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: onSurfaceColor,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today,
                                  color: onSurfaceVariantColor,
                                ),
                              ],
                            ),
                            backgroundColor: surfaceContainerHighColor,
                            onSurfaceVariantColor: onSurfaceVariantColor,
                            textColor: onSurfaceColor,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 16, bottom: 8),
                              child: Text(
                                'Repeats on',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: onSurfaceVariantColor,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? primaryColor
                                          : const Color(
                                              0xFFECE6F0,
                                            ), // surface-container-high
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: isSelected
                                              ? onPrimaryColor
                                              : onSurfaceVariantColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Hero(
                tag: 'fab',
                child: ElevatedButton.icon(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: onPrimaryColor,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: Icon(isEditing ? Icons.save : Icons.add, size: 20),
                  label: Text(
                    isEditing ? 'Save Changes' : 'Create Event',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonInput() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withAlpha(179), // ~70% opacity
            ),
          ),
          child,
        ],
      ),
    );
  }
}
