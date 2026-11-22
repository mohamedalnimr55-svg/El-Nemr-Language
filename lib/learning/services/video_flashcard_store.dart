import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_models.dart';
import 'learning_write_queue.dart';

class VideoFlashcardStore {
  const VideoFlashcardStore._();
  static String _key(String videoKey) => 'learning.flashcards.$videoKey';

  static Future<Map<String, Map<String, dynamic>>> load(String videoKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(videoKey));
    if (raw == null || raw.isEmpty) return <String, Map<String, dynamic>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, dynamic>>{};
      return <String, Map<String, dynamic>>{
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  static Future<bool> toggle(String videoKey, LearningSegment segment) =>
      LearningWriteQueue.run<bool>(_key(videoKey), () async {
    final prefs = await SharedPreferences.getInstance();
    final cards = await load(videoKey);
    if (matchesSegment(cards[segment.id], segment)) {
      cards.remove(segment.id);
      await prefs.setString(_key(videoKey), jsonEncode(cards));
      return false;
    }
    cards[segment.id] = <String, dynamic>{
      'id': segment.id,
      'startMs': segment.start.inMilliseconds,
      'endMs': segment.end.inMilliseconds,
      'original': segment.original,
      'translation': segment.translation,
      'repetitions': 0,
      'intervalDays': 0,
      'ease': 2.5,
      'dueAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key(videoKey), jsonEncode(cards));
    return true;
  });

  static Future<void> review(String videoKey, String segmentId, double score) =>
      LearningWriteQueue.run<void>(_key(videoKey), () async {
    final prefs = await SharedPreferences.getInstance();
    final cards = await load(videoKey);
    final card = cards[segmentId];
    if (card == null) return;

    var repetitions = (card['repetitions'] as num?)?.toInt() ?? 0;
    var interval = (card['intervalDays'] as num?)?.toInt() ?? 0;
    var ease = (card['ease'] as num?)?.toDouble() ?? 2.5;
    final quality = (score * 5).round().clamp(0, 5);

    // SM-2 inspired schedule: weak answers return tomorrow; strong answers
    // expand the interval while keeping an ease floor.
    if (quality < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      repetitions++;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * ease).round().clamp(1, 3650).toInt();
      }
      ease = (ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))).clamp(1.3, 3.0).toDouble();
    }

    card
      ..['repetitions'] = repetitions
      ..['intervalDays'] = interval
      ..['ease'] = ease
      ..['lastScore'] = score
      ..['dueAt'] = DateTime.now().add(Duration(days: interval)).toIso8601String();
    await prefs.setString(_key(videoKey), jsonEncode(cards));
  });

  /// Subtitle IDs can remain unchanged when the original or translated
  /// track is replaced. An old card must never be reviewed, removed or
  /// mistakenly graded against the changed dialogue.
  static bool matchesSegment(
    Map<String, dynamic>? card,
    LearningSegment segment,
  ) => card != null &&
      card.containsKey('translation') &&
      card['original'] == segment.original &&
      card['translation'] == segment.translation &&
      card['startMs'] == segment.start.inMilliseconds &&
      card['endMs'] == segment.end.inMilliseconds;

  /// Only schedule due cards whose *content* still matches a current subtitle.
  /// Existing orphaned cards stay in storage until a user replaces/removes
  /// them, instead of hijacking the new transcript's learning progress.
  static List<MapEntry<String, Map<String, dynamic>>> dueForSegments(
    Map<String, Map<String, dynamic>> cards,
    Iterable<LearningSegment> activeSegments, {
    DateTime? now,
  }) {
    final currentById = <String, LearningSegment>{
      for (final segment in activeSegments) segment.id: segment,
    };
    return cards.entries.where((entry) {
      final segment = currentById[entry.key];
      return segment != null &&
          matchesSegment(entry.value, segment) &&
          isDue(entry.value, now: now);
    }).toList(growable: false);
  }

  static bool isDue(Map<String, dynamic> card, {DateTime? now}) {
    final raw = card['dueAt'] as String?;
    final due = raw == null ? null : DateTime.tryParse(raw);
    return due == null || !due.isAfter(now ?? DateTime.now());
  }
}
