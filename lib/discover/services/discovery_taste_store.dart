import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/discovery_item.dart';
import '../models/discovery_taste_profile.dart';

class DiscoveryTasteStore {
  const DiscoveryTasteStore._();

  static const _key = 'discover.taste.v1';

  static Future<DiscoveryTasteProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const DiscoveryTasteProfile();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return DiscoveryTasteProfile.fromJson(decoded);
      if (decoded is Map) return DiscoveryTasteProfile.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return const DiscoveryTasteProfile();
  }

  static Future<void> save(DiscoveryTasteProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  static String itemKey(DiscoveryItem item) => '${item.provider.name}:${item.providerId}';

  static Future<DiscoveryTasteProfile> rate(
    DiscoveryTasteProfile current,
    DiscoveryItem item, {
    required bool liked,
  }) async {
    final next = current.rate(
      itemKey: itemKey(item),
      tags: item.recommendationTags,
      liked: liked,
    );
    await save(next);
    return next;
  }

  static Future<DiscoveryTasteProfile> recordPlay(
    DiscoveryTasteProfile current,
    DiscoveryItem item,
  ) async {
    final next = current.recordPlay(
      itemKey: itemKey(item),
      tags: item.recommendationTags,
    );
    await save(next);
    return next;
  }
}
