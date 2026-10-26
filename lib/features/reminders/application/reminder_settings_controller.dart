import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_offset_preset.dart';

/// Manages persisted settings for attendance reminder notifications.
class ReminderSettingsController extends ChangeNotifier {
  ReminderSettingsController({required SharedPreferences prefs})
      : _prefs = prefs {
    _loadSettings();
  }

  static const String enabledKey = 'attendance_reminders_enabled';
  static const String offsetMinutesKey = 'attendance_reminders_offset_minutes';

  final SharedPreferences _prefs;

  bool _enabled = false;
  ReminderOffsetPreset _offset = ReminderOffsetPreset.oneHour;

  bool get enabled => _enabled;
  ReminderOffsetPreset get offset => _offset;

  void _loadSettings() {
    _enabled = _prefs.getBool(enabledKey) ?? false;
    final minutes = _prefs.getInt(offsetMinutesKey);
    if (minutes != null) {
      _offset = ReminderOffsetPreset.fromMinutes(minutes);
    } else {
      _offset = ReminderOffsetPreset.oneHour;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await _prefs.setBool(enabledKey, value);
    notifyListeners();
  }

  Future<void> setOffset(ReminderOffsetPreset preset) async {
    if (_offset == preset) return;
    _offset = preset;
    await _prefs.setInt(offsetMinutesKey, preset.duration.inMinutes);
    notifyListeners();
  }
}
