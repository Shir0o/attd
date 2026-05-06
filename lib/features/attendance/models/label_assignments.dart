class LabelAssignments {
  LabelAssignments({
    Set<String> autoLabels = const <String>{},
    Set<String> manualLabels = const <String>{},
  })  : autoLabels = Set.unmodifiable(autoLabels),
        manualLabels = Set.unmodifiable(manualLabels),
        all = Set.unmodifiable({...autoLabels, ...manualLabels});

  static final LabelAssignments empty = LabelAssignments();

  final Set<String> autoLabels;
  final Set<String> manualLabels;
  final Set<String> all;

  bool hasLabel(String label) => all.contains(label);

  bool isManual(String label) => manualLabels.contains(label);

  factory LabelAssignments.fromJson(Map<String, dynamic>? json) {
    if (json == null) return LabelAssignments.empty;

    Set<String> parseLabels(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toSet();
      }
      return const <String>{};
    }

    return LabelAssignments(
      autoLabels: parseLabels(json['autoLabels'] ?? json['labels']),
      manualLabels: parseLabels(json['manualLabels']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoLabels': autoLabels.toList(),
      'manualLabels': manualLabels.toList(),
    };
  }
}

const watchlistLabel = 'watchlist';
