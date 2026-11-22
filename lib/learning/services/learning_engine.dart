import 'dart:math';
import '../models/learning_models.dart';
import 'learning_text_tokenizer.dart';

class AnswerScore {
  const AnswerScore({
    required this.score,
    required this.missingWords,
    required this.extraWords,
  });

  final double score;
  final List<String> missingWords;
  final List<String> extraWords;

  bool get perfect => score >= 0.999;
}

class LearningEngine {
  LearningEngine({Random? random}) : _random = random ?? Random();
  final Random _random;

  // Timelines are sorted by start time, but subtitles may overlap (for
  // example two speakers or a long caption with a shorter interjection).
  // Binary-searching by BOTH start and end incorrectly discarded an earlier
  // active cue whenever a later, shorter cue had already ended.
  LearningSegment? segmentAt(List<LearningSegment> segments, Duration position) {
    var lo = 0;
    var hi = segments.length;
    // Find the first cue which starts strictly after the current position.
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (segments[mid].start <= position) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // Prefer the most recently started active cue. Earlier, longer captions
    // are still eligible if the newer one has already ended.
    for (var i = lo - 1; i >= 0; i--) {
      if (position < segments[i].end) return segments[i];
    }
    return null;
  }

  /// Dictation and target-language exercises expect spoken source dialogue.
  /// Translation-to-native exercises expect the learner's own language.
  static String answerLanguageForQuestion(
    QuizQuestion question, {
    required String nativeLanguage,
    required String targetLanguage,
  }) => question.kind == QuizKind.translateToNative
      ? nativeLanguage
      : targetLanguage;

  QuizQuestion questionFor(LearningSegment segment, {required LearningMode mode, String nativeLanguage = 'en'}) {
    // Speaker annotations belong in dialogue metadata/UI, not in the words
    // a learner must dictate, translate, or pronounce.
    final spoken = parseDialogueLine(segment.original).text;
    final translated = segment.translation == null
        ? null
        : parseDialogueLine(segment.translation!).text.trim();
    final ar = nativeLanguage.toLowerCase().startsWith('ar');
    if (mode == LearningMode.listening) {
      return QuizQuestion(kind: QuizKind.dictation, prompt: ar ? 'اكتب ما سمعته في المقطع' : 'Type exactly what you heard', answer: spoken, segment: segment);
    }
    if (translated != null && translated.isNotEmpty) {
      if (_random.nextBool()) {
        return QuizQuestion(kind: QuizKind.translateToNative, prompt: ar ? 'ترجم الجملة إلى لغتك' : 'Translate the line into your language', answer: translated, segment: segment);
      }
      return QuizQuestion(kind: QuizKind.translateToTarget, prompt: ar ? 'اكتب الجملة باللغة التي تتعلمها' : 'Write the line in the language you are learning', answer: spoken, segment: segment);
    }
    final words = spoken.split(RegExp(r'\s+')).where((e) => e.length > 2).toList();
    if (words.isNotEmpty) {
      final word = words[_random.nextInt(words.length)];
      return QuizQuestion(kind: QuizKind.fillBlank, prompt: spoken.replaceFirst(word, '_____'), answer: word, segment: segment);
    }
    return QuizQuestion(kind: QuizKind.dictation, prompt: ar ? 'اكتب ما سمعته' : 'Type what you heard', answer: spoken, segment: segment);
  }

  double scoreAnswer(String answer, String expected) => scoreDetailed(answer, expected).score;

  AnswerScore scoreDetailed(String answer, String expected) {
    final actual = tokenizeLearningText(answer);
    final target = tokenizeLearningText(expected);
    if (target.isEmpty) {
      return AnswerScore(
        score: actual.isEmpty ? 1.0 : 0.0,
        missingWords: const <String>[],
        extraWords: List<String>.unmodifiable(actual),
      );
    }

    final rows = actual.length + 1;
    final cols = target.length + 1;
    final d = List<List<int>>.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = 0; i < rows; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final substitution = d[i - 1][j - 1] + (actual[i - 1] == target[j - 1] ? 0 : 1);
        d[i][j] = min(min(d[i - 1][j] + 1, d[i][j - 1] + 1), substitution);
      }
    }

    final missing = <String>[];
    final extra = <String>[];
    var i = actual.length;
    var j = target.length;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && actual[i - 1] == target[j - 1] && d[i][j] == d[i - 1][j - 1]) {
        i--; j--;
        continue;
      }
      if (j > 0 && d[i][j] == d[i][j - 1] + 1) {
        missing.add(target[j - 1]);
        j--;
        continue;
      }
      if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
        extra.add(actual[i - 1]);
        i--;
        continue;
      }
      if (i > 0 && j > 0) {
        // A substitution is most useful to a learner when shown as both a
        // missing expected word and an extra recognized/typed word.
        missing.add(target[j - 1]);
        extra.add(actual[i - 1]);
        i--; j--;
      } else if (j > 0) {
        missing.add(target[--j]);
      } else if (i > 0) {
        extra.add(actual[--i]);
      }
    }
    final orderedMissing = missing.reversed.toList(growable: false);
    final orderedExtra = extra.reversed.toList(growable: false);
    final distance = d[actual.length][target.length];
    final denominator = max(actual.length, target.length);
    return AnswerScore(
      score: (1 - distance / denominator).clamp(0.0, 1.0).toDouble(),
      missingWords: List<String>.unmodifiable(orderedMissing),
      extraWords: List<String>.unmodifiable(orderedExtra),
    );
  }

}
