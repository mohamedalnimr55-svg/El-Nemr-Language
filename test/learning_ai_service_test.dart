import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/ai_language_service.dart';

void main() {
  test('AI provider is opt-in at build time', () {
    // Default test builds intentionally have no endpoint, preventing accidental
    // network traffic or transmission of learner/video content.
    expect(AiLanguageService.isConfigured, isFalse);
  });
}
