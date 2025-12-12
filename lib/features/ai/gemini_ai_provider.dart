import 'dart:convert';

import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAiProvider implements AiProvider {
  GeminiAiProvider({
    required String apiKey,
    String modelName = 'gemini-1.5-flash',
  }) : _model = GenerativeModel(
         model: modelName,
         apiKey: apiKey,
         generationConfig: GenerationConfig(responseMimeType: 'application/json'),
       );

  final GenerativeModel _model;

  @override
  Future<FollowUpSuggestion> suggestFollowUp(FollowUpRequest request) async {
    final prompt = _buildFollowUpPrompt(request);
    final response = await _model.generateContent([Content.text(prompt)]);

    final text = response.text;
    if (text == null) {
      throw Exception('Failed to generate suggestion: Empty response');
    }

    try {
      final payload = jsonDecode(text) as Map<String, dynamic>;
      final nameSuggestion = _parseNameSuggestion(
        payload,
        fallbackSubject: request.flag.subject,
      );
      final subjectLabel = _parseSubjectLabel(payload);
      return FollowUpSuggestion(
        subject: payload['subject'] ?? request.flag.subject,
        message: payload['message'] ?? 'Unable to generate message.',
        reasoning: payload['reasoning'] ?? 'AI generated',
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
        labelRationale:
            payload['labelRationale'] as String? ??
            payload['labelReason'] as String? ??
            subjectLabel?.rationale,
      );
    } catch (e) {
      throw Exception('Failed to parse suggestion: $e');
    }
  }

  @override
  Future<List<AbsencePrediction>> predictAbsences(
    AbsencePredictionRequest request,
  ) async {
    final prompt = _buildPredictionPrompt(request);
    final response = await _model.generateContent([Content.text(prompt)]);

    final text = response.text;
    if (text == null) {
      throw Exception('Failed to generate predictions: Empty response');
    }

    try {
      final payload = jsonDecode(text) as Map<String, dynamic>;
      final items =
          (payload['predictions'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      return items
          .map((item) {
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
              labelRationale:
                  item['labelRationale'] as String? ??
                  item['labelReason'] as String? ??
                  subjectLabel?.rationale,
            );
          })
          .where(
            (prediction) => prediction.probability >= request.minConfidence,
          )
          .toList()
        ..sort((a, b) => b.probability.compareTo(a.probability));
    } catch (e) {
      throw Exception('Failed to parse predictions: $e');
    }
  }

  String _buildFollowUpPrompt(FollowUpRequest request) {
    return jsonEncode({
      'task': 'generate_follow_up',
      'subject': request.flag.subject,
      'reason': request.flag.reason,
      'isFamily': request.flag.isFamily,
      'range': request.rangeLabel,
      if (request.nameMetadata.isNotEmpty)
        'nameMetadata': request.nameMetadata.map(
          (name, metadata) => MapEntry(name, metadata.toJson()),
        ),
      if (request.attendanceFeatures.isNotEmpty)
        'attendanceFeatures': request.attendanceFeatures.map(
          (name, features) => MapEntry(name, features.toJson()),
        ),
      'instructions':
          'Generate a personalized follow-up message. Return JSON with keys: subject, message, reasoning, tone. '
          '1. Analyze "nameMetadata": identifying potential typos or duplicates (e.g. "Jon" vs "John"). If the subject name seems to be a typo of a more frequent name, return "correctedName" and "duplicateCandidates". '
          '2. Analyze "attendanceFeatures": assign a "label" (e.g. "Committed", "At-Risk", "New", "Regular") based on attendance consistency, streaks, and total sessions. Provide a short "labelRationale". '
          '3. "message" should be warm and encourage connection.',
    });
  }

  String _buildPredictionPrompt(AbsencePredictionRequest request) {
    return jsonEncode({
      'task': 'predict_absences',
      'range': request.analytics.range.label,
      'watchlist':
          request.analytics.watchlist
              .map(
                (flag) => {
                  'subject': flag.subject,
                  'reason': flag.reason,
                  'isFamily': flag.isFamily,
                },
              )
              .toList(),
      if (request.nameMetadata.isNotEmpty)
        'nameMetadata': request.nameMetadata.map(
          (name, metadata) => MapEntry(name, metadata.toJson()),
        ),
      if (request.attendanceFeatures.isNotEmpty)
        'attendanceFeatures': request.attendanceFeatures.map(
          (name, features) => MapEntry(name, features.toJson()),
        ),
      'instructions':
          'Analyze attendance patterns and predict likely upcoming absences. Return JSON with key "predictions", a list of objects. '
          'For each prediction: '
          '1. Analyze "nameMetadata" for the subject. If it appears to be a typo/duplicate of another name, returning "correctedName" and "duplicateCandidates". '
          '2. Analyze "attendanceFeatures" to assign a context "label" (e.g. "Sporadic", "Inactive", "Churn Risk") and "labelRationale". '
          '3. Estimate "probability" (0-1) of absence and provide a "reason".',
    });
  }

  // Helper parsing methods reused from HttpAiProvider logic
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
        payload['labelRationale'] as String? ??
        payload['labelReason'] as String?;
    return SubjectLabel(label: label, rationale: rationale);
  }

  List<String> _parseDuplicateClusters(Map<String, dynamic> payload) {
    return (payload['duplicateClusterIds'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const [];
  }
}
