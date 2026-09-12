import 'package:flutter_test/flutter_test.dart';

import 'package:el_nemr_language/learning/services/content_identity_service.dart';

void main() {
  test('detects a series episode and keeps the soundtrack language', () {
    final identity = ContentIdentityService.detect(
      fileName: 'Dark.S02E04.1080p.WEB-DL.mkv',
      audioLanguage: 'de',
    );

    expect(identity.kind, LocalContentKind.seriesEpisode);
    expect(identity.title.toLowerCase(), contains('dark'));
    expect(identity.season, 2);
    expect(identity.episode, 4);
    expect(identity.summary, contains('S02E04'));
    expect(identity.summary, contains('audio DE'));
  });

  test('does not pretend a regular filename is acoustic fingerprinted', () {
    final identity = ContentIdentityService.detect(
      fileName: 'My.Movie.2024.1080p.mkv',
      audioLanguage: 'ja',
    );

    expect(identity.kind, LocalContentKind.movieOrVideo);
    expect(identity.year, 2024);
    expect(identity.summary, contains('Movie / video'));
    expect(identity.summary, contains('audio JA'));
  });
}
