import 'dart:convert';
import 'dart:io';

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

  test('runtime model name is persistent and cannot be blank', () async {
    await AiLanguageService.setModel('llama3.2');
    expect(AiLanguageService.model, 'llama3.2');
    await AiLanguageService.loadConfiguration();
    expect(AiLanguageService.model, 'llama3.2');
    await expectLater(
      AiLanguageService.setModel('   '),
      throwsA(isA<AiLanguageException>()),
    );
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

  test('AI Tutor makes a real HTTP request with the configured model', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    Map<String, dynamic>? captured;
    server.listen((request) async {
      captured = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object>{
          'choices': <Object>[
            <String, Object>{
              'message': <String, String>{'content': 'READY'},
            },
          ],
        }),
      );
      await request.response.close();
    });
    try {
      await AiLanguageService.setModel('local-test-model');
      await AiLanguageService.setEndpoint(
        'http://${server.address.address}:${server.port}/v1/chat/completions',
      );
      expect(await AiLanguageService.testConnection(), 'READY');
      expect(captured?['model'], 'local-test-model');
      final messages = captured?['messages'] as List<dynamic>?;
      expect(messages, hasLength(2));
      expect((messages!.last as Map<String, dynamic>)['content'], 'Reply READY.');
    } finally {
      await server.close(force: true);
    }
  });

  test('AI provider non-success status produces a visible error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"error":{"message":"gateway unavailable"}}');
      await request.response.close();
    });
    try {
      await AiLanguageService.setEndpoint(
        'http://${server.address.address}:${server.port}/v1/chat/completions',
      );
      await expectLater(
        AiLanguageService.testConnection(),
        throwsA(isA<AiLanguageException>().having(
          (e) => e.message,
          'message',
          contains('gateway unavailable'),
        )),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('connection test fails clearly if no endpoint is configured', () async {
    await expectLater(
      AiLanguageService.testConnection(),
      throwsA(isA<AiLanguageException>()),
    );
  });
}
