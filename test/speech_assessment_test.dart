import 'package:flutter_test/flutter_test.dart';

import 'package:el_nemr_language/learning/services/learning_engine.dart';
import 'package:el_nemr_language/learning/services/speech_assessment.dart';

void main() {
  const perfect = AnswerScore(
    score: 1,
    missingWords: <String>[],
    extraWords: <String>[],
  );

  test('shadowing without measured speech time does not invent pace', () {
    const partial = AnswerScore(
      score: 0.8,
      missingWords: <String>['today'],
      extraWords: <String>[],
    );
    final assessment = assessSpeech(
      answer: partial,
      expectedText: 'Where are you going today',
      expectedDuration: const Duration(seconds: 3),
    );
    expect(assessment.pace, isNull);
    expect(assessment.overall, closeTo(0.8 * 0.70 + 0.8 * 0.30, 0.001));
  });

  test('CJK completeness uses the same scoring units as the evaluator', () {
    final engine = LearningEngine();
    final answer = engine.scoreDetailed('你好世', '你好世界');
    final assessment = assessSpeech(
      answer: answer,
      expectedText: '你好世界',
      expectedDuration: const Duration(seconds: 2),
    );
    expect(assessment.wordAccuracy, closeTo(.75, .001));
    expect(assessment.completeness, closeTo(.75, .001));
    expect(assessment.pace, isNull);
  });

  test('matching words at actor pace scores very highly', () {
    final result = assessSpeech(
      answer: perfect,
      expectedText: 'Where have you been today',
      expectedDuration: const Duration(seconds: 3),
      speakingDuration: const Duration(milliseconds: 3100),
    );

    expect(result.wordAccuracy, 1);
    expect(result.completeness, 1);
    expect(result.pace, greaterThan(.9));
    expect(result.overall, greaterThan(.95));
  });

  test('missing words and very slow delivery lower independent dimensions', () {
    const partial = AnswerScore(
      score: .6,
      missingWords: <String>['been', 'today'],
      extraWords: <String>[],
    );
    final result = assessSpeech(
      answer: partial,
      expectedText: 'Where have you been today',
      expectedDuration: const Duration(seconds: 2),
      speakingDuration: const Duration(seconds: 5),
    );

    expect(result.completeness, closeTo(.6, .001));
    expect(result.pace, lessThan(.3));
    expect(result.overall, lessThan(.65));
  });
}
