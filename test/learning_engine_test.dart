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
      expect(engine.segmentAt(segments, Duration.zero), isNull,
          reason: 'The first subtitle must not appear before its start time.');
      expect(engine.segmentAt(segments, const Duration(seconds: 2))?.id, 'a');
      expect(engine.segmentAt(segments, const Duration(seconds: 3)), isNull,
          reason: 'A subtitle gap must not display the first spoken line.');
      expect(engine.segmentAt(segments, const Duration(seconds: 5))?.id, 'b');
      expect(engine.segmentAt(segments, const Duration(seconds: 7)), isNull,
          reason: 'The first subtitle must not reappear after the last cue.');
    });

    test('overlapping captions retain an earlier active dialogue cue', () {
      final engine = LearningEngine(random: Random(1));
      const segments = <LearningSegment>[
        LearningSegment(
          id: 'long',
          start: Duration(seconds: 1),
          end: Duration(seconds: 8),
          original: 'A long line across two subtitles',
        ),
        LearningSegment(
          id: 'short',
          start: Duration(seconds: 3),
          end: Duration(seconds: 4),
          original: 'Brief interruption',
        ),
        LearningSegment(
          id: 'later',
          start: Duration(seconds: 10),
          end: Duration(seconds: 11),
          original: 'Next scene',
        ),
      ];
      expect(engine.segmentAt(segments, const Duration(seconds: 2))?.id, 'long');
      expect(engine.segmentAt(segments, const Duration(milliseconds: 3500))?.id,
          'short');
      expect(engine.segmentAt(segments, const Duration(seconds: 5))?.id,
          'long', reason: 'The earlier cue remains active after the short cue ends.');
      expect(engine.segmentAt(segments, const Duration(seconds: 8)), isNull);
      expect(engine.segmentAt(segments, const Duration(seconds: 9)), isNull);
      expect(engine.segmentAt(segments, const Duration(seconds: 10))?.id, 'later');
    });

    test('dictation and translation quizzes omit VTT speaker metadata', () {
      final engine = LearningEngine(random: Random(42));
      const annotated = LearningSegment(
        id: 'speaker',
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        original: '[Sarah] I am home.',
        translation: '[سارة] أنا في البيت.',
      );

      final listening = engine.questionFor(
        annotated,
        mode: LearningMode.listening,
      );
      expect(listening.answer, 'I am home.');
      final quiz = engine.questionFor(annotated, mode: LearningMode.test);
      expect(quiz.answer, anyOf('I am home.', 'أنا في البيت.'));
      expect(quiz.answer, isNot(contains('[Sarah]')));
      expect(quiz.answer, isNot(contains('[سارة]')));
      final recognized = parseDialogueLine(annotated.original).text;
      expect(engine.scoreAnswer('I am home.', recognized), 1);
    });

    test('speech recognition uses the language of the expected quiz answer', () {
      const segment = LearningSegment(
        id: 'speech',
        start: Duration.zero,
        end: Duration(seconds: 2),
        original: 'How are you?',
        translation: 'كيف حالك؟',
      );
      const nativeQuestion = QuizQuestion(
        kind: QuizKind.translateToNative,
        prompt: 'Translate',
        answer: 'كيف حالك؟',
        segment: segment,
      );
      const targetQuestion = QuizQuestion(
        kind: QuizKind.dictation,
        prompt: 'Dictate',
        answer: 'How are you?',
        segment: segment,
      );
      expect(
        LearningEngine.answerLanguageForQuestion(
          nativeQuestion, nativeLanguage: 'ar', targetLanguage: 'en',
        ),
        'ar',
      );
      expect(
        LearningEngine.answerLanguageForQuestion(
          targetQuestion, nativeLanguage: 'ar', targetLanguage: 'en',
        ),
        'en',
      );
    });

    test('answer scoring is normalized and punctuation-insensitive', () {
      final engine = LearningEngine(random: Random(1));
      expect(engine.scoreAnswer('Hello, WORLD!', 'hello world'), 1.0);
      expect(engine.scoreAnswer('hello', 'hello world'), closeTo(0.5, 0.001));
      expect(engine.scoreAnswer('', 'hello world'), 0.0);
      expect(engine.scoreAnswer('مرحبا بك', 'مرحبا بك'), 1.0);
    });

    test('CJK responses receive partial credit for missing characters', () {
      final engine = LearningEngine(random: Random(1));
      final chinese = engine.scoreDetailed('你好世', '你好世界');
      expect(chinese.score, closeTo(0.75, 0.001));
      expect(chinese.missingWords, <String>['界']);
      expect(chinese.extraWords, isEmpty);

      final japanese = engine.scoreDetailed('こんにち', 'こんにちは');
      expect(japanese.score, closeTo(0.8, 0.001));
      expect(japanese.missingWords, <String>['は']);

      final korean = engine.scoreDetailed('안녕하세', '안녕하세요');
      expect(korean.score, closeTo(0.8, 0.001));
      expect(korean.missingWords, <String>['요']);

      expect(engine.scoreAnswer('hello 世界', 'HELLO，世界！'), 1);
      expect(engine.scoreAnswer('你好', '你好'), 1);
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
