import 'package:flutter/material.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';
import '../application/reminder_settings_controller.dart';
import '../domain/reminder_offset_preset.dart';

/// Convocation-styled settings section for Attendance Reminders.
class RemindersSettingsSection extends StatelessWidget {
  const RemindersSettingsSection({
    super.key,
    required this.controller,
  });

  final ReminderSettingsController controller;

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
                              'Remind to record attendance for scheduled events',
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
                        onChanged: (val) => controller.setEnabled(val),
                      ),
                    ],
                  ),
                  if (controller.enabled) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REMINDER OFFSET',
                                  style: AppTypography.eyebrow(
                                    fontSize: 10,
                                    color: c.ink3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Time after scheduled start',
                                  style: AppTypography.geist(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: c.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<ReminderOffsetPreset>(
                              value: controller.offset,
                              alignment: Alignment.centerRight,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: c.ink3,
                              ),
                              style: AppTypography.geist(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.primary,
                              ),
                              selectedItemBuilder: (context) {
                                return ReminderOffsetPreset.values.map((preset) {
                                  return Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      preset.label,
                                      style: AppTypography.geist(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.primary,
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                              items: ReminderOffsetPreset.values.map((preset) {
                                return DropdownMenuItem(
                                  value: preset,
                                  alignment: Alignment.centerRight,
                                  child: Text(preset.label),
                                );
                              }).toList(),
                              onChanged: (preset) {
                                if (preset != null) {
                                  controller.setOffset(preset);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
