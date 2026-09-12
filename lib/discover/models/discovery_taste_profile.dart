class DiscoveryTasteProfile {
  const DiscoveryTasteProfile({
    this.tagScores = const <String, int>{},
    this.itemRatings = const <String, int>{},
    this.playCounts = const <String, int>{},
  });

  final Map<String, int> tagScores;
  final Map<String, int> itemRatings;
  final Map<String, int> playCounts;

  int tagScore(String tag) => tagScores[_normalize(tag)] ?? 0;
  int itemRating(String itemKey) => itemRatings[itemKey] ?? 0;
  int playCount(String itemKey) => playCounts[itemKey] ?? 0;

  bool get hasTasteSignals =>
      tagScores.values.any((value) => value != 0) ||
      itemRatings.values.any((value) => value != 0) ||
      playCounts.isNotEmpty;

  List<String> get favoriteTags {
    final entries = tagScores.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) => entry.key).take(6).toList(growable: false);
  }

  DiscoveryTasteProfile withExplicitFavorites(Set<String> favorites) {
    final next = Map<String, int>.from(tagScores);
    const curated = <String>{
      'action',
      'animation',
      'comedy',
      'crime',
      'documentary',
      'drama',
      'family',
      'fantasy',
      'history',
      'horror',
      'music',
      'mystery',
      'romance',
      'science fiction',
      'sports',
      'thriller',
    };
    for (final tag in curated) {
      final normalized = _normalize(tag);
      final current = next[normalized] ?? 0;
      if (favorites.contains(normalized)) {
        next[normalized] = current < 4 ? 4 : current;
      } else if (current == 4) {
        next.remove(normalized);
      }
    }
    return DiscoveryTasteProfile(
      tagScores: next,
      itemRatings: itemRatings,
      playCounts: playCounts,
    );
  }

  DiscoveryTasteProfile rate({
    required String itemKey,
    required Iterable<String> tags,
    required bool liked,
  }) {
    final nextTags = Map<String, int>.from(tagScores);
    final delta = liked ? 2 : -2;
    for (final raw in tags) {
      final tag = _normalize(raw);
      if (tag.isEmpty) continue;
      nextTags[tag] = ((nextTags[tag] ?? 0) + delta).clamp(-8, 8).toInt();
    }
    final nextRatings = Map<String, int>.from(itemRatings)..[itemKey] = liked ? 1 : -1;
    return DiscoveryTasteProfile(
      tagScores: nextTags,
      itemRatings: nextRatings,
      playCounts: playCounts,
    );
  }

  DiscoveryTasteProfile recordPlay({
    required String itemKey,
    required Iterable<String> tags,
  }) {
    final nextCounts = Map<String, int>.from(playCounts);
    nextCounts[itemKey] = (nextCounts[itemKey] ?? 0) + 1;

    // Opening a title is only a weak positive signal. It should never outweigh
    // an explicit thumbs-down.
    final nextTags = Map<String, int>.from(tagScores);
    for (final raw in tags.take(3)) {
      final tag = _normalize(raw);
      if (tag.isEmpty) continue;
      final current = nextTags[tag] ?? 0;
      if (current >= 0 && current < 6) nextTags[tag] = current + 1;
    }
    return DiscoveryTasteProfile(
      tagScores: nextTags,
      itemRatings: itemRatings,
      playCounts: nextCounts,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'tagScores': tagScores,
        'itemRatings': itemRatings,
        'playCounts': playCounts,
      };

  factory DiscoveryTasteProfile.fromJson(Map<String, dynamic> json) {
    Map<String, int> ints(Object? raw) {
      if (raw is! Map) return const <String, int>{};
      return raw.map((key, value) => MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0));
    }

    return DiscoveryTasteProfile(
      tagScores: ints(json['tagScores']),
      itemRatings: ints(json['itemRatings']),
      playCounts: ints(json['playCounts']),
    );
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
