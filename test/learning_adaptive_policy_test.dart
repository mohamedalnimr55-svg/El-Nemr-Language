import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/adaptive_learning_policy.dart';

void main() {
  test('mastered material becomes listening-only challenge', () {
    final d = AdaptiveLearningPolicy.decide(difficulty: .6, bestScore: .96, attempts: 3);
    expect(d.showOriginal, isFalse);
    expect(d.showTranslation, isFalse);
    expect(d.speedFactor, 1.0);
  });

  test('weak or difficult material receives support and slower playback', () {
    final d = AdaptiveLearningPolicy.decide(difficulty: .85, bestScore: .4, attempts: 1);
    expect(d.showOriginal, isTrue);
    expect(d.showTranslation, isTrue);
    expect(d.speedFactor, lessThan(1.0));
  });

  test('easy unseen material hides native translation', () {
    final d = AdaptiveLearningPolicy.decide(difficulty: .2);
    expect(d.showOriginal, isTrue);
    expect(d.showTranslation, isFalse);
  });
}
