import '../../../../data/session.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/member_default_resolver.dart';

/// One roster entry a fast-marking search can return — a member, plus the
/// family they belong to when there is one.
typedef SearchEntry = ({Member member, String? familyName});

/// The in-memory search, query, and ranking index derived from an Event Roster
/// and historical sessions, providing tokenized surname matching, initials
/// lookup, and likelihood ordering behind a single query interface.
///
/// Precomputes search and token structures upon initialization so that fast-marking
/// interactions remain thin, performant, and rebuild-overhead free.
class ActiveRosterIndex {
  ActiveRosterIndex({
    required List<Member> members,
    List<Family> families = const [],
    List<Session> recentSessions = const [],
  })  : _families = List.unmodifiable(families),
        _members = List.unmodifiable(members) {
    // 1. Precompute attendee names and surname tokens
    for (final m in _members) {
      final last = extractLastName(m.displayName);
      final given = extractGivenName(m.displayName);
      _lastNameById[m.id] = last;
      _givenNameById[m.id] = given;
      _hasDistinctSurnameById[m.id] =
          last.isNotEmpty && last != m.displayName.trim();
      _initialsById[m.id] = extractInitials(m.displayName);
      _ratesById[m.id] = attendanceRate(m.id, recentSessions);
    }

    // 2. Map family names for members (ignoring auto-singletons)
    for (final f in _families) {
      final familyName = f.isAutoSingleton ? null : f.displayName;
      for (final m in f.members) {
        _familyNameById[m.id] = familyName;
      }
    }

    // 3. Precompute likelihood ordering
    final ranked = rankByLikelihood(_members, recentSessions);
    for (var i = 0; i < ranked.length; i++) {
      likelihoodPriority[ranked[i].id] = i;
    }

    const unranked = 1 << 30;
    _likelyHereMembers = List.unmodifiable(
      [..._members]..sort((a, b) {
          final byOrder = (likelihoodPriority[a.id] ?? unranked).compareTo(
            likelihoodPriority[b.id] ?? unranked,
          );
          if (byOrder != 0) return byOrder;
          return a.displayNameLowercase.compareTo(
            b.displayNameLowercase,
          );
        }),
    );

    // 4. Precompute search entries
    _searchEntries = List.unmodifiable([
      for (final m in _likelyHereMembers)
        (member: m, familyName: _familyNameById[m.id]),
    ]);

    // 5. Precompute full initials index
    final index = <String, Set<String>>{};
    for (final m in _members) {
      final initials = _initialsById[m.id]!;
      if (initials.first.isEmpty) continue;
      index.putIfAbsent(initials.first, () => <String>{}).add(initials.last);
    }
    _fullInitialsIndex = Map.unmodifiable(index);
  }

  final List<Member> _members;
  final List<Family> _families;

  final Map<String, String> _lastNameById = {};
  final Map<String, String> _givenNameById = {};
  final Map<String, bool> _hasDistinctSurnameById = {};
  final Map<String, ({String first, String last})> _initialsById = {};
  final Map<String, double?> _ratesById = {};
  final Map<String, String?> _familyNameById = {};

  /// Member id → its position in likelihood ranking (lower is higher priority).
  final Map<String, int> likelihoodPriority = {};

  late final List<Member> _likelyHereMembers;
  late final List<SearchEntry> _searchEntries;
  late final Map<String, Set<String>> _fullInitialsIndex;

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

  /// The uppercase first-name and surname initials of [displayName].
  ///
  /// For single-token names, repeats the single initial for both. Blank input yields
  /// empty initials.
  static ({String first, String last}) extractInitials(String displayName) {
    final parts = tokenizeName(displayName);
    if (parts.isEmpty) return (first: '', last: '');
    return (
      first: parts.first[0].toUpperCase(),
      last: parts.last[0].toUpperCase(),
    );
  }

  /// How well [haystack] matches [query] — **lower is better**:
  ///
  /// * `0` — [haystack] starts with the query
  /// * `1` — a later word in [haystack] starts with the query (after space, hyphen, or apostrophe)
  /// * `2` — the query appears somewhere else inside [haystack]
  ///
  /// `null` when the query does not appear at all, and for a blank query.
  static int? calculateMatchRank(String haystack, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final h = haystack.toLowerCase();
    return calculateMatchRankLowercased(h, q);
  }

  /// Internal helper for match ranking that expects both [haystackLower] and
  /// [cleanQueryLower] to be pre-lowercased and [cleanQueryLower] to be pre-trimmed,
  /// avoiding redundant string lowercasing and trimming in search loops.
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

  /// How well [entry] matches [query] — lower is better, `null` for no match.
  /// A family-name match always ranks worse (+3) than any display-name match.
  static int? calculateSearchRank(SearchEntry entry, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return null;
    return calculateSearchRankLowercased(entry, cleanQuery);
  }

  /// Internal helper using pre-lowercased query string and cached member
  /// lowercased display name to eliminate repeated lowercasing per entry.
  static int? calculateSearchRankLowercased(
    SearchEntry entry,
    String cleanQueryLower,
  ) {
    final byName = calculateMatchRankLowercased(
      entry.member.displayNameLowercase,
      cleanQueryLower,
    );
    if (byName != null) return byName;
    final familyName = entry.familyName;
    if (familyName == null) return null;
    final byFamily = calculateMatchRankLowercased(
      familyName.toLowerCase(),
      cleanQueryLower,
    );
    return byFamily == null ? null : byFamily + 3;
  }

