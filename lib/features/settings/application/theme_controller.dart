import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _loadTheme();
  }

  final SharedPreferences _prefs;
  static const _themeKey = 'theme_mode';
  static const _reportExportEnabledKey = 'report_export_enabled';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isReportExportEnabled = false;
  bool get isReportExportEnabled => _isReportExportEnabled;

  void _loadTheme() {
    final themeIndex = _prefs.getInt(_themeKey);
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    _isReportExportEnabled = _prefs.getBool(_reportExportEnabledKey) ?? false;
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;
    notifyListeners();
    await _prefs.setInt(_themeKey, newThemeMode.index);
  }

  Future<void> updateReportExportEnabled(bool enabled) async {
    if (enabled == _isReportExportEnabled) return;
    _isReportExportEnabled = enabled;
    notifyListeners();
    await _prefs.setBool(_reportExportEnabledKey, enabled);
  }
}

