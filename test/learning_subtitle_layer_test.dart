import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/models/subtitle_cue.dart';
import 'package:el_nemr_language/learning/models/subtitle_layer.dart';

void main() {
  test('replacing a subtitle track refreshes cue duration and seek cursor', () {
    final layer = SubtitleLayer(
      id: 'replace', label: 'Original', source: 'old.srt',
      language: 'en',
      cues: const <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          text: 'Short old cue',
        ),
      ],
    );
    expect(layer.textAt(const Duration(milliseconds: 1500)), 'Short old cue');
    // Populate the cached maximum duration with the old one-second cue.
    expect(layer.textAt(const Duration(seconds: 10)), isEmpty);

    layer.cues = const <SubtitleCue>[
      SubtitleCue(
        start: Duration(seconds: 8),
        end: Duration(seconds: 9),
        text: 'Short interruption',
      ),
      SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 12),
        text: 'Long new cue',
      ),
    ];

    // New track data is sorted, and a still-running long line survives the
    // end of the later short interjection.
    expect(layer.cues.first.text, 'Long new cue');
    expect(layer.textAt(const Duration(milliseconds: 8500)),
        'Long new cue\nShort interruption');
    expect(layer.textAt(const Duration(seconds: 10)), 'Long new cue');
    expect(layer.textAt(const Duration(milliseconds: 500)), isEmpty);
  });

  test('constructor snapshots incoming cues instead of retaining an unsorted list', () {
    final provided = <SubtitleCue>[
      const SubtitleCue(
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
        text: 'Later',
      ),
      const SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'Earlier',
      ),
    ];
    final layer = SubtitleLayer(
      id: 'copy', label: 'Dialogue', source: 'sample.vtt',
      language: 'en', cues: provided,
    );
    expect(layer.textAt(const Duration(milliseconds: 1500)), 'Earlier');
    provided.clear();
    expect(layer.cues, hasLength(2));
    expect(layer.textAt(const Duration(seconds: 6)), 'Later');
  });

  test('published cues cannot be edited around timeline cache invalidation', () {
    final layer = SubtitleLayer(
      id: 'immutable', label: 'Learning', source: 'first.srt',
      language: 'en',
      cues: const <SubtitleCue>[
        SubtitleCue(
          start: Duration(seconds: 2),
          end: Duration(seconds: 4),
          text: 'First',
        ),
      ],
    );
    // Populate internal cursor and maximum cue duration.
    expect(layer.textAt(const Duration(seconds: 3)), 'First');
    expect(() => layer.cues.clear(), throwsUnsupportedError);
    expect(() => layer.cues.add(
      const SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 10),
        text: 'Untracked edit',
      ),
    ), throwsUnsupportedError);
    expect(layer.textAt(const Duration(seconds: 3)), 'First');

    final provided = <SubtitleCue>[
      const SubtitleCue(
        start: Duration(seconds: 6),
        end: Duration(seconds: 7),
        text: 'Interjection',
      ),
      const SubtitleCue(
        start: Duration(seconds: 1),
        end: Duration(seconds: 11),
        text: 'New long subtitle',
      ),
    ];
    layer.cues = provided;
    provided.clear();
    expect(layer.cues, hasLength(2));
    expect(() => layer.cues.removeAt(0), throwsUnsupportedError);
    expect(layer.textAt(const Duration(seconds: 8)), 'New long subtitle');
    expect(layer.textAt(const Duration(seconds: 6)), 'New long subtitle\nInterjection');
  });

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
