import '../models/member.dart';

/// The in-memory name index derived from an Event Roster: the given name and
/// Attendee Surname of each member for the marking grid, and the substring
/// matching behind the session summary's search.
///
/// Precomputes name tokens upon initialization so that grid rebuilds stay thin
/// and free of repeated string work.
class ActiveRosterIndex {
  ActiveRosterIndex({required List<Member> members}) {
    for (final m in members) {
      final last = extractLastName(m.displayName);
      _lastNameById[m.id] = last;
      _givenNameById[m.id] = extractGivenName(m.displayName);
      _hasDistinctSurnameById[m.id] =
          last.isNotEmpty && last != m.displayName.trim();
    }
  }

  final Map<String, String> _lastNameById = {};
  final Map<String, String> _givenNameById = {};
  final Map<String, bool> _hasDistinctSurnameById = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Static Name Tokenizer and Parsing Utilities
  // ─────────────────────────────────────────────────────────────────────────

  /// Splits [displayName] into non-empty whitespace-delimited tokens.
  static List<String> tokenizeName(String displayName) {
    return displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// The Attendee Surname: the last whitespace-delimited token of [displayName],
  /// or the entire string if single-token. Returns an empty string for blank input.
  static String extractLastName(String displayName) {
    final parts = tokenizeName(displayName);
    if (parts.isEmpty) return '';
    return parts.last;
  }

  /// The given name(s): all whitespace-delimited tokens except the last of
  /// [displayName], or the entire string if single-token. Returns an empty string
  /// for blank input.
  static String extractGivenName(String displayName) {
    final parts = tokenizeName(displayName);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return parts.sublist(0, parts.length - 1).join(' ');
  }

  /// How well [haystackLower] matches [cleanQueryLower] — **lower is better**:
  ///
  /// * `0` — [haystackLower] starts with the query
  /// * `1` — a later word in [haystackLower] starts with the query (after
  ///   space, hyphen, or apostrophe)
  /// * `2` — the query appears somewhere else inside [haystackLower]
  ///
  /// `null` when the query does not appear at all, and for a blank query. Both
  /// arguments must be pre-lowercased and [cleanQueryLower] pre-trimmed,
  /// avoiding redundant string work in search loops.
  static int? calculateMatchRankLowercased(
    String haystackLower,
    String cleanQueryLower,
  ) {
    if (cleanQueryLower.isEmpty) return null;
    final at = haystackLower.indexOf(cleanQueryLower);
    if (at < 0) return null;
    if (at == 0) return 0;
    for (var i = at;
        i >= 0;
        i = haystackLower.indexOf(cleanQueryLower, i + 1)) {
      if (i <= 0) continue;
      final before = haystackLower[i - 1];
      if (before == ' ' || before == '-' || before == "'") return 1;
    }
    return 2;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Query Interface
  // ─────────────────────────────────────────────────────────────────────────

  /// Display title for [member], returning given name(s) when the Attendee Surname
  /// is distinct and serves as subtitle, or the full display name for single-token names.
  String displayNameFor(Member member) {
    if (hasDistinctSurname(member)) {
      return givenNameFor(member);
    }
    return member.displayName;
  }

  /// The given name of [member].
  String givenNameFor(Member member) =>
      _givenNameById[member.id] ?? extractGivenName(member.displayName);

  /// The Attendee Surname of [member].
  String surnameFor(Member member) =>
      _lastNameById[member.id] ?? extractLastName(member.displayName);

  /// Whether [member] has a distinct surname from their given name.
  bool hasDistinctSurname(Member member) {
    final cached = _hasDistinctSurnameById[member.id];
    if (cached != null) return cached;
    final last = surnameFor(member);
    return last.isNotEmpty && last != member.displayName.trim();
  }

  /// Whether pre-lowercased [haystackLower] matches [cleanQueryLower].
  ///
  /// Safely trims and lowercases [cleanQueryLower] while remaining zero-allocation
  /// when [cleanQueryLower] is already pre-trimmed and lowercased.
  bool matchesLowercased(String haystackLower, String cleanQueryLower) {
    final q = cleanQueryLower.trim().toLowerCase();
    if (q.isEmpty) return true;
    return calculateMatchRankLowercased(haystackLower.toLowerCase(), q) !=
        null;
  }
}
