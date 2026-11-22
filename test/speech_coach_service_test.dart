import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/speech_coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('elnemr/speech_coach');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps a language and returns actual recognized text', () async {
    String? locale;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listen');
      locale = (call.arguments as Map<Object?, Object?>)['locale'] as String?;
      return '  Hello, how are you?  ';
    });

    final text = await SpeechCoachService.instance.listen(
      languageCode: 'en-GB',
      timeout: const Duration(milliseconds: 100),
    );
    expect(text, 'Hello, how are you?');
    expect(locale, 'en-US');
  });

  test('times out stalled native recognizer and requests stop', () async {
    var stopCalls = 0;
    final neverCompletes = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      if (call.method == 'listen') return neverCompletes.future;
      if (call.method == 'stop') {
        stopCalls++;
        return Future<void>.value();
      }
      throw PlatformException(code: 'unexpected', message: call.method);
    });

    await expectLater(
      SpeechCoachService.instance.listen(
        timeout: const Duration(milliseconds: 15),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(stopCalls, 1);
  });
}
