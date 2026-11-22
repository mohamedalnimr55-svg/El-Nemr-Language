import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/services/ai_language_service.dart';
import 'package:el_nemr_language/learning/services/lesson_explanation_service.dart';

void main() {
  const segment = LearningSegment(
    id: 'lesson-1',
    start: Duration(seconds: 1),
    end: Duration(seconds: 4),
    original: 'Bonjour, comment allez-vous?',
    translation: 'Hello, how are you?',
  );
  const profile = LearnerProfile(nativeLanguage: 'en', targetLanguage: 'fr');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AiLanguageService.loadConfiguration();
  });

  test('without an AI endpoint, Local Coach still explains the scene', () async {
    final result = await LessonExplanationService.explain(
      segment: segment,
      profile: profile,
      sourceLanguage: 'fr',
    );
    expect(result.usedLocalCoach, isTrue);
    expect(result.warning, isNull);
    expect(result.text, contains('Hello, how are you?'));
  });

  test('on HTTP 503, the learner gets Local Coach and an explicit warning', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      await utf8.decoder.bind(request).join();
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"error":{"message":"model offline"}}');
      await request.response.close();
    });
    try {
      await AiLanguageService.setEndpoint(
        'http://${server.address.address}:${server.port}/v1/chat/completions',
      );
      final result = await LessonExplanationService.explain(
        segment: segment,
        profile: profile,
        sourceLanguage: 'fr',
      );
      expect(requests, 1);
      expect(result.usedLocalCoach, isTrue);
      expect(result.warning, contains('model offline'));
      expect(result.text, contains('Hello, how are you?'));
    } finally {
      await server.close(force: true);
    }
  });

  test('successful AI gateway is used instead of fallback', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object>{
        'choices': <Object>[
          <String, Object>{
            'message': <String, String>{'content': 'AI: bonjour is a greeting.'},
          },
        ],
      }));
      await request.response.close();
    });
    try {
      await AiLanguageService.setEndpoint(
        'http://${server.address.address}:${server.port}/v1/chat/completions',
      );
      final result = await LessonExplanationService.explain(
        segment: segment,
        profile: profile,
        sourceLanguage: 'fr',
      );
      expect(result.usedLocalCoach, isFalse);
      expect(result.warning, isNull);
      expect(result.text, 'AI: bonjour is a greeting.');
    } finally {
      await server.close(force: true);
    }
  });
}
