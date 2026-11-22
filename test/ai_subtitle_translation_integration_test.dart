import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/subtitle_cue.dart';
import 'package:el_nemr_language/learning/services/ai_language_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AiLanguageService.loadConfiguration();
  });

  Future<HttpServer> createGateway(
    String Function(List<String> input) respond,
    List<int> batchSizes,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final payload = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      final messages = payload['messages'] as List<dynamic>;
      final prompt = (messages.last as Map<String, dynamic>)['content'] as String;
      const marker = 'Input JSON:\n';
      final start = prompt.lastIndexOf(marker);
      if (start < 0) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final input = (jsonDecode(prompt.substring(start + marker.length))
          as List<dynamic>).cast<String>();
      batchSizes.add(input.length);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'choices': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': respond(input)},
          },
        ],
      }));
      await request.response.close();
    });
    await AiLanguageService.setEndpoint(
      'http://${server.address.address}:${server.port}/v1/chat/completions',
    );
    return server;
  }

  test('translation batches preserve all 36 lines and original timestamps', () async {
    final sizes = <int>[];
    final server = await createGateway(
      (input) => jsonEncode(input.map((item) => 'AR: $item').toList()),
      sizes,
    );
    try {
      final cues = List<SubtitleCue>.generate(
        36,
        (i) => SubtitleCue(
          start: Duration(milliseconds: i * 2300),
          end: Duration(milliseconds: i * 2300 + 1700),
          text: 'Line $i',
        ),
      );
      final translated = await AiLanguageService.translateCues(
        cues, sourceLanguage: 'en', targetLanguage: 'ar',
      );
      expect(sizes, <int>[35, 1]);
      expect(translated, hasLength(36));
      for (var i = 0; i < cues.length; i++) {
        expect(translated[i].text, 'AR: Line $i');
        expect(translated[i].start, cues[i].start);
        expect(translated[i].end, cues[i].end);
      }
    } finally {
      await server.close(force: true);
    }
  });

  test('malformed translation entries fail rather than corrupting subtitles', () async {
    var reply = '["OK", 43]';
    final sizes = <int>[];
    final server = await createGateway((_) => reply, sizes);
    try {
      const cues = <SubtitleCue>[
        SubtitleCue(start: Duration.zero, end: Duration(seconds: 1), text: 'One'),
        SubtitleCue(start: Duration(seconds: 2), end: Duration(seconds: 3), text: 'Two'),
      ];
      for (final invalid in <String>[
        '["OK", 43]',
        '["OK", null]',
        '["OK", "  "]',
        '["Only one"]',
        'not JSON',
      ]) {
        reply = invalid;
        await expectLater(
          AiLanguageService.translateCues(
            cues, sourceLanguage: 'en', targetLanguage: 'ar',
          ),
          throwsA(isA<AiLanguageException>()),
          reason: invalid,
        );
      }
      expect(sizes, everyElement(2));
    } finally {
      await server.close(force: true);
    }
  });
}
