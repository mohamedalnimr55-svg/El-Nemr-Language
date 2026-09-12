import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechCoachService {
  SpeechCoachService._();
  static final SpeechCoachService instance = SpeechCoachService._();
  static const MethodChannel _channel = MethodChannel('elnemr/speech_coach');

  Future<String?> listen({String languageCode = 'en'}) async {
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
    final value = await _channel.invokeMethod<String>('listen', <String, Object?>{
      'locale': locale,
    });
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Best effort; the platform may already have completed the request.
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
