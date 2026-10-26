/// Preset offsets for attendance reminder notifications relative to event start time.
enum ReminderOffsetPreset {
  atStart(Duration.zero, 'At event start'),
  fifteenMinutes(Duration(minutes: 15), '15 minutes after'),
  thirtyMinutes(Duration(minutes: 30), '30 minutes after'),
  oneHour(Duration(hours: 1), '1 hour after'),
  twoHours(Duration(hours: 2), '2 hours after');

  const ReminderOffsetPreset(this.duration, this.label);

  final Duration duration;
  final String label;

  static ReminderOffsetPreset fromMinutes(int minutes) {
    for (final preset in values) {
      if (preset.duration.inMinutes == minutes) {
        return preset;
      }
    }
    return ReminderOffsetPreset.oneHour;
  }
}
