import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subtitle_layer.dart';

class SubtitleLayerStore {
  const SubtitleLayerStore._();
  static String _key(String videoKey) => 'learning.subtitleLayers.$videoKey';

  static Future<void> save(String videoKey, List<SubtitleLayer> layers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(videoKey), jsonEncode(layers.map((e) => e.settingsToJson()).toList()));
  }

  static Future<Map<String, Map<String, dynamic>>> load(String videoKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(videoKey));
    if (raw == null || raw.isEmpty) return const <String, Map<String, dynamic>>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return <String, Map<String, dynamic>>{
        for (final item in list)
          if (item is Map<String, dynamic> && item['id'] is String) item['id'] as String: item,
      };
    } catch (_) {
      return const <String, Map<String, dynamic>>{};
    }
  }
}
