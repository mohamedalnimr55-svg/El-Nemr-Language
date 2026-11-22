import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_write_queue.dart';
import '../models/learning_models.dart';

class LearningProgressStore {
  const LearningProgressStore._();
  static String _key(String videoKey) => 'learning.progress.$videoKey';

  static Future<Map<String, dynamic>> load(String videoKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(videoKey));
    if (raw == null) return <String, dynamic>{};
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) { return <String, dynamic>{}; }
  }

  /// Only scores from the exact same original text, translation and timing
  /// may influence adaptive practice. Translation replacements can reuse IDs.
  /// Pre-existing records without translation identity are preserved, but
  /// cannot safely establish that the answer language/content was unchanged.
  static bool matchesSegment(
    Map<String, dynamic>? progress,
    LearningSegment segment,
  ) => progress != null &&
      progress.containsKey('translation') &&
      progress['original'] == segment.original &&
      progress['translation'] == segment.translation &&
      progress['startMs'] == segment.start.inMilliseconds &&
      progress['endMs'] == segment.end.inMilliseconds;

  /// An answer produced for an earlier subtitle version must not be
  /// attributed to a replacement that reuses the same segment ID.
  static bool sameSegmentIdentity(
    LearningSegment recorded,
    LearningSegment current,
  ) =>
      recorded.id == current.id &&
      recorded.start == current.start &&
      recorded.end == current.end &&
      recorded.original == current.original &&
      recorded.translation == current.translation;

  static Future<void> record(
    String videoKey,
    String segmentId,
    double score, {
    LearningSegment? segment,
  }) => LearningWriteQueue.run<void>(_key(videoKey), () async {
    final prefs = await SharedPreferences.getInstance();
    final data = await load(videoKey);
    final stored = Map<String, dynamic>.from(data[segmentId] as Map? ?? const {});
    final old = segment == null || matchesSegment(stored, segment)
        ? stored
        : <String, dynamic>{};
    final attempts = (old['attempts'] as num?)?.toInt() ?? 0;
    final best = (old['best'] as num?)?.toDouble() ?? 0;
    data[segmentId] = <String, dynamic>{
      'attempts': attempts + 1,
      'best': score > best ? score : best,
      'last': score,
      if (segment != null) ...<String, dynamic>{
        'original': segment.original,
        'translation': segment.translation,
        'startMs': segment.start.inMilliseconds,
        'endMs': segment.end.inMilliseconds,
      },
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key(videoKey), jsonEncode(data));
  });
}
