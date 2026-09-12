import 'dart:math';
import '../models/learning_models.dart';

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

  LearningSegment? segmentAt(List<LearningSegment> segments, Duration position) {
    var lo = 0;
    var hi = segments.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final s = segments[mid];
      if (position < s.start) {
        hi = mid - 1;
      } else if (position >= s.end) {
        lo = mid + 1;
      } else {
        return s;
      }
    }
    return null;
  }

  QuizQuestion questionFor(LearningSegment segment, {required LearningMode mode, String nativeLanguage = 'en'}) {
    final translated = segment.translation?.trim();
    final ar = nativeLanguage.toLowerCase().startsWith('ar');
    if (mode == LearningMode.listening) {
      return QuizQuestion(kind: QuizKind.dictation, prompt: ar ? 'اكتب ما سمعته في المقطع' : 'Type exactly what you heard', answer: segment.original, segment: segment);
    }
    if (translated != null && translated.isNotEmpty) {
      if (_random.nextBool()) {
        return QuizQuestion(kind: QuizKind.translateToNative, prompt: ar ? 'ترجم الجملة إلى لغتك' : 'Translate the line into your language', answer: translated, segment: segment);
      }
      return QuizQuestion(kind: QuizKind.translateToTarget, prompt: ar ? 'اكتب الجملة باللغة التي تتعلمها' : 'Write the line in the language you are learning', answer: segment.original, segment: segment);
    }
    final words = segment.original.split(RegExp(r'\s+')).where((e) => e.length > 2).toList();
    if (words.isNotEmpty) {
      final word = words[_random.nextInt(words.length)];
      return QuizQuestion(kind: QuizKind.fillBlank, prompt: segment.original.replaceFirst(word, '_____'), answer: word, segment: segment);
    }
    return QuizQuestion(kind: QuizKind.dictation, prompt: ar ? 'اكتب ما سمعته' : 'Type what you heard', answer: segment.original, segment: segment);
  }

  double scoreAnswer(String answer, String expected) => scoreDetailed(answer, expected).score;

  AnswerScore scoreDetailed(String answer, String expected) {
    final actual = _tokens(answer);
    final target = _tokens(expected);
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

  List<String> _tokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\u00C0-\u024F\u0400-\u052F\u0600-\u06FF\u0750-\u077F\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]+', unicode: true), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
}
