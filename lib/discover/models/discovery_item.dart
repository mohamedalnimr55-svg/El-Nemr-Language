import '../../models/video_item.dart';

enum DiscoveryProvider { internetArchive, wikimediaCommons }

enum DiscoveryCategory {
  all,
  movies,
  series,
  sports,
  documentaries,
  news,
  kids,
  education,
}

extension DiscoveryCategoryInfo on DiscoveryCategory {
  String get label => switch (this) {
        DiscoveryCategory.all => 'All',
        DiscoveryCategory.movies => 'Movies',
        DiscoveryCategory.series => 'Series & TV',
        DiscoveryCategory.sports => 'Sports & matches',
        DiscoveryCategory.documentaries => 'Documentaries',
        DiscoveryCategory.news => 'News',
        DiscoveryCategory.kids => 'Kids',
        DiscoveryCategory.education => 'Learning',
      };

  String get searchHint => switch (this) {
        DiscoveryCategory.all => '',
        DiscoveryCategory.movies => 'film movie cinema',
        DiscoveryCategory.series => 'television series episode',
        DiscoveryCategory.sports => 'sports match football soccer basketball tennis',
        DiscoveryCategory.documentaries => 'documentary',
        DiscoveryCategory.news => 'news current affairs',
        DiscoveryCategory.kids => 'children kids animation cartoon',
        DiscoveryCategory.education => 'education educational lecture',
      };
}

class DiscoveryItem {
  const DiscoveryItem({
    required this.provider,
    required this.providerId,
    required this.title,
    required this.category,
    this.description = '',
    this.languageCode = '',
    this.languageLabel = '',
    this.thumbnailUrl,
    this.creator,
    this.year,
    this.licenseName = '',
    this.licenseUrl,
    this.popularity = 0,
    this.tags = const <String>[],
    this.directStreamUrl,
    this.providerPageUrl,
  });

  final DiscoveryProvider provider;
  final String providerId;
  final String title;
  final String description;
  final DiscoveryCategory category;
  final String languageCode;
  final String languageLabel;
  final String? thumbnailUrl;
  final String? creator;
  final String? year;
  final String licenseName;
  final String? licenseUrl;
  final int popularity;
  final List<String> tags;

  List<String> get recommendationTags {
    final values = <String>{
      ...tags.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      if (category == DiscoveryCategory.documentaries) 'documentary',
      if (category == DiscoveryCategory.sports) 'sports',
      if (category == DiscoveryCategory.kids) 'kids',
      if (category == DiscoveryCategory.education) 'education',
      if (category == DiscoveryCategory.news) 'news',
    };
    return values.toList(growable: false);
  }

  /// Some providers (Commons) expose a media URL in the search response.
  final String? directStreamUrl;
  final String? providerPageUrl;

  bool matchesTarget(String target) =>
      languageCode.isNotEmpty && languageCode.toLowerCase() == target.toLowerCase();

  String get providerLabel => switch (provider) {
        DiscoveryProvider.internetArchive => 'Internet Archive',
        DiscoveryProvider.wikimediaCommons => 'Wikimedia Commons',
      };
}

class ResolvedDiscoveryMedia {
  const ResolvedDiscoveryMedia({
    required this.item,
    required this.streamUrl,
    this.duration = Duration.zero,
    this.subtitles = const [],
  });

  final DiscoveryItem item;
  final String streamUrl;
  final Duration duration;
  final List<VideoExternalSub> subtitles;

  VideoItem toVideoItem() => VideoItem(
        id: 'discover:${item.provider.name}:${item.providerId}',
        title: item.title,
        uri: streamUrl,
        resumeKey: 'discover:${item.provider.name}:${item.providerId}',
        duration: duration,
        externalSubtitles: promoteFirstExternalAsDefault(subtitles),
        audioLanguage: item.languageCode.isEmpty ? null : item.languageCode,
      );
}
