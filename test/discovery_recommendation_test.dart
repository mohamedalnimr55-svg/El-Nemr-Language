import 'package:flutter_test/flutter_test.dart';

import 'package:el_nemr_language/discover/models/discovery_item.dart';
import 'package:el_nemr_language/discover/models/discovery_taste_profile.dart';
import 'package:el_nemr_language/discover/services/discovery_recommendation_service.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';

void main() {
  const service = DiscoveryRecommendationService.instance;

  DiscoveryItem movie(String id, String title, String language, List<String> tags, {int popularity = 100}) {
    return DiscoveryItem(
      provider: DiscoveryProvider.internetArchive,
      providerId: id,
      title: title,
      category: DiscoveryCategory.movies,
      languageCode: language,
      languageLabel: language,
      tags: tags,
      popularity: popularity,
      licenseName: 'Public Domain',
    );
  }

  test('learning language stays a strong recommendation signal', () {
    final ranked = service.rank(
      items: [
        movie('de', 'German Drama', 'de', const ['drama']),
        movie('ja', 'Japanese Drama', 'ja', const ['drama'], popularity: 999999),
      ],
      learner: const LearnerProfile(targetLanguage: 'de'),
      taste: const DiscoveryTasteProfile(),
    );

    expect(ranked.first.item.providerId, 'de');
  });

  test('taste affinity reranks same-language titles', () {
    final ranked = service.rank(
      items: [
        movie('crime', 'Crime Pick', 'en', const ['crime']),
        movie('romance', 'Romance Pick', 'en', const ['romance'], popularity: 200),
      ],
      learner: const LearnerProfile(targetLanguage: 'en'),
      taste: const DiscoveryTasteProfile(tagScores: {'crime': 6, 'romance': -2}),
    );

    expect(ranked.first.item.providerId, 'crime');
    expect(ranked.first.reason.toLowerCase(), contains('crime'));
  });

  test('explicitly disliked titles are removed', () {
    final ranked = service.rank(
      items: [movie('nope', 'Nope', 'en', const ['action'])],
      learner: const LearnerProfile(targetLanguage: 'en'),
      taste: const DiscoveryTasteProfile(itemRatings: {'internetArchive:nope': -1}),
    );

    expect(ranked, isEmpty);
  });
}
