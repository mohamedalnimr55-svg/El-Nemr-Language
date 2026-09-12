import 'package:el_nemr_language/discover/models/discovery_item.dart';
import 'package:el_nemr_language/discover/services/discovery_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes common two/three-letter and human language names', () {
    expect(normalizeDiscoveryLanguage('English'), 'en');
    expect(normalizeDiscoveryLanguage('eng'), 'en');
    expect(normalizeDiscoveryLanguage('Deutsch'), 'de');
    expect(normalizeDiscoveryLanguage('Japanese'), 'ja');
    expect(normalizeDiscoveryLanguage('kor'), 'ko');
  });

  test('discovery item target matching does not guess unknown languages', () {
    const unknown = DiscoveryItem(
      provider: DiscoveryProvider.wikimediaCommons,
      providerId: 'File:Example.webm',
      title: 'Example',
      category: DiscoveryCategory.education,
    );
    expect(unknown.matchesTarget('ko'), isFalse);
  });

  test('category labels cover the requested catalog surfaces', () {
    expect(DiscoveryCategory.movies.label, contains('Movies'));
    expect(DiscoveryCategory.series.label, contains('Series'));
    expect(DiscoveryCategory.sports.label, contains('Sports'));
    expect(DiscoveryCategory.documentaries.label, contains('Documentaries'));
  });
}
