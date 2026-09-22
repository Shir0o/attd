import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/sessions/domain/insights_config.dart';

Event _event({InsightsConfig? config}) => Event(
      id: 'e1',
      title: 'Wednesday Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      insightsConfig: config,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('Insights configuration on the Event', () {
    test('an event that has never been configured carries none', () {
      final restored = Event.fromJson(_event().toJson());

      expect(restored.insightsConfig, isNull);
      // Defaults still apply, so nothing needs migrating.
      expect(
        restored.resolvedInsightsConfig.resolvedRegularThresholdPercent,
        80,
      );
      expect(restored.resolvedInsightsConfig.resolvedRange,
          InsightsRange.twelveWeeks);
    });

    test('round-trips every setting through JSON', () {
      final config = const InsightsConfig(
        range: InsightsRange.year,
        regularThresholdPercent: 60,
        regularWindow: 12,
        lapsedConsecutiveMisses: 2,
        lapsedMinimumPriorSessions: 6,
        visibleSections: {
          InsightsSection.rateOverTime,
          InsightsSection.streaks,
        },
      );

      final restored = Event.fromJson(_event(config: config).toJson());
      final got = restored.insightsConfig;

      expect(got, isNotNull);
      expect(got!.range, InsightsRange.year);
      expect(got.regularThresholdPercent, 60);
      expect(got.regularWindow, 12);
      expect(got.lapsedConsecutiveMisses, 2);
      expect(got.lapsedMinimumPriorSessions, 6);
      expect(got.visibleSections, {
        InsightsSection.rateOverTime,
        InsightsSection.streaks,
      });
    });

    test('keeps each setting under its own key, so one edit cannot revert another', () {
      // Discrete keys rather than a blob: the Drive merge is per file and
      // last-write-wins (ADR 0007).
      final json = _event(
        config: const InsightsConfig(
          regularThresholdPercent: 70,
          lapsedConsecutiveMisses: 4,
        ),
      ).toJson();

      expect(json['insightsRegularThresholdPercent'], 70);
      expect(json['insightsLapsedConsecutiveMisses'], 4);
      // Unset settings write no key at all.
      expect(json.containsKey('insightsRegularWindow'), isFalse);
      expect(json.containsKey('insightsVisibleSections'), isFalse);
    });

    test('survives copyWith alongside the other event presets', () {
      final updated = _event().copyWith(
        insightsConfig: const InsightsConfig(regularWindow: 10),
      );

      expect(updated.insightsConfig?.regularWindow, 10);
      expect(updated.title, 'Wednesday Study');
    });

    test('ignores settings it does not recognise', () {
      final json = _event().toJson()
        ..['insightsRange'] = 'someFutureRange'
        ..['insightsVisibleSections'] = ['regulars', 'notASection'];

      final restored = Event.fromJson(json);

      expect(restored.insightsConfig?.range, isNull);
      expect(restored.insightsConfig?.visibleSections,
          {InsightsSection.regulars});
    });
  });
}
