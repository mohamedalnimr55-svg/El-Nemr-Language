import 'subtitle_cue.dart';

enum LearningMode { watch, learn, listening, speak, test }

enum QuizKind { translateToNative, translateToTarget, dictation, fillBlank, comprehension }

class LearningSegment {
  const LearningSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.original,
    this.translation,
    this.difficulty = 0.5,
  });

  final String id;
  final Duration start;
  final Duration end;
  final String original;
  final String? translation;
  final double difficulty;

  Duration get duration => end - start;
}

class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.prompt,
    required this.answer,
    required this.segment,
    this.options = const <String>[],
  });

  final QuizKind kind;
  final String prompt;
  final String answer;
  final LearningSegment segment;
  final List<String> options;
}

List<LearningSegment> segmentsFromCues(
  List<SubtitleCue> original, {
  List<SubtitleCue> translation = const <SubtitleCue>[],
}) {
  if (original.isEmpty) return const <LearningSegment>[];
  final source = List<SubtitleCue>.of(original)..sort((a, b) => a.start.compareTo(b.start));
  final translated = List<SubtitleCue>.of(translation)..sort((a, b) => a.start.compareTo(b.start));
  final out = <LearningSegment>[];
  var translationCursor = 0;

  for (var i = 0; i < source.length; i++) {
    final cue = source[i];
    final minTime = cue.start - const Duration(milliseconds: 2500);
    while (translationCursor < translated.length && translated[translationCursor].end < minTime) {
      translationCursor++;
    }
    final translationText = _translationNear(cue, translated, translationCursor);
    out.add(LearningSegment(
      id: 'seg_${cue.start.inMilliseconds}_$i',
      start: cue.start,
      end: cue.end,
      original: cue.text,
      translation: translationText,
      difficulty: estimateLearningDifficulty(cue.text, cue.end - cue.start),
    ));
  }
  return out;
}

String? _translationNear(SubtitleCue cue, List<SubtitleCue> translated, int startIndex) {
  if (translated.isEmpty || startIndex >= translated.length) return null;
  SubtitleCue? best;
  var bestScore = 1 << 62;
  final maxTime = cue.end + const Duration(milliseconds: 2500);
  for (var i = startIndex; i < translated.length; i++) {
    final candidate = translated[i];
    if (candidate.start > maxTime) break;
    final overlapStart = candidate.start > cue.start ? candidate.start : cue.start;
    final overlapEnd = candidate.end < cue.end ? candidate.end : cue.end;
    if (overlapEnd > overlapStart) return candidate.text;
    final score = (candidate.start.inMilliseconds - cue.start.inMilliseconds).abs();
    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return bestScore <= 2500 ? best?.text : null;
}

double estimateLearningDifficulty(String text, Duration duration) {
  final words = text
      .replaceAll(
        RegExp(
          r'[^\w\u00C0-\u024F\u0400-\u052F\u0600-\u06FF\u0750-\u077F\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF’\-]+',
          unicode: true,
        ),
        ' ',
      )
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 0.05;

  final normalized = words.map((e) => e.toLowerCase()).toList(growable: false);
  final averageLength = words.fold<int>(0, (sum, word) => sum + word.length) / words.length;
  final longWordRatio = words.where((word) => word.length >= 8).length / words.length;
  final lexicalDiversity = normalized.toSet().length / normalized.length;
  final durationMinutes = duration.inMilliseconds <= 0
      ? 0.0
      : duration.inMilliseconds / 60000.0;
  final wordsPerMinute = durationMinutes == 0 ? 0.0 : words.length / durationMinutes;

  final speedScore = ((wordsPerMinute - 85) / 145).clamp(0.0, 1.0).toDouble();
  final lengthScore = ((words.length - 5) / 24).clamp(0.0, 1.0).toDouble();
  final wordShapeScore = (((averageLength - 3.8) / 5.5) * 0.55 + longWordRatio * 0.45)
      .clamp(0.0, 1.0)
      .toDouble();
  final diversityScore = ((lexicalDiversity - 0.45) / 0.5).clamp(0.0, 1.0).toDouble();

  // Frequent clause/linking markers across the languages most commonly used
  // in the learning UI. This is intentionally a conservative heuristic, not
  // a claim of certified CEFR classification.
  const connectors = <String>{
    'although', 'though', 'however', 'unless', 'whereas', 'despite', 'because',
    'therefore', 'nevertheless', 'while', 'whenever', 'whoever', 'which',
    'obwohl', 'während', 'deshalb', 'trotzdem', 'wenn', 'weil', 'dass',
    'aunque', 'mientras', 'porque', 'sin embargo', 'donc', 'pourtant',
    'parce', 'puisque', 'لكن', 'لأن', 'رغم', 'بينما', 'حيث', 'إذا',
  };
  final lowerText = text.toLowerCase();
  var connectorHits = 0;
  for (final marker in connectors) {
    if (lowerText.contains(marker)) connectorHits++;
  }
  final clausePunctuation = RegExp(r'[,;:—–]|\([^)]{2,}\)').allMatches(text).length;
  final structureScore = ((connectorHits * 0.18) + (clausePunctuation * 0.09))
      .clamp(0.0, 1.0)
      .toDouble();

  return (
    speedScore * 0.26 +
    lengthScore * 0.18 +
    wordShapeScore * 0.20 +
    diversityScore * 0.14 +
    structureScore * 0.22
  ).clamp(0.05, 1.0).toDouble();
}

String estimatedCefr(double difficulty) {
  final value = difficulty.clamp(0.0, 1.0);
  if (value < 0.20) return 'A1';
  if (value < 0.35) return 'A2';
  if (value < 0.52) return 'B1';
  if (value < 0.68) return 'B2';
  if (value < 0.84) return 'C1';
  return 'C2';
}

class DialogueLine {
  const DialogueLine({required this.text, this.speaker});

  final String text;
  final String? speaker;
}

DialogueLine parseDialogueLine(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return const DialogueLine(text: '');

  final voice = RegExp(r'^<v(?:\.[^ >]+)*\s+([^>]+)>(.*?)(?:</v>)?$', caseSensitive: false, dotAll: true)
      .firstMatch(text);
  if (voice != null) {
    return DialogueLine(
      speaker: voice.group(1)?.trim(),
      text: (voice.group(2) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim(),
    );
  }

  final bracketed = RegExp(r'^\[([^\]\n]{1,32})\]\s*[:\-–—]?\s*(.+)$', dotAll: true).firstMatch(text);
  if (bracketed != null) {
    return DialogueLine(speaker: bracketed.group(1)?.trim(), text: (bracketed.group(2) ?? '').trim());
  }

  final colon = RegExp(r'^([\p{L}][\p{L}\p{N} ._\-]{0,30}):\s+(.+)$', unicode: true, dotAll: true).firstMatch(text);
  if (colon != null) {
    final speaker = colon.group(1)?.trim();
    // Avoid interpreting ordinary sentence prefixes as speakers. Subtitle
    // speaker labels are usually short and title/upper-cased.
    final likelyLabel = speaker != null &&
        (speaker == speaker.toUpperCase() ||
         speaker.split(RegExp(r'\s+')).every((part) => part.isNotEmpty && part[0] == part[0].toUpperCase()));
    if (likelyLabel) {
      return DialogueLine(speaker: speaker, text: (colon.group(2) ?? '').trim());
    }
  }

  text = text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  return DialogueLine(text: text);
}
