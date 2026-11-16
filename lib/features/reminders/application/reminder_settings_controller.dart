import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persisted settings for attendance reminder notifications.
class ReminderSettingsController extends ChangeNotifier {
  ReminderSettingsController({required SharedPreferences prefs})
      : _prefs = prefs {
    _loadSettings();
  }

  static const String enabledKey = 'attendance_reminders_enabled';

  final SharedPreferences _prefs;

  bool _enabled = false;

  bool get enabled => _enabled;

  void _loadSettings() {
    _enabled = _prefs.getBool(enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await _prefs.setBool(enabledKey, value);
    notifyListeners();
  }
}
