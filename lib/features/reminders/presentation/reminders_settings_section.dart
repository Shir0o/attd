import 'package:flutter/material.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../application/attendance_reminder_service.dart';
import '../application/reminder_settings_controller.dart';

/// Convocation-styled settings section for Attendance Reminders.
class RemindersSettingsSection extends StatelessWidget {
  const RemindersSettingsSection({
    super.key,
    required this.controller,
    this.reminderService,
  });

  final ReminderSettingsController controller;
  final AttendanceReminderService? reminderService;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConvCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: controller.enabled
                              ? c.primary.withValues(alpha: 0.12)
                              : c.bg2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: controller.enabled ? c.primary : c.ink4,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Reminders',
                              style: AppTypography.geist(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'One hour after a scheduled event starts, if attendance is not recorded',
                              style: AppTypography.geist(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: c.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConvToggle(
                        value: controller.enabled,
                        onChanged: (val) async {
                          if (val) {
                            final granted = await reminderService?.requestPermissions() ?? true;
                            if (!granted) {
                              return;
                            }
                          }
                          await controller.setEnabled(val);
                          await reminderService?.syncReminders();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
