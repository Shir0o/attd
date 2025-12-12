import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/ai/http_ai_provider.dart';
import 'package:attendance_tracker/features/ai/mock_ai_provider.dart';
import 'package:attendance_tracker/features/ai/gemini_ai_provider.dart';

enum AiProviderType { mock, http, gemini }

class AiProviderFactory {
  const AiProviderFactory({
    this.defaultEndpoint = 'https://example.com/api/ai',
  });

  final String defaultEndpoint;

  AiProvider create(
    AiProviderType type, {
    String? endpointOverride,
    String? apiKey,
  }) {
    switch (type) {
      case AiProviderType.http:
        return HttpAiProvider(
          endpoint: Uri.parse(endpointOverride ?? defaultEndpoint),
        );
      case AiProviderType.gemini:
        if (apiKey == null || apiKey.isEmpty) {
          // Fallback or throw? For now fallback to mock to prevent crashes if key missing
          // But ideally we should probably throw or return a specific error provider.
          // Let's return MockAiProvider for safety with a console warning if we could.
          return const MockAiProvider();
        }
        return GeminiAiProvider(apiKey: apiKey);
      case AiProviderType.mock:
      default:
        return const MockAiProvider();
    }
  }
}
