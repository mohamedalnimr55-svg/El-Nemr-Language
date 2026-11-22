import 'package:flutter_test/flutter_test.dart';

import 'package:el_nemr_language/learning/models/learning_models.dart';

void main() {
  test('exposes exactly the five user-facing learning modes', () {
    expect(
      LearningMode.values,
      <LearningMode>[
        LearningMode.watch,
        LearningMode.learn,
        LearningMode.listening,
        LearningMode.speak,
        LearningMode.test,
      ],
    );
  });

  group('Estimated learning difficulty', () {
    test('fast complex speech ranks above short slow speech', () {
      final easy = estimateLearningDifficulty(
        'I am home now.',
        const Duration(seconds: 4),
      );
      final hard = estimateLearningDifficulty(
        'Although the circumstances were unexpectedly complicated, nevertheless we decided to continue because the alternative was considerably worse.',
        const Duration(seconds: 4),
      );

      expect(hard, greaterThan(easy));
      expect(estimatedCefr(easy), isNotEmpty);
      expect(estimatedCefr(hard), isNotEmpty);
    });

    test('Hindi and Greek word-based captions are not discarded as empty', () {
      const duration = Duration(seconds: 3);
      final hindi = estimateLearningDifficulty(
        'हम आज अपने दोस्तों के साथ भाषा सीखने के लिए एक नई कहानी सुनने जा रहे हैं।',
        duration,
      );
      final greek = estimateLearningDifficulty(
        'Σήμερα θα μάθουμε μια καινούργια γλώσσα και θα συνεχίσουμε με δύσκολες λέξεις.',
        duration,
      );
      expect(hindi, greaterThan(.05));
      expect(greek, greaterThan(.05));
      expect(hindi, inInclusiveRange(.05, 1));
      expect(greek, inInclusiveRange(.05, 1));
    });

    test('Unicode word boundaries keep accents and leave empty input easy', () {
      expect(estimateLearningDifficulty('', const Duration(seconds: 4)), .05);
      final accented = estimateLearningDifficulty(
        'Είναι πραγματικά υπέροχο που όλοι συνεργαζόμαστε για να μιλήσουμε διαφορετικά.',
        const Duration(seconds: 2),
      );
      expect(accented, greaterThan(.05));
    });

    test('CEFR labels are monotonic', () {
      expect(estimatedCefr(0.10), 'A1');
      expect(estimatedCefr(0.25), 'A2');
      expect(estimatedCefr(0.45), 'B1');
      expect(estimatedCefr(0.60), 'B2');
      expect(estimatedCefr(0.75), 'C1');
      expect(estimatedCefr(0.95), 'C2');
    });
  });

  group('Role-play speaker parsing', () {
    test('parses colon labels', () {
      final line = parseDialogueLine('SARAH: I am going home.');
      expect(line.speaker, 'SARAH');
      expect(line.text, 'I am going home.');
    });

    test('parses bracket labels', () {
      final line = parseDialogueLine('[John] Where were you?');
      expect(line.speaker, 'John');
      expect(line.text, 'Where were you?');
    });

    test('parses WebVTT voice labels', () {
      final line = parseDialogueLine('<v Sarah>I was waiting.</v>');
      expect(line.speaker, 'Sarah');
      expect(line.text, 'I was waiting.');
    });

    test('does not invent a speaker for normal dialogue', () {
      final line = parseDialogueLine('Where have you been?');
      expect(line.speaker, isNull);
      expect(line.text, 'Where have you been?');
    });
  });
}
