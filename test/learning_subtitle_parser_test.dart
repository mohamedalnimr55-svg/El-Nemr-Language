import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/subtitle_parser.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';

void main() {
  group('SubtitleParser', () {
    test('parses SRT, strips markup and sorts cues', () {
      const source = '''
2
00:00:03,500 --> 00:00:05,000
Second &amp; <i>clean</i>

1
00:00:01,000 --> 00:00:02,250
Hello world
''';
      final cues = SubtitleParser.parse(source, extension: 'srt');
      expect(cues, hasLength(2));
      expect(cues.first.start, const Duration(seconds: 1));
      expect(cues.first.end, const Duration(seconds: 2, milliseconds: 250));
      expect(cues.first.text, 'Hello world');
      expect(cues.last.text, 'Second & clean');
    });

    test('parses WebVTT cue identifiers and timestamps', () {
      const source = '''WEBVTT

intro
00:01.100 --> 00:03.250 align:start
Hello
world

00:00:04.000 --> 00:00:05.000
Bye
''';
      final cues = SubtitleParser.parse(source, extension: 'vtt');
      expect(cues, hasLength(2));
      expect(cues.first.start, const Duration(seconds: 1, milliseconds: 100));
      expect(cues.first.text, 'Hello\nworld');
      expect(cues.last.text, 'Bye');
    });

    test('sorts out-of-order WebVTT cues for video playback and seeking', () {
      const source = '''WEBVTT

00:00:10.000 --> 00:00:12.000
Late cue

00:00:01.000 --> 00:00:03.000
First cue

00:00:05.000 --> 00:00:07.000
Middle cue
''';
      final cues = SubtitleParser.parse(source, extension: 'vtt');
      expect(cues.map((cue) => cue.text),
          <String>['First cue', 'Middle cue', 'Late cue']);
      expect(cues.first.start, const Duration(seconds: 1));
      expect(cues.last.start, const Duration(seconds: 10));
    });

    test('SRT ignores styling-only subtitle cues', () {
      const source = '''1
00:00:01,000 --> 00:00:02,000
<i></i>

2
00:00:03,000 --> 00:00:04,000
Actual words
''';
      final cues = SubtitleParser.parse(source, extension: 'srt');
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Actual words');
    });

    test('WebVTT ignores NOTE, STYLE and REGION metadata blocks', () {
      const source = '''WEBVTT

NOTE Not spoken dialogue
00:00:01.000 --> 00:00:02.000
This comment is not a subtitle.

STYLE
::cue { color: yellow; }
00:00:03.000 --> 00:00:04.000
Not dialogue either.

REGION
id:bottom
00:00:05.000 --> 00:00:06.000
Not spoken text.

real-cue
00:00:07.000 --> 00:00:08.000 align:start
Actual dialogue
''';
      final cues = SubtitleParser.parse(source, extension: 'vtt');
      expect(cues, hasLength(1));
      expect(cues.single.start, const Duration(seconds: 7));
      expect(cues.single.text, 'Actual dialogue');
    });

    test('SRT skips reversed-duration cues rather than creating broken lessons', () {
      const source = '''1
00:00:04,000 --> 00:00:03,000
Reverse time

2
00:00:05,000 --> 00:00:06,000
Real sentence
''';
      final cues = SubtitleParser.parse(source, extension: 'srt');
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Real sentence');
    });

    test('WebVTT speaker tags survive parsing for real role-play lines', () {
      const source = '''WEBVTT

00:00:01.000 --> 00:00:02.500
<v Sarah>Hello, John.</v>

00:00:03.000 --> 00:00:04.500
<v John>Hi, Sarah.</v>
''';
      final cues = SubtitleParser.parse(source, extension: 'vtt');
      expect(cues, hasLength(2));
      final sarah = parseDialogueLine(cues.first.text);
      final john = parseDialogueLine(cues.last.text);
      expect(sarah.speaker, 'Sarah');
      expect(sarah.text, 'Hello, John.');
      expect(john.speaker, 'John');
      expect(john.text, 'Hi, Sarah.');
    });

    test('WebVTT styling without voice labels remains plain text', () {
      const source = '''WEBVTT

00:00:01.000 --> 00:00:02.500
<i>This is important.</i>
''';
      final cues = SubtitleParser.parse(source, extension: 'vtt');
      expect(cues.single.text, 'This is important.');
      expect(parseDialogueLine(cues.single.text).speaker, isNull);
    });

    test('ASS speaker Name is retained for role-play without altering dialogue', () {
      const source = '''[Script Info]
Title: Role-play

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.20,0:00:03.40,Default,Sarah,0,0,0,,Hello, John!
Dialogue: 0,0:00:04.20,0:00:05.40,Default,John,0,0,0,,Hi, Sarah!
''';
      final cues = SubtitleParser.parse(source, extension: 'ass');
      expect(cues, hasLength(2));
      final first = parseDialogueLine(cues.first.text);
      final second = parseDialogueLine(cues.last.text);
      expect(first.speaker, 'Sarah');
      expect(first.text, 'Hello, John!');
      expect(second.speaker, 'John');
      expect(second.text, 'Hi, Sarah!');
    });

    test('ASS blank Name leaves text unmodified and invalid durations are ignored', () {
      const source = '''[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,Good morning
Dialogue: 0,0:00:04.00,0:00:03.00,Default,Alice,0,0,0,,Bad timestamps
''';
      final cues = SubtitleParser.parse(source, extension: 'ass');
      expect(cues, hasLength(1));
      expect(cues.single.text, 'Good morning');
      expect(parseDialogueLine(cues.single.text).speaker, isNull);
    });

    test('parses ASS dialogue and removes override tags', () {
      const source = '''[Script Info]
Title: Test

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.20,0:00:03.40,Default,,0,0,0,,{\\i1}Hello{\\i0}\\Nworld
''';
      final cues = SubtitleParser.parse(source, extension: 'ass');
      expect(cues, hasLength(1));
      expect(cues.single.start, const Duration(seconds: 1, milliseconds: 200));
      expect(cues.single.end, const Duration(seconds: 3, milliseconds: 400));
      expect(cues.single.text, 'Hello\nworld');
    });
  });
}
