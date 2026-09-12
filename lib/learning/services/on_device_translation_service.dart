import 'dart:io';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../models/subtitle_cue.dart';

class OnDeviceTranslationException implements Exception {
  const OnDeviceTranslationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Free on-device subtitle translation backed by Google ML Kit.
///
/// Language models are downloaded once by the native SDK and then reused.
/// No API key is needed and subtitle text is translated on the device.
class OnDeviceTranslationService {
  const OnDeviceTranslationService._();

  static bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  static TranslateLanguage? languageFor(String code) {
    final normalized = code.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) return null;
    final base = normalized.split('-').first;
    for (final language in TranslateLanguage.values) {
      final bcp = language.bcpCode.toLowerCase();
      if (bcp == normalized || bcp.split('-').first == base) return language;
    }
    return null;
  }

  static bool canTranslate(String sourceLanguage, String targetLanguage) {
    if (!isAvailable) return false;
    final source = languageFor(sourceLanguage);
    final target = languageFor(targetLanguage);
    return source != null && target != null && source != target;
  }

  static Future<void> ensureModels({
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = false,
  }) async {
    final source = languageFor(sourceLanguage);
    final target = languageFor(targetLanguage);
    if (source == null || target == null) {
      throw const OnDeviceTranslationException('This language pair is not supported by the on-device translator.');
    }
    final manager = OnDeviceTranslatorModelManager();
    for (final language in <TranslateLanguage>{source, target}) {
      final code = language.bcpCode;
      final ready = await manager.isModelDownloaded(code);
      if (!ready) {
        final downloaded = await manager.downloadModel(code, isWifiRequired: wifiOnly);
        if (!downloaded) {
          throw OnDeviceTranslationException('Could not download the $code translation model.');
        }
      }
    }
  }

  static Future<String> translateText(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = false,
  }) async {
    final source = languageFor(sourceLanguage);
    final target = languageFor(targetLanguage);
    if (source == null || target == null || source == target) {
      throw const OnDeviceTranslationException('Unsupported or identical source/target language.');
    }
    await ensureModels(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      wifiOnly: wifiOnly,
    );
    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    try {
      return (await translator.translateText(text)).trim();
    } catch (e) {
      throw OnDeviceTranslationException('On-device translation failed: $e');
    } finally {
      await translator.close();
    }
  }

  static Future<List<SubtitleCue>> translateCues(
    List<SubtitleCue> cues, {
    required String sourceLanguage,
    required String targetLanguage,
    bool wifiOnly = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (cues.isEmpty) return const <SubtitleCue>[];
    final source = languageFor(sourceLanguage);
    final target = languageFor(targetLanguage);
    if (source == null || target == null || source == target) {
      throw const OnDeviceTranslationException('Unsupported or identical source/target language.');
    }

    await ensureModels(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      wifiOnly: wifiOnly,
    );

    final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
    final cache = <String, String>{};
    final translated = <SubtitleCue>[];
    try {
      for (var i = 0; i < cues.length; i++) {
        final cue = cues[i];
        final input = cue.text.trim();
        if (input.isEmpty) {
          translated.add(cue);
        } else {
          final value = cache[input] ?? await translator.translateText(input);
          cache[input] = value;
          translated.add(SubtitleCue(start: cue.start, end: cue.end, text: value.trim()));
        }
        onProgress?.call(i + 1, cues.length);
      }
      return translated;
    } catch (e) {
      throw OnDeviceTranslationException('On-device translation failed: $e');
    } finally {
      await translator.close();
    }
  }
}
