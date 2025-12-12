class LabelAssignments {
  const LabelAssignments({
    this.autoLabels = const <String>{},
    this.manualLabels = const <String>{},
  });

  final Set<String> autoLabels;
  final Set<String> manualLabels;

  Set<String> get all => {...autoLabels, ...manualLabels};

  bool hasLabel(String label) => all.contains(label);

  bool isManual(String label) => manualLabels.contains(label);

  factory LabelAssignments.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LabelAssignments();

    Set<String> _parseLabels(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toSet();
      }
      return const <String>{};
    }

    return LabelAssignments(
      autoLabels: _parseLabels(json['autoLabels'] ?? json['labels']),
      manualLabels: _parseLabels(json['manualLabels']),
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
