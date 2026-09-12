import 'dart:math';

import 'learning_engine.dart';

class SpeechAssessment {
  const SpeechAssessment({
    required this.wordAccuracy,
    required this.completeness,
    required this.pace,
    required this.overall,
  });

  final double wordAccuracy;
  final double completeness;
  final double pace;
  final double overall;
}

/// Honest local speaking feedback built from recognized words and timing.
///
/// It intentionally does not claim phoneme/accent scoring. [wordAccuracy]
/// comes from text alignment, [completeness] measures how much of the expected
/// line was recognized, and [pace] compares speaking duration with the actor's
/// segment duration using a forgiving ratio curve.
SpeechAssessment assessSpeech({
  required AnswerScore answer,
  required String expectedText,
  required Duration expectedDuration,
  required Duration speakingDuration,
}) {
  final expectedWords = _tokens(expectedText).length;
  final missing = answer.missingWords.length.clamp(0, expectedWords);
  final completeness = expectedWords == 0
      ? answer.score
      : ((expectedWords - missing) / expectedWords).clamp(0.0, 1.0).toDouble();

  final expectedMs = max(1, expectedDuration.inMilliseconds);
  final actualMs = max(1, speakingDuration.inMilliseconds);
  final ratio = actualMs / expectedMs;
  // Full credit around the actor's pace, gradually decreasing for very fast
  // or very slow delivery. 0.5x and 2x still get partial credit rather than 0.
  final pace = (1.0 - (ratio - 1.0).abs() / 1.35).clamp(0.0, 1.0).toDouble();
  final overall = (
    answer.score * 0.55 +
    completeness * 0.25 +
    pace * 0.20
  ).clamp(0.0, 1.0).toDouble();

  return SpeechAssessment(
    wordAccuracy: answer.score,
    completeness: completeness,
    pace: pace,
    overall: overall,
  );
}

List<String> _tokens(String value) => value
    .toLowerCase()
    .replaceAll(
      RegExp(
        r'[^\w\u00C0-\u024F\u0400-\u052F\u0600-\u06FF\u0750-\u077F\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]+',
        unicode: true,
      ),
      ' ',
    )
    .trim()
    .split(RegExp(r'\s+'))
    .where((e) => e.isNotEmpty)
    .toList(growable: false);
