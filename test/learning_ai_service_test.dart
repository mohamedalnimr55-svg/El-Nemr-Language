import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/services/ai_language_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AiLanguageService.loadConfiguration();
  });

  test('AI provider is opt-in at build time', () {
    expect(AiLanguageService.isConfigured, isFalse);
  });

  test('runtime endpoint is saved, reloaded, and can be cleared', () async {
    const url = 'http://127.0.0.1:8000/v1/chat/completions';
    await AiLanguageService.setEndpoint(url);
    expect(AiLanguageService.isConfigured, isTrue);
    expect(AiLanguageService.endpoint, url);

    await AiLanguageService.loadConfiguration();
    expect(AiLanguageService.endpoint, url);

    await AiLanguageService.setEndpoint('');
    expect(AiLanguageService.isConfigured, isFalse);
  });

  test('bad URLs and URL-embedded secrets are rejected', () async {
    for (final url in <String>[
      'not a url',
      'ftp://example.com/v1/chat/completions',
      'http://',
      'https://user:password@example.com/v1/chat/completions',
      'https://example.com/v1/chat/completions#fragment',
    ]) {
      await expectLater(
        AiLanguageService.setEndpoint(url),
        throwsA(isA<AiLanguageException>()),
        reason: url,
      );
    }
    expect(AiLanguageService.isConfigured, isFalse);
  });

  test('connection test fails clearly if no endpoint is configured', () async {
    await expectLater(
      AiLanguageService.testConnection(),
      throwsA(isA<AiLanguageException>()),
    );
  });
}
