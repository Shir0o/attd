/// What a "Followed up" tick answered.
///
/// A tick is not a permanent dismissal: it answers one flag at one point in a
/// person's attendance. It records the flag (by enum name) and the day the
/// person was last present when it was ticked, so a person comes back when
/// they trigger a different rule, or the same rule after attending again.
///
/// The flag is kept as its name rather than a `CheckOnFlag` so this model
/// stays importable from `Event` without a cycle.
class CheckOnFollowUp {
  const CheckOnFollowUp({required this.flag, required this.lastPresent});

  /// `CheckOnFlag.name` of the flag that was ticked.
  final String flag;

  /// Calendar day of the person's last present mark when ticked.
  final DateTime lastPresent;

  bool answers(String flagName, DateTime present) =>
      flag == flagName &&
      lastPresent.year == present.year &&
      lastPresent.month == present.month &&
      lastPresent.day == present.day;

  Map<String, dynamic> toJson() => {
        'flag': flag,
        'lastPresent': '${lastPresent.year.toString().padLeft(4, '0')}-'
            '${lastPresent.month.toString().padLeft(2, '0')}-'
            '${lastPresent.day.toString().padLeft(2, '0')}',
      };

  /// Null when [json] is not a well-formed tick, so one bad entry never
  /// blocks an event from loading.
  static CheckOnFollowUp? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final flag = json['flag'];
    final raw = json['lastPresent'];
    if (flag is! String || raw is! String) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    return CheckOnFollowUp(flag: flag, lastPresent: date);
  }

  @override
  bool operator ==(Object other) =>
      other is CheckOnFollowUp &&
      flag == other.flag &&
      answers(flag, other.lastPresent);

  @override
  int get hashCode =>
      Object.hash(flag, lastPresent.year, lastPresent.month, lastPresent.day);
}
