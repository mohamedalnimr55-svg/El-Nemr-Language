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

    test('chooses largest translation overlap, not the first one', () {
      const original = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 10),
          end: Duration(seconds: 13),
          text: 'This is the actual spoken line',
        ),
      ];
      const translated = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 9),
          end: Duration(seconds: 10, milliseconds: 30),
          text: 'Wrong previous sentence',
        ),
        SubtitleCue(
          start: Duration(seconds: 10, milliseconds: 100),
          end: Duration(seconds: 12, milliseconds: 800),
          text: 'Correct matching sentence',
        ),
      ];
      final segments = segmentsFromCues(original, translation: translated);
      expect(segments.single.translation, 'Correct matching sentence');
    });

    test('nearest translation fallback works for non-overlapping timed tracks', () {
      const original = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 10),
          end: Duration(seconds: 12),
          text: 'Current line',
        ),
      ];
      const near = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 12, milliseconds: 300),
          end: Duration(seconds: 13),
          text: 'Offset subtitle',
        ),
      ];
      const far = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 16),
          end: Duration(seconds: 17),
          text: 'Unrelated subtitle',
        ),
      ];
      expect(segmentsFromCues(original, translation: near).single.translation,
          'Offset subtitle');
      expect(segmentsFromCues(original, translation: far).single.translation,
          isNull);
    });

    test('tie in overlap prefers translation with closer start', () {
      const original = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 10),
          end: Duration(seconds: 12),
          text: 'Line to translate',
        ),
      ];
      const translated = <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 9),
          end: Duration(seconds: 11),
          text: 'Earlier half',
        ),
        SubtitleCue(
          start: Duration(seconds: 10),
          end: Duration(seconds: 11),
          text: 'Closer half',
        ),
      ];
      expect(
        segmentsFromCues(original, translation: translated).single.translation,
        'Closer half',
      );
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

    test('fill-blank quiz hides a character not a whole CJK sentence', () {
      final engine = LearningEngine(random: Random(3));
      for (final text in ['你好世界', 'こんにちは', '안녕하세요', 'สวัสดี']) {
        final segment = LearningSegment(
          id: text,
          start: Duration.zero,
          end: const Duration(seconds: 2),
          original: text,
        );
        final question = engine.questionFor(segment, mode: LearningMode.test);
        expect(question.kind, QuizKind.fillBlank, reason: text);
        expect(question.answer, isNotEmpty);
        expect(question.prompt, contains('_____'));
        expect(question.prompt, isNot('_____'),
            reason: 'The exercise must retain context around the gap.');
        expect(question.prompt.replaceFirst('_____', question.answer), text);
      }
    });

    test('cloze preserves casing and punctuation in Latin dialogue', () {
      final engine = LearningEngine(random: Random(1));
      const segment = LearningSegment(
        id: 'punctuation',
        start: Duration.zero,
        end: Duration(seconds: 2),
        original: 'Hello, WORLD!',
      );
      final question = engine.questionFor(segment, mode: LearningMode.test);
      expect(question.kind, QuizKind.fillBlank);
      expect(question.prompt, contains('_____'));
      expect(question.prompt.replaceFirst('_____', question.answer),
          segment.original);
    });

    test('symbol-only dialogue falls back to dictation rather than blanking all', () {
      final engine = LearningEngine(random: Random(2));
      const segment = LearningSegment(
        id: 'symbols',
        start: Duration.zero,
        end: Duration(seconds: 2),
        original: '🦊🦁',
      );
      final question = engine.questionFor(segment, mode: LearningMode.test);
      expect(question.kind, QuizKind.dictation);
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

    test('non-Latin scripts do not get false perfect scores when text differs', () {
      final engine = LearningEngine(random: Random(1));
      expect(engine.scoreAnswer('नमस्ते', 'नमस्ते!'), 1);
      expect(engine.scoreAnswer('नमस्ते', 'धन्यवाद'), lessThan(1));
      expect(engine.scoreAnswer('שלום', 'բוקר'), lessThan(1));
      expect(engine.scoreAnswer('γειά', 'αντίο'), lessThan(1));
      expect(engine.scoreAnswer('привет', 'пока'), lessThan(1));
      expect(engine.scoreAnswer('xin chào', 'xin chào'), 1);
      expect(engine.scoreAnswer('🦊', '🦁'), 0,
          reason: 'Unknown nonempty scripts/symbols must not be treated as empty.');
      expect(engine.scoreAnswer('สวัสด', 'สวัสดี'), inExclusiveRange(0, 1),
          reason: 'Unspaced Thai receives partial credit, not 0 or 100%.');
      expect(engine.scoreAnswer('ສະບາ', 'ສະບາຍ'), inExclusiveRange(0, 1));
    });

    test('less-common Unicode scripts count in multilingual answers', () {
      final engine = LearningEngine(random: Random(5));
      expect(engine.scoreAnswer('hello བཀྲ་ཤིས', 'hello ལྷ་ས'), lessThan(1),
          reason: 'Tibetan words must not vanish next to English.');
      expect(engine.scoreAnswer('abc ⵜⴰⵎⴰⵣⵉⵖⵜ', 'abc ⴰⵣⵓⵍ'), lessThan(1),
          reason: 'Tifinagh words must count even without a hardcoded block.');
      expect(engine.scoreAnswer('hello 🦊', 'hello 🦁'), closeTo(0.5, 0.001),
          reason: 'Symbols next to Latin words must not be silently dropped.');
      expect(engine.scoreAnswer('hello你好', 'hello你们'), closeTo(2 / 3, 0.001),
          reason: 'Chinese units must split even when adjacent to Latin text.');
      expect(engine.scoreAnswer('བཀྲ་ཤིས', 'བཀྲ་ཤིས'), 1);
    });

    test('Unicode combining marks and punctuation remain stable', () {
      final engine = LearningEngine(random: Random(5));
      expect(engine.scoreAnswer('Αθήνα!', 'αθήνα'), 1);
      expect(engine.scoreAnswer('नमस्ते', 'नमस्ते।'), 1);
      expect(engine.scoreAnswer('Hello, world!', 'hello world'), 1);
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
