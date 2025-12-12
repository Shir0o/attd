import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider.dart';

class HttpAiProvider implements AiProvider {
  HttpAiProvider({required this.endpoint, http.Client? client})
    : client = client ?? http.Client();

  final Uri endpoint;
  final http.Client client;

  @override
  Future<FollowUpSuggestion> suggestFollowUp(FollowUpRequest request) async {
    final response = await client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'follow_up',
        'subject': request.flag.subject,
        'reason': request.flag.reason,
        'isFamily': request.flag.isFamily,
        'range': request.rangeLabel,
        // Expected Firebase Function schema: optional metadata fields provide
        // high-quality name resolution and labeling context. The function can
        // safely ignore them if the deployed version does not support them.
        // {
        //   "nameMetadata": {"Alex": {"original": "Alex", "normalized": "alex", "recentEdits": [], "usageCount": 3}},
        //   "attendanceFeatures": {"Alex": {"totalSessions": 5, "absentCount": 2, "presentCount": 3, "absenceStreak": 2, "lastRecorded": "2025-01-14T00:00:00.000"}}
        // }
        if (request.nameMetadata.isNotEmpty)
          'nameMetadata': request.nameMetadata.map(
            (name, metadata) => MapEntry(name, metadata.toJson()),
          ),
        if (request.attendanceFeatures.isNotEmpty)
          'attendanceFeatures': request.attendanceFeatures.map(
            (name, features) => MapEntry(name, features.toJson()),
          ),
      }),
    );

    if (response.statusCode >= 400) {
      throw HttpException('Failed to fetch suggestion: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final nameSuggestion = _parseNameSuggestion(
      payload,
      fallbackSubject: request.flag.subject,
    );
    final subjectLabel = _parseSubjectLabel(payload);
    return FollowUpSuggestion(
      subject: payload['subject'] ?? request.flag.subject,
      message: payload['message'] ?? 'Unable to generate message.',
      reasoning: payload['reasoning'] ?? 'Remote response',
      tone: payload['tone'] ?? 'neutral',
      correctedName: payload['correctedName'] as String?,
      duplicateCandidates:
          (payload['duplicateCandidates'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      duplicateClusterIds: _parseDuplicateClusters(payload),
      nameSuggestion: nameSuggestion,
      subjectLabel: subjectLabel,
      label: payload['label'] as String? ?? subjectLabel?.label,
      labelRationale: payload['labelRationale'] as String? ??
          payload['labelReason'] as String? ??
          subjectLabel?.rationale,
    );
  }

  @override
  Future<List<AbsencePrediction>> predictAbsences(
    AbsencePredictionRequest request,
  ) async {
    final response = await client.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'prediction',
        'range': request.analytics.range.label,
        'watchlist': request.analytics.watchlist
            .map(
              (flag) => {
                'subject': flag.subject,
                'reason': flag.reason,
                'isFamily': flag.isFamily,
              },
            )
            .toList(),
        // Optional schema for the Firebase Function to support richer
        // labeling and de-duplication. Backwards-compatible: absent keys are
        // tolerated by older deployments.
        // {
        //   "nameMetadata": {...},
        //   "attendanceFeatures": {...}
        // }
        if (request.nameMetadata.isNotEmpty)
          'nameMetadata': request.nameMetadata.map(
            (name, metadata) => MapEntry(name, metadata.toJson()),
          ),
        if (request.attendanceFeatures.isNotEmpty)
          'attendanceFeatures': request.attendanceFeatures.map(
            (name, features) => MapEntry(name, features.toJson()),
          ),
      }),
    );

    if (response.statusCode >= 400) {
      throw HttpException(
        'Failed to fetch predictions: ${response.statusCode}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (payload['predictions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return items
        .map(
          (item) {
            final nameSuggestion = _parseNameSuggestion(
              item,
              fallbackSubject: item['subject'] as String?,
            );
            final subjectLabel = _parseSubjectLabel(item);
            return AbsencePrediction(
              subject: item['subject'] as String,
              reason: item['reason'] as String? ?? 'No rationale provided',
              probability: (item['probability'] as num).toDouble(),
              isFamily: item['isFamily'] as bool? ?? false,
              correctedName: item['correctedName'] as String?,
              duplicateCandidates:
                  (item['duplicateCandidates'] as List<dynamic>?)
                      ?.whereType<String>()
                      .toList() ??
                  const [],
              duplicateClusterIds: _parseDuplicateClusters(item),
              nameSuggestion: nameSuggestion,
              subjectLabel: subjectLabel,
              label: item['label'] as String? ?? subjectLabel?.label,
              labelRationale: item['labelRationale'] as String? ??
                  item['labelReason'] as String? ??
                  subjectLabel?.rationale,
            );
          },
        )
        .where((prediction) => prediction.probability >= request.minConfidence)
        .toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));
  }
}

class HttpException implements Exception {
  HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}

NameSuggestion? _parseNameSuggestion(
  Map<String, dynamic> payload, {
  String? fallbackSubject,
}) {
  final rawSuggestion = payload['nameSuggestion'];
  if (rawSuggestion is Map<String, dynamic>) {
    final suggestedName = rawSuggestion['suggestedName'] as String?;
    if (suggestedName != null && suggestedName.isNotEmpty) {
      return NameSuggestion(
        suggestedName: suggestedName,
        confidence: (rawSuggestion['confidence'] as num?)?.toDouble(),
        duplicateClusterIds: _parseDuplicateClusters(rawSuggestion),
      );
    }
  }

  final correctedName = payload['correctedName'] as String?;
  final correctedConfidence =
      (payload['correctedNameConfidence'] as num?)?.toDouble();
  final duplicateClusters = _parseDuplicateClusters(payload);
  if (correctedName != null || correctedConfidence != null) {
    return NameSuggestion(
      suggestedName: correctedName ?? fallbackSubject ?? 'Unknown',
      confidence: correctedConfidence,
      duplicateClusterIds: duplicateClusters,
    );
  }

  if (duplicateClusters.isNotEmpty && fallbackSubject != null) {
    return NameSuggestion(
      suggestedName: fallbackSubject,
      duplicateClusterIds: duplicateClusters,
    );
  }

  return null;
}

SubjectLabel? _parseSubjectLabel(Map<String, dynamic> payload) {
  final label = payload['label'] as String?;
  if (label == null) return null;
  final rationale =
      payload['labelRationale'] as String? ?? payload['labelReason'] as String?;
  return SubjectLabel(label: label, rationale: rationale);
}

List<String> _parseDuplicateClusters(Map<String, dynamic> payload) {
  return (payload['duplicateClusterIds'] as List<dynamic>?)
          ?.whereType<String>()
          .toList() ??
      const [];
}
