import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechCoachService {
  SpeechCoachService._();
  static final SpeechCoachService instance = SpeechCoachService._();
  static const MethodChannel _channel = MethodChannel('elnemr/speech_coach');

  /// Native recognizers sometimes never send a final callback (for example,
  /// after the speech engine loses its audio service). Never leave the
  /// learner's recording button indefinitely disabled.
  Future<String?> listen({
    String languageCode = 'en',
    Duration timeout = const Duration(seconds: 40),
  }) async {
    // Android permission is requested in Flutter. On iOS the native Speech
    // bridge asks for both Speech Recognition and microphone authorization;
    // this avoids permission_handler build-flag differences with SwiftPM.
    if (Platform.isAndroid) {
      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        throw PlatformException(code: 'microphone_denied', message: 'Microphone permission was denied');
      }
    }
    final locale = _localeFor(languageCode);
    try {
      final value = await _channel.invokeMethod<String>(
        'listen',
        <String, Object?>{'locale': locale},
      ).timeout(timeout);
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } on TimeoutException {
      // Ask native recognition to stop, but do not make UI recovery depend on
      // the same native channel responding to this follow-up method.
      unawaited(stop().timeout(const Duration(seconds: 2), onTimeout: () {}));
      throw TimeoutException(
        'Offline speech recognition took too long. Retry recording or check the device speech model.',
        timeout,
      );
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Best effort; the platform may already have completed the request.
    } on MissingPluginException {
      // Native implementation may not be installed on this platform.
    }
  }

  String _localeFor(String languageCode) {
    final code = languageCode.toLowerCase().split(RegExp('[-_]')).first;
    const locales = <String, String>{
      'ar': 'ar-SA',
      'en': 'en-US',
      'de': 'de-DE',
      'fr': 'fr-FR',
      'es': 'es-ES',
      'it': 'it-IT',
      'pt': 'pt-PT',
      'ru': 'ru-RU',
      'tr': 'tr-TR',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'zh': 'zh-CN',
    };
    return locales[code] ?? code;
  }
}
