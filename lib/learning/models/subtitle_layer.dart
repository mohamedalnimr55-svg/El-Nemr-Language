import 'package:flutter/material.dart';
import 'subtitle_cue.dart';

enum SubtitleLayerRole { original, translation, phonetic, notes }

class SubtitleLayer {
  SubtitleLayer({
    required this.id,
    required this.label,
    required this.source,
    required this.language,
    required this.cues,
    this.role = SubtitleLayerRole.original,
    this.x = 0.5,
    this.y = 0.82,
    this.scale = 1.0,
    this.delayMs = 0,
    this.visible = true,
    this.locked = false,
    this.textColor = Colors.white,
    this.backgroundColor = const Color(0xB3000000),
    this.outline = true,
  });

  final String id;
  final String source;
  String label;
  String language;
  SubtitleLayerRole role;
  List<SubtitleCue> cues;
  double x;
  double y;
  double scale;
  int delayMs;
  bool visible;
  bool locked;
  Color textColor;
  Color backgroundColor;
  bool outline;

  int _cursor = 0;
  int? _maxCueDurationMs;

  List<SubtitleCue> activeCues(Duration position) {
    if (cues.isEmpty) return const <SubtitleCue>[];
    final shifted = position - Duration(milliseconds: delayMs);
    final shiftedMs = shifted.inMilliseconds;
    if (_cursor >= cues.length) _cursor = cues.length - 1;

    // Keep a cursor at the last cue that has started. This makes normal
    // sequential playback O(1) amortized while still allowing seeks both ways.
    while (_cursor > 0 && cues[_cursor].start > shifted) {
      _cursor--;
    }
    while (_cursor + 1 < cues.length && cues[_cursor + 1].start <= shifted) {
      _cursor++;
    }
    if (cues[_cursor].start > shifted && _cursor == 0) {
      return const <SubtitleCue>[];
    }

    final maxDuration = _maxCueDurationMs ??= cues.fold<int>(
      0,
      (maxMs, cue) {
        final duration = (cue.end - cue.start).inMilliseconds;
        return duration > maxMs ? duration : maxMs;
      },
    );

    // Scan only as far back as an overlapping cue could possibly reach.
    // Unlike an "end <= now => break" shortcut, this remains correct for ASS
    // files with deliberately overlapping dialogue lines.
    final out = <SubtitleCue>[];
    for (var i = _cursor; i >= 0; i--) {
      final cue = cues[i];
      if (shiftedMs - cue.start.inMilliseconds > maxDuration) break;
      if (cue.start <= shifted && cue.end > shifted) out.insert(0, cue);
    }
    return out;
  }

  String textAt(Duration position) => activeCues(position)
      .map((e) => e.text)
      .where((e) => e.trim().isNotEmpty)
      .join('\n');

  Map<String, Object?> settingsToJson() => <String, Object?>{
        'id': id,
        'label': label,
        'source': source,
        'language': language,
        'role': role.name,
        'x': x,
        'y': y,
        'scale': scale,
        'delayMs': delayMs,
        'visible': visible,
        'locked': locked,
        'textColor': textColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
        'outline': outline,
      };
}
