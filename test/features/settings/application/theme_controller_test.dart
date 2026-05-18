import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads a saved theme mode from preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
    });
    final prefs = await SharedPreferences.getInstance();

    final controller = ThemeController(prefs);

    expect(controller.themeMode, ThemeMode.dark);
  });

  test('ignores null and unchanged theme updates', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ThemeController(prefs);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.updateThemeMode(null);
    await controller.updateThemeMode(ThemeMode.system);

    expect(controller.themeMode, ThemeMode.system);
    expect(notifications, 0);
    expect(prefs.getInt('theme_mode'), isNull);
  });

  test('persists changed theme mode and notifies listeners', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = ThemeController(prefs);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.updateThemeMode(ThemeMode.light);

    expect(controller.themeMode, ThemeMode.light);
    expect(notifications, 1);
    expect(prefs.getInt('theme_mode'), ThemeMode.light.index);
  });
}
