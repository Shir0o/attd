import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String _frequency = 'Weekly';

  final List<String> _frequencies = [
    'One-time',
    'Weekly',
    'Bi-weekly',
    'Monthly',
  ];

  DateTime _selectedDate = DateTime.now();

  final Set<String> _selectedDays = {};
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
    // Set default day(s) to current day
    final now = DateTime.now();
    // weekday is 1-7 (Mon-Sun), we need to map to our list
    // 1=Mon, 7=Sun.
    // List index: 0=Sun, 1=Mon...
    // So if weekday=7 (Sun), index=0. If weekday=1 (Mon), index=1.
    int index = now.weekday == 7 ? 0 : now.weekday;
    if (index >= 0 && index < _daysOfWeek.length) {
      _selectedDays.add(_daysOfWeek[index]);
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
      final newEvent = Event(
        id: const Uuid().v4(),
        title: _nameController.text,
        time: _selectedTime,
        frequency: _frequency,
        oneTimeDate: _frequency == 'One-time' ? _selectedDate : null,
        repeatingDays: _frequency != 'One-time' ? _selectedDays.toList() : [],
        createdAt: DateTime.now(),
      );

      try {
        await widget.eventRepository.createEvent(newEvent);
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
    const tertiaryContainerColor = Color(0xFFFFD8E4); // From Stitch CSS
    const onTertiaryContainerColor = Color(0xFF31111D); // From Stitch CSS

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Event',
          style: TextStyle(
            color: onSurfaceColor,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveEvent,
            child: const Text(
              'Save',
              style: TextStyle(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Name
                    _buildInputContainer(
                      label: 'Event Name',
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 16,
                          color: onTertiaryContainerColor,
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
                      tertiaryContainerColor: tertiaryContainerColor,
                      onSurfaceVariantColor: onSurfaceVariantColor,
                      onTertiaryContainerColor: onTertiaryContainerColor,
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
                    GestureDetector(
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
                                  color: onTertiaryContainerColor,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.schedule,
                              color: onSurfaceVariantColor,
                            ),
                          ],
                        ),
                        tertiaryContainerColor: tertiaryContainerColor,
                        onSurfaceVariantColor: onSurfaceVariantColor,
                        onTertiaryContainerColor: onTertiaryContainerColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Frequency
                    _buildInputContainer(
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
                            color: onTertiaryContainerColor,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _frequency = newValue;
                              });
                            }
                          },
                          items: _frequencies.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      tertiaryContainerColor: tertiaryContainerColor,
                      onSurfaceVariantColor: onSurfaceVariantColor,
                      onTertiaryContainerColor: onTertiaryContainerColor,
                    ),

                    const SizedBox(height: 24),

                    // Day / Date
                    if (_frequency == 'One-time')
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: _buildInputContainer(
                          label: 'Date',
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  // Requires intl package or manual formatting.
                                  // Using basic string interpolation for now to avoid import if possible,
                                  // but intl is better. The user removed intl import earlier.
                                  // Let's use a helper or simple format.
                                  "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: onTertiaryContainerColor,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today,
                                color: onSurfaceVariantColor,
                              ),
                            ],
                          ),
                          tertiaryContainerColor: tertiaryContainerColor,
                          onSurfaceVariantColor: onSurfaceVariantColor,
                          onTertiaryContainerColor: onTertiaryContainerColor,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
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
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Create Event',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputContainer({
    required String label,
    required Widget child,
    required Color tertiaryContainerColor,
    required Color onSurfaceVariantColor,
    required Color onTertiaryContainerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tertiaryContainerColor,
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
              color: onTertiaryContainerColor.withAlpha(179), // ~70% opacity
            ),
          ),
          child,
        ],
      ),
    );
  }
}
