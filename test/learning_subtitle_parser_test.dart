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
