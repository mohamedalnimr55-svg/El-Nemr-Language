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

  /// Only scores with matching original text and timing may influence
  /// adaptive practice. Subtitle replacements often reuse timestamp IDs.
  static bool matchesSegment(
    Map<String, dynamic>? progress,
    LearningSegment segment,
  ) => progress != null &&
      progress['original'] == segment.original &&
      progress['startMs'] == segment.start.inMilliseconds &&
      progress['endMs'] == segment.end.inMilliseconds;

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
        'startMs': segment.start.inMilliseconds,
        'endMs': segment.end.inMilliseconds,
      },
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key(videoKey), jsonEncode(data));
  });
}
