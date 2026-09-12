import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/models/subtitle_cue.dart';
import 'package:el_nemr_language/learning/services/learning_engine.dart';

void main() {
  group('Learning timeline', () {
    test('aligns translated cue by overlap and keeps source timing', () {
      const original = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 10),
          end: Duration(seconds: 12),
          text: 'How are you?',
        ),
      ];
      const translated = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 10, milliseconds: 250),
          end: Duration(seconds: 12, milliseconds: 300),
          text: 'كيف حالك؟',
        ),
      ];
      final segments = segmentsFromCues(original, translation: translated);
      expect(segments, hasLength(1));
      expect(segments.single.translation, 'كيف حالك؟');
      expect(segments.single.start, const Duration(seconds: 10));
    });

    test('segmentAt performs exact boundary lookup', () {
      final engine = LearningEngine(random: Random(1));
      const segments = <LearningSegment>[
        LearningSegment(
          id: 'a',
          start: Duration(seconds: 1),
          end: Duration(seconds: 3),
          original: 'one',
        ),
        LearningSegment(
          id: 'b',
          start: Duration(seconds: 4),
          end: Duration(seconds: 6),
          original: 'two',
        ),
      ];
      expect(engine.segmentAt(segments, const Duration(seconds: 2))?.id, 'a');
      expect(engine.segmentAt(segments, const Duration(seconds: 3)), isNull);
      expect(engine.segmentAt(segments, const Duration(seconds: 5))?.id, 'b');
    });

    test('answer scoring is normalized and punctuation-insensitive', () {
      final engine = LearningEngine(random: Random(1));
      expect(engine.scoreAnswer('Hello, WORLD!', 'hello world'), 1.0);
      expect(engine.scoreAnswer('hello', 'hello world'), closeTo(0.5, 0.001));
      expect(engine.scoreAnswer('', 'hello world'), 0.0);
      expect(engine.scoreAnswer('مرحبا بك', 'مرحبا بك'), 1.0);
    });

    test('detailed scoring reports missing and different words', () {
      final engine = LearningEngine(random: Random(1));
      final result = engine.scoreDetailed('I go school', 'I go to school');
      expect(result.score, closeTo(0.75, 0.001));
      expect(result.missingWords, contains('to'));
      expect(result.extraWords, isEmpty);

      final substitution = engine.scoreDetailed('I like cats', 'I like dogs');
      expect(substitution.missingWords, contains('dogs'));
      expect(substitution.extraWords, contains('cats'));
    });
  });
}
