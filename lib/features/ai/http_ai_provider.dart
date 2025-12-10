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
      }),
    );

    if (response.statusCode >= 400) {
      throw HttpException('Failed to fetch suggestion: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FollowUpSuggestion(
      subject: payload['subject'] ?? request.flag.subject,
      message: payload['message'] ?? 'Unable to generate message.',
      reasoning: payload['reasoning'] ?? 'Remote response',
      tone: payload['tone'] ?? 'neutral',
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
          (item) => AbsencePrediction(
            subject: item['subject'] as String,
            reason: item['reason'] as String? ?? 'No rationale provided',
            probability: (item['probability'] as num).toDouble(),
            isFamily: item['isFamily'] as bool? ?? false,
          ),
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
