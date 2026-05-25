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
        return 'Use per-member defaults';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceStartMode.allAbsent:
        return 'All absent';
      case AttendanceStartMode.allPresent:
        return 'All present';
      case AttendanceStartMode.perMemberDefault:
        return 'Per-member';
    }
  }

  String get description {
    switch (this) {
      case AttendanceStartMode.allAbsent:
        return 'Good when only a few people came — only mark the ones present.';
      case AttendanceStartMode.allPresent:
        return 'Good when nearly everyone came — only mark the few absentees.';
      case AttendanceStartMode.perMemberDefault:
        return 'Use each member\'s saved default attendance status.';
    }
  }
}