  /// The [entries] matching [query], best match first.
  static List<SearchEntry> executeRankedSearch(
    Iterable<SearchEntry> entries,
    String query, {
    Map<String, int> priority = const {},
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    final scored = <({SearchEntry entry, int rank})>[];
    for (final entry in entries) {
      final rank = calculateSearchRankLowercased(entry, cleanQuery);
      if (rank == null) continue;
      scored.add((entry: entry, rank: rank));
    }

    scored.sort((a, b) {
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      final pa = priority[a.entry.member.id];
      final pb = priority[b.entry.member.id];
      if (pa != pb) {
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      }
      return a.entry.member.displayNameLowercase.compareTo(
        b.entry.member.displayNameLowercase,
      );
    });

    return [for (final s in scored) s.entry];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Query Interface
  // ─────────────────────────────────────────────────────────────────────────

  /// Roster members ordered by likelihood (most likely to attend first).
  List<Member> likelyHere() => _likelyHereMembers;

  /// The search entries available in this index.
  List<SearchEntry> get searchEntries => _searchEntries;

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

  /// The first-name and surname initials for [member].
  ({String first, String last}) initialsFor(Member member) =>
      _initialsById[member.id] ?? extractInitials(member.displayName);

  /// Recent attendance rate for [member], or null if insufficient history.
  double? rateFor(Member member) => _ratesById[member.id];

  /// Household display name for [member], or null if none or auto-singleton.
  String? familyNameFor(Member member) => _familyNameById[member.id];

  /// One-line subtitle for [member] (household or Attendee Surname fallback,
  /// plus recent attendance percentage).
  String subtitleFor(Member member) {
    final fam = familyNameFor(member);
    final last = surnameFor(member);
    final fallback = (last.trim().isNotEmpty) ? last.trim() : 'Loner';
    final household = (fam == null || fam.trim().isEmpty) ? fallback : fam;
    final rate = rateFor(member);
    if (rate == null) return household;
    return '$household · ${(rate * 100).round()}% recently';
  }

  /// First-name initial → surname initials available under it.
  ///
  /// When [subset] is provided (e.g. unmarked members), computes the map for that
  /// subset using precomputed initials. When omitted, returns the precomputed index
  /// for the whole active roster.
  Map<String, Set<String>> initialsIndex([Iterable<Member>? subset]) {
    if (subset == null) return _fullInitialsIndex;
    final index = <String, Set<String>>{};
    for (final m in subset) {
      final initials = initialsFor(m);
      if (initials.first.isEmpty) continue;
      index.putIfAbsent(initials.first, () => <String>{}).add(initials.last);
    }
    return index;
  }

  /// Returns members matching the first-name [first] initial and optional surname [last] initial.
  List<Member> membersWithInitials(
    String first, {
    String? last,
    Iterable<Member>? within,
  }) {
    final candidates = within ?? _likelyHereMembers;
    final out = <Member>[];
    for (final m in candidates) {
      final initials = initialsFor(m);
      if (initials.first != first) continue;
      if (last != null && initials.last != last) continue;
      out.add(m);
    }
    return out;
  }

  /// Ranks and returns matching [SearchEntry] records for [query], capped at [limit].
  List<SearchEntry> search(
    String query, {
    int? limit,
    Map<String, int>? priority,
  }) {
    final results = executeRankedSearch(
      _searchEntries,
      query,
      priority: priority ?? likelihoodPriority,
    );
    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// How well [entry] matches [query].
  int? searchRank(SearchEntry entry, String query) =>
      calculateSearchRank(entry, query);

  /// How well [haystack] matches [query].
  int? matchRank(String haystack, String query) =>
      calculateMatchRank(haystack, query);

  /// Whether [haystack] matches [query] (case-insensitive substring/prefix).
  bool matches(String haystack, String query) {
    if (query.trim().isEmpty) return true;
    return calculateMatchRank(haystack, query) != null;
  }

  /// Whether the top hit in [results] matches [query] strictly better than the runner-up.
  bool isUnambiguous(String query, List<SearchEntry> results) {
    if (results.length == 1) return true;
    if (results.length < 2) return false;
    final first = searchRank(results[0], query);
    final second = searchRank(results[1], query);
    if (first == null || second == null) return false;
    return first < second;
  }

  /// Households whose name or members match [query], ordered by best match rank.
  /// If [query] is null or empty, returns all non-empty families in the roster.
  List<Family> groupedByFamily({String? query, int? limit}) {
    if (query == null) {
      final list = _families.where((f) => f.members.isNotEmpty).toList();
      return limit != null && list.length > limit
          ? list.sublist(0, limit)
          : list;
    }
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      final list = _families.where((f) => f.members.isNotEmpty).toList();
      return limit != null && list.length > limit
          ? list.sublist(0, limit)
          : list;
    }

    final scored = <({Family family, int rank})>[];
    for (final family in _families) {
      if (family.members.isEmpty) continue;
      int? best = calculateMatchRankLowercased(
        family.displayNameLowercase,
        cleanQuery,
      );
      for (final m in family.members) {
        final r = calculateMatchRankLowercased(
          m.displayNameLowercase,
          cleanQuery,
        );
        if (r != null && (best == null || r < best)) best = r;
      }
      if (best != null) {
        scored.add((family: family, rank: best));
      }
    }

    scored.sort((a, b) {
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      return a.family.displayNameLowercase.compareTo(
        b.family.displayNameLowercase,
      );
    });

    final ordered = [for (final s in scored) s.family];
    return limit != null && ordered.length > limit
        ? ordered.sublist(0, limit)
        : ordered;
  }
}
