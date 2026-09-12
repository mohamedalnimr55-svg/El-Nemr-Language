import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LearningProgressStore {
  const LearningProgressStore._();
  static String _key(String videoKey) => 'learning.progress.$videoKey';

  static Future<Map<String, dynamic>> load(String videoKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(videoKey));
    if (raw == null) return <String, dynamic>{};
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); } catch (_) { return <String, dynamic>{}; }
  }

  static Future<void> record(String videoKey, String segmentId, double score) async {
    final prefs = await SharedPreferences.getInstance();
    final data = await load(videoKey);
    final old = Map<String, dynamic>.from(data[segmentId] as Map? ?? const {});
    final attempts = (old['attempts'] as num?)?.toInt() ?? 0;
    final best = (old['best'] as num?)?.toDouble() ?? 0;
    data[segmentId] = <String, dynamic>{
      'attempts': attempts + 1,
      'best': score > best ? score : best,
      'last': score,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_key(videoKey), jsonEncode(data));
  }
}
