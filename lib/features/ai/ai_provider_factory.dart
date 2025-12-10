import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/ai/http_ai_provider.dart';
import 'package:attendance_tracker/features/ai/mock_ai_provider.dart';

enum AiProviderType { mock, http }

class AiProviderFactory {
  const AiProviderFactory({
    this.defaultEndpoint = 'https://example.com/api/ai',
  });

  final String defaultEndpoint;

  AiProvider create(AiProviderType type, {String? endpointOverride}) {
    switch (type) {
      case AiProviderType.http:
        return HttpAiProvider(
          endpoint: Uri.parse(endpointOverride ?? defaultEndpoint),
        );
      case AiProviderType.mock:
      default:
        return const MockAiProvider();
    }
  }
}
