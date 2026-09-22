/// Per-event Insights presets.
///
/// A preset, never derived data: these are inputs to the Insights computation,
/// not cached results of it. They live on the Event beside the roster grouping
/// and marking mode presets and travel with it through backup, restore and
/// sharing, so a metric means the same thing wherever the event is opened.
/// See `docs/adr/0007-per-event-insights-configuration.md`.
library;

/// How far back Insights looks, counted in most-recent sessions.
///
/// One range governs every section: a chart covering a year above a Regulars
/// list silently meaning "last 8" is two answers to what looks like one
/// question.
enum InsightsRange {
  twelveWeeks(12, '12 wk'),
  sixMonths(26, '6 mo'),
  year(52, 'Year');

  const InsightsRange(this.sessionCount, this.label);

  /// Most-recent sessions included.
  final int sessionCount;
  final String label;
}

/// A section of the Insights page.
enum InsightsSection {
  rateOverTime,
  extremes,
  regulars,
  lapsed,
  guests,
  lateness,
  growth,
  memberTable,
  firstTimers,
  streaks,
  medianSize,
}

/// Sections shown when the user has not chosen otherwise.
///
/// Everything else is one toggle away. [InsightsSection.guests] and
/// [InsightsSection.lateness] are default-on but additionally suppress
/// themselves at zero, so they cost nothing on an event that has neither.
const kDefaultVisibleSections = <InsightsSection>{
  InsightsSection.rateOverTime,
  InsightsSection.extremes,
  InsightsSection.regulars,
  InsightsSection.lapsed,
  InsightsSection.memberTable,
  InsightsSection.guests,
  InsightsSection.lateness,
};

class InsightsConfig {
  const InsightsConfig({
    this.range,
    this.regularThresholdPercent,
    this.regularWindow,
    this.lapsedConsecutiveMisses,
    this.lapsedMinimumPriorSessions,
    this.visibleSections,
  });

  /// Every field is nullable-means-unchosen so an existing event picks up the
  /// defaults with no migration, exactly as `markingMode` did.
  final InsightsRange? range;
  final int? regularThresholdPercent;
  final int? regularWindow;
  final int? lapsedConsecutiveMisses;
  final int? lapsedMinimumPriorSessions;
  final Set<InsightsSection>? visibleSections;

  InsightsRange get resolvedRange => range ?? InsightsRange.twelveWeeks;

  int get resolvedRegularThresholdPercent => regularThresholdPercent ?? 80;

  int get resolvedRegularWindow => regularWindow ?? 8;

  int get resolvedLapsedConsecutiveMisses => lapsedConsecutiveMisses ?? 3;

  /// Sessions of prior history required before any lapsed verdict is rendered.
  /// Below this the section reports insufficient data rather than a false
  /// negative about someone who simply has no record yet.
  int get resolvedLapsedMinimumPriorSessions => lapsedMinimumPriorSessions ?? 4;

  Set<InsightsSection> get resolvedVisibleSections =>
      visibleSections ?? kDefaultVisibleSections;

  bool get isEmpty =>
      range == null &&
      regularThresholdPercent == null &&
      regularWindow == null &&
      lapsedConsecutiveMisses == null &&
      lapsedMinimumPriorSessions == null &&
      visibleSections == null;

  InsightsConfig copyWith({
    InsightsRange? range,
    int? regularThresholdPercent,
    int? regularWindow,
    int? lapsedConsecutiveMisses,
    int? lapsedMinimumPriorSessions,
    Set<InsightsSection>? visibleSections,
  }) {
    return InsightsConfig(
      range: range ?? this.range,
      regularThresholdPercent:
          regularThresholdPercent ?? this.regularThresholdPercent,
      regularWindow: regularWindow ?? this.regularWindow,
      lapsedConsecutiveMisses:
          lapsedConsecutiveMisses ?? this.lapsedConsecutiveMisses,
      lapsedMinimumPriorSessions:
          lapsedMinimumPriorSessions ?? this.lapsedMinimumPriorSessions,
      visibleSections: visibleSections ?? this.visibleSections,
    );
  }

  /// Discrete keys rather than one blob: the Drive merge is per file and
  /// last-write-wins, so a blob would make one person's threshold change
  /// silently revert another's section toggle.
  Map<String, dynamic> toJson() {
    return {
      if (range != null) 'insightsRange': range!.name,
      if (regularThresholdPercent != null)
        'insightsRegularThresholdPercent': regularThresholdPercent,
      if (regularWindow != null) 'insightsRegularWindow': regularWindow,
      if (lapsedConsecutiveMisses != null)
        'insightsLapsedConsecutiveMisses': lapsedConsecutiveMisses,
      if (lapsedMinimumPriorSessions != null)
        'insightsLapsedMinimumPriorSessions': lapsedMinimumPriorSessions,
      if (visibleSections != null)
        'insightsVisibleSections': visibleSections!.map((s) => s.name).toList(),
    };
  }

  factory InsightsConfig.fromJson(Map<String, dynamic> json) {
    InsightsRange? range;
    final rangeName = json['insightsRange'] as String?;
    if (rangeName != null) {
      for (final r in InsightsRange.values) {
        if (r.name == rangeName) {
          range = r;
          break;
        }
      }
    }

    Set<InsightsSection>? sections;
    final sectionNames = json['insightsVisibleSections'] as List<dynamic>?;
    if (sectionNames != null) {
      sections = <InsightsSection>{};
      for (final raw in sectionNames) {
        for (final s in InsightsSection.values) {
          if (s.name == raw) {
            sections.add(s);
            break;
          }
        }
      }
    }

    return InsightsConfig(
      range: range,
      regularThresholdPercent: json['insightsRegularThresholdPercent'] as int?,
      regularWindow: json['insightsRegularWindow'] as int?,
      lapsedConsecutiveMisses: json['insightsLapsedConsecutiveMisses'] as int?,
      lapsedMinimumPriorSessions:
          json['insightsLapsedMinimumPriorSessions'] as int?,
      visibleSections: sections,
    );
  }
}
