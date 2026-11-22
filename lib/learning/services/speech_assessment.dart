import 'dart:math';

import 'learning_engine.dart';
import 'learning_text_tokenizer.dart';

class SpeechAssessment {
  const SpeechAssessment({
    required this.wordAccuracy,
    required this.completeness,
    required this.pace,
    required this.overall,
  });

  final double wordAccuracy;
  final double completeness;
  /// Null when only the recognition request duration is available.
  final double? pace;
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
  Duration? speakingDuration,
}) {
  final expectedWords = tokenizeLearningText(expectedText).length;
  final missing = answer.missingWords.length.clamp(0, expectedWords);
  final completeness = expectedWords == 0
      ? answer.score
      : ((expectedWords - missing) / expectedWords).clamp(0.0, 1.0).toDouble();

  // Word recognition takes time to initialize and finalize. Do not treat
  // stopwatch wall time around a platform recognition call as speaking time.
  // Only calculate pace if a recorder supplies measured speech duration.
  final double? pace;
  if (speakingDuration == null) {
    pace = null;
  } else {
    final expectedMs = max(1, expectedDuration.inMilliseconds);
    final actualMs = max(1, speakingDuration.inMilliseconds);
    final ratio = actualMs / expectedMs;
    pace = (1.0 - (ratio - 1.0).abs() / 1.35).clamp(0.0, 1.0).toDouble();
  }
  final overall = (
    pace == null
      ? answer.score * 0.70 + completeness * 0.30
      : answer.score * 0.55 + completeness * 0.25 + pace * 0.20
  ).clamp(0.0, 1.0).toDouble();

  return SpeechAssessment(
    wordAccuracy: answer.score,
    completeness: completeness,
    pace: pace,
    overall: overall,
  );
}

