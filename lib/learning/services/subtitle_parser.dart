import '../models/subtitle_cue.dart';

class SubtitleParser {
  const SubtitleParser._();

  static List<SubtitleCue> parse(String source, {String? extension}) {
    final normalized = source.replaceFirst('\uFEFF', '').replaceAll('\r\n', '\n');
    final ext = (extension ?? '').toLowerCase();
    if (ext.endsWith('vtt') || normalized.trimLeft().startsWith('WEBVTT')) {
      return _parseVtt(normalized);
    }
    if (ext.endsWith('ass') || ext.endsWith('ssa') || normalized.contains('[Events]')) {
      return _parseAss(normalized);
    }
    return _parseSrt(normalized);
  }

  static List<SubtitleCue> _parseSrt(String source) {
    final blocks = source.split(RegExp(r'\n\s*\n'));
    final cues = <SubtitleCue>[];
    final timeRe = RegExp(r'(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{1,3})');
    for (final block in blocks) {
      final lines = block.split('\n').where((e) => e.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      var timeIndex = lines.indexWhere((l) => timeRe.hasMatch(l));
      if (timeIndex < 0) continue;
      final m = timeRe.firstMatch(lines[timeIndex]);
      if (m == null) continue;
      final text = lines.skip(timeIndex + 1).join('\n').trim();
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: _clock(m.group(1)!), end: _clock(m.group(2)!), text: _clean(text)));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<SubtitleCue> _parseVtt(String source) {
    final lines = source.split('\n');
    final cues = <SubtitleCue>[];
    final timeRe = RegExp(r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[.](\d{1,3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[.](\d{1,3})');
    var i = 0;
    while (i < lines.length) {
      final m = timeRe.firstMatch(lines[i]);
      if (m == null) { i++; continue; }
      final start = _vttClock(m.group(1), m.group(2)!, m.group(3)!, m.group(4)!);
      final end = _vttClock(m.group(5), m.group(6)!, m.group(7)!, m.group(8)!);
      i++;
      final text = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) { text.add(lines[i]); i++; }
      final value = _clean(text.join('\n'));
      if (value.isNotEmpty) cues.add(SubtitleCue(start: start, end: end, text: value));
    }
    return cues;
  }

  static List<SubtitleCue> _parseAss(String source) {
    final cues = <SubtitleCue>[];
    var format = <String>[];
    var inEvents = false;
    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().startsWith('[')) {
        inEvents = line.trim().toLowerCase() == '[events]';
        continue;
      }
      if (!inEvents) continue;
      if (line.toLowerCase().startsWith('format:')) {
        format = line.substring(line.indexOf(':') + 1).split(',').map((e) => e.trim().toLowerCase()).toList();
        continue;
      }
      if (!line.toLowerCase().startsWith('dialogue:')) continue;
      final payload = line.substring(line.indexOf(':') + 1).trimLeft();
      final fields = _splitAss(payload, format.isEmpty ? 10 : format.length);
      if (fields.length < 3) continue;
      final startPosition = format.indexOf('start');
      final endPosition = format.indexOf('end');
      final textPosition = format.indexOf('text');
      final startIndex = startPosition >= 0 ? startPosition : 1;
      final endIndex = endPosition >= 0 ? endPosition : 2;
      final textIndex = textPosition >= 0 ? textPosition : fields.length - 1;
      if (startIndex >= fields.length || endIndex >= fields.length || textIndex >= fields.length) continue;
      final text = _cleanAss(fields.sublist(textIndex).join(','));
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: _assClock(fields[startIndex]), end: _assClock(fields[endIndex]), text: text));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  static List<String> _splitAss(String value, int expected) {
    final out = <String>[];
    var rest = value;
    for (var i = 0; i < expected - 1; i++) {
      final comma = rest.indexOf(',');
      if (comma < 0) break;
      out.add(rest.substring(0, comma));
      rest = rest.substring(comma + 1);
    }
    out.add(rest);
    return out;
  }

  static String _clean(String value) => value
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  static String _cleanAss(String value) => _clean(value
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\h', ' '));

  static Duration _clock(String value) {
    final p = value.replaceAll(',', '.').split(':');
    final sec = p[2].split('.');
    return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]), seconds: int.parse(sec[0]), milliseconds: _millis(sec.length > 1 ? sec[1] : '0'));
  }

  static Duration _vttClock(String? h, String m, String s, String ms) => Duration(hours: int.tryParse(h ?? '0') ?? 0, minutes: int.tryParse(m) ?? 0, seconds: int.tryParse(s) ?? 0, milliseconds: _millis(ms));

  static Duration _assClock(String value) {
    final p = value.trim().split(':');
    final sec = p.last.split('.');
    return Duration(hours: int.tryParse(p.length > 2 ? p[p.length - 3] : '0') ?? 0, minutes: int.tryParse(p[p.length - 2]) ?? 0, seconds: int.tryParse(sec[0]) ?? 0, milliseconds: (int.tryParse(sec.length > 1 ? sec[1].padRight(2, '0').substring(0, 2) : '0') ?? 0) * 10);
  }

  static int _millis(String value) {
    final v = value.padRight(3, '0');
    return int.tryParse(v.substring(0, 3)) ?? 0;
  }
}
