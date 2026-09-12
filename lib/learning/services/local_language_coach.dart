import '../models/learning_models.dart';
import '../models/learner_profile.dart';
import 'on_device_translation_service.dart';

class LocalLanguageCoach {
  const LocalLanguageCoach._();

  static Future<String> explain({
    required LearningSegment segment,
    required LearnerProfile profile,
    required String sourceLanguage,
  }) async {
    final source = sourceLanguage.trim().toLowerCase().split(RegExp('[-_]')).first;
    final native = profile.nativeLanguage.trim().toLowerCase().split(RegExp('[-_]')).first;
    var meaning = segment.translation?.trim() ?? '';
    if (meaning.isEmpty &&
        source.isNotEmpty &&
        native.isNotEmpty &&
        source != native &&
        OnDeviceTranslationService.canTranslate(source, native)) {
      try {
        meaning = await OnDeviceTranslationService.translateText(
          segment.original,
          sourceLanguage: source,
          targetLanguage: native,
        );
      } catch (_) {}
    }

    final hints = _grammarHints(segment.original, source);
    final focusWords = _focusWords(segment.original).take(4).toList(growable: false);
    final arabic = native == 'ar';
    final buffer = StringBuffer();
    if (arabic) {
      buffer.writeln('المعنى في السياق:');
      buffer.writeln(meaning.isEmpty ? 'اعتمد على السياق واسمع الجملة مرة أخرى.' : meaning);
      if (focusWords.isNotEmpty) {
        buffer..writeln()..writeln('ركّز في السماع على: ${focusWords.join(' · ')}');
      }
      if (hints.isNotEmpty) {
        buffer..writeln()..writeln('ملاحظة لغوية: ${hints.join(' ')}');
      }
      buffer
        ..writeln()
        ..writeln('تدريب سريع: اسمع الجملة مرة بدون ترجمة، ثم كررها بصوتك، وبعدها اكشف النص.');
    } else {
      buffer.writeln('Meaning in context:');
      buffer.writeln(meaning.isEmpty ? 'Use the scene context and replay the line once.' : meaning);
      if (focusWords.isNotEmpty) {
        buffer..writeln()..writeln('Listening focus: ${focusWords.join(' · ')}');
      }
      if (hints.isNotEmpty) {
        buffer..writeln()..writeln('Language note: ${hints.join(' ')}');
      }
      buffer
        ..writeln()
        ..writeln('Quick drill: listen once without help, repeat the line aloud, then reveal the text.');
    }
    return buffer.toString().trim();
  }

  static List<String> _grammarHints(String text, String language) {
    final lower = text.toLowerCase();
    final hints = <String>[];
    if (language == 'en') {
      if (RegExp(r"\b(have|has|had)\s+been\s+\w+ing\b").hasMatch(lower)) {
        hints.add('The “have/has been + -ing” pattern connects an ongoing/recent activity with the present.');
      }
      if (RegExp(r"\b(i'm|you're|he's|she's|we're|they're|don't|didn't|can't|won't|i've|you've)\b").hasMatch(lower)) {
        hints.add('Notice the contraction: natural speech compresses these words, so listen for the linked sound rather than every written letter.');
      }
    } else if (language == 'de') {
      if (RegExp(r'\b(weil|dass|obwohl|wenn)\b').hasMatch(lower)) {
        hints.add('After weil/dass/obwohl/wenn, German commonly places the conjugated verb near the end of the clause.');
      }
    } else if (language == 'fr') {
      if (RegExp(r"\b(j'|l'|d'|qu'|c')").hasMatch(lower)) {
        hints.add('French elision joins short words to the next word; listen to them as one sound group.');
      }
    }
    return hints;
  }

  static Iterable<String> _focusWords(String text) sync* {
    final words = text
        .replaceAll(RegExp(r"[^\p{L}\p{N}’'\-]+", unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((e) => e.length >= 5)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in words) {
      yield word;
    }
  }
}
