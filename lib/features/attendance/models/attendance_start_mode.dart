/// How a new attendance session should be pre-seeded.
enum AttendanceStartMode {
  /// Pre-mark every member absent. Best when most of the roster will not show up.
  allAbsent,

  /// Pre-mark every member present. Best when nearly everyone is expected.
  allPresent,

  /// Use each member's per-member `defaultStatus`. The neutral default.
  perMemberDefault,
}

extension AttendanceStartModeLabel on AttendanceStartMode {
  String get label {
    switch (this) {
      case AttendanceStartMode.allAbsent:
        return 'Start with all absent';
      case AttendanceStartMode.allPresent:
        return 'Start with all present';
      case AttendanceStartMode.perMemberDefault:
        return 'Smart defaults (from past 8 sessions)';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceStartMode.allAbsent:
        return 'All absent';
      case AttendanceStartMode.allPresent:
        return 'All present';
      case AttendanceStartMode.perMemberDefault:
        return 'Smart';
    }
  }

  String get description {
    switch (this) {
      case AttendanceStartMode.allAbsent:
        return 'Good when only a few people came — only mark the ones present.';
      case AttendanceStartMode.allPresent:
        return 'Good when nearly everyone came — only mark the few absentees.';
      case AttendanceStartMode.perMemberDefault:
        return 'Pre-marks members who are consistently present or absent (≥80% over the last 8 sessions). Mixed patterns are left for you to confirm.';
    }
  }
}
