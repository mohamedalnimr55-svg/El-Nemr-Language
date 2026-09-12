import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/models/subtitle_cue.dart';
import 'package:el_nemr_language/learning/models/subtitle_layer.dart';

void main() {
  test('SubtitleLayer returns overlapping cues and applies independent delay', () {
    final layer = SubtitleLayer(
      id: 'x',
      label: 'English',
      source: 'file:///en.srt',
      language: 'en',
      delayMs: 500,
      cues: const <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 1),
          end: Duration(seconds: 4),
          text: 'A',
        ),
        SubtitleCue(
          start: Duration(seconds: 2),
          end: Duration(seconds: 3),
          text: 'B',
        ),
      ],
    );

    // Player position 2.75s becomes subtitle time 2.25s after +500 ms delay.
    expect(layer.textAt(const Duration(milliseconds: 2750)), 'A\nB');
    expect(layer.textAt(const Duration(milliseconds: 1400)), isEmpty);
  });
}
