import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/models/subtitle_cue.dart';
import 'package:el_nemr_language/learning/services/transcription_service.dart';

void main() {
  test('timed cues serialize to stable SRT', () {
    const cues = <SubtitleCue>[
      SubtitleCue(
        start: Duration(seconds: 1, milliseconds: 5),
        end: Duration(seconds: 2, milliseconds: 90),
        text: 'Hello',
      ),
      SubtitleCue(
        start: Duration(minutes: 1, seconds: 2),
        end: Duration(minutes: 1, seconds: 4, milliseconds: 125),
        text: 'World',
      ),
    ];
    final srt = TranscriptionService.toSrt(cues);
    expect(srt, contains('00:00:01,005 --> 00:00:02,090'));
    expect(srt, contains('00:01:02,000 --> 00:01:04,125'));
    expect(srt, contains('Hello'));
  });
}
