import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/video_item.dart';
import '../models/discovery_item.dart';
import 'discovery_language.dart';

class DiscoveryException implements Exception {
  const DiscoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DiscoveryService {
  DiscoveryService._();
  static final DiscoveryService instance = DiscoveryService._();

  final _archive = _InternetArchiveProvider();
  final _commons = _WikimediaCommonsProvider();
  final Map<String, _DiscoveryCacheEntry> _cache = <String, _DiscoveryCacheEntry>{};
  static const _cacheTtl = Duration(minutes: 12);

  void clearCache() => _cache.clear();

  Future<List<DiscoveryItem>> search({
    required String targetLanguage,
    required DiscoveryCategory category,
    String query = '',
    bool targetOnly = true,
    int limit = 24,
  }) async {
    final cacheKey = [
      targetLanguage.toLowerCase(),
      category.name,
      query.trim().toLowerCase(),
      targetOnly ? 'target' : 'all',
      '$limit',
    ].join('|');
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return cached.items;
    }

    Future<List<DiscoveryItem>> collect({
      required bool onlyTarget,
      required int requested,
    }) async {
      final perProvider = (requested / 2).ceil().clamp(4, 30).toInt();
      final futures = <Future<List<DiscoveryItem>>>[
        _archive.search(
          targetLanguage: targetLanguage,
          category: category,
          query: query,
          targetOnly: onlyTarget,
          limit: perProvider,
        ),
        _commons.search(
          targetLanguage: targetLanguage,
          category: category,
          query: query,
          targetOnly: onlyTarget,
          limit: perProvider,
        ),
      ];
      final settled = await Future.wait(
        futures.map((future) async {
          try {
            return await future;
          } catch (_) {
            return const <DiscoveryItem>[];
          }
        }),
      );
      return settled.expand((e) => e).toList(growable: false);
    }

    final all = <DiscoveryItem>[];
    if (targetOnly) {
      all.addAll(await collect(onlyTarget: true, requested: limit));
    } else {
      // Even in “All languages”, explicitly fetch the learning language first,
      // then merge a broad catalog behind it. This makes the selected learning
      // goal a ranking preference rather than a hard restriction.
      final batches = await Future.wait([
        collect(onlyTarget: true, requested: (limit / 2).ceil()),
        collect(onlyTarget: false, requested: limit),
      ]);
      all
        ..addAll(batches[0])
        ..addAll(batches[1]);
    }

    final deduped = <String, DiscoveryItem>{};
    for (final item in all) {
      deduped.putIfAbsent('${item.provider.name}:${item.providerId}', () => item);
    }
    final ranked = deduped.values.toList();
    ranked.sort((a, b) {
      final aMatch = a.matchesTarget(targetLanguage) ? 1 : 0;
      final bMatch = b.matchesTarget(targetLanguage) ? 1 : 0;
      if (aMatch != bMatch) return bMatch.compareTo(aMatch);
      return b.popularity.compareTo(a.popularity);
    });
    final result = ranked.take(limit).toList(growable: false);
    _cache[cacheKey] = _DiscoveryCacheEntry(DateTime.now(), result);
    return result;
  }

  Future<ResolvedDiscoveryMedia> resolve(DiscoveryItem item) async {
    switch (item.provider) {
      case DiscoveryProvider.internetArchive:
        return _archive.resolve(item);
      case DiscoveryProvider.wikimediaCommons:
        return _commons.resolve(item);
    }
  }
}

class _DiscoveryCacheEntry {
  const _DiscoveryCacheEntry(this.createdAt, this.items);
  final DateTime createdAt;
  final List<DiscoveryItem> items;
}

class _JsonHttpClient {
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'El-Nemr-Language/0.8');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw DiscoveryException('Source returned HTTP ${response.statusCode}.');
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const DiscoveryException('Unexpected source response.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

class _InternetArchiveProvider extends _JsonHttpClient {
  static const _fields = <String>[
    'identifier',
    'title',
    'description',
    'language',
    'creator',
    'date',
    'downloads',
    'licenseurl',
    'rights',
    'collection',
    'subject',
  ];

  Future<List<DiscoveryItem>> search({
    required String targetLanguage,
    required DiscoveryCategory category,
    required String query,
    required bool targetOnly,
    required int limit,
  }) async {
    final lang = discoveryLanguageFor(targetLanguage);
    final clauses = <String>['mediatype:movies'];
    if (targetOnly) {
      final languageClause = lang.archiveNames
          .map((name) => 'language:"${_escape(name)}"')
          .join(' OR ');
      clauses.add('($languageClause)');
    }
    final categoryClause = _categoryClause(category);
    if (categoryClause.isNotEmpty) clauses.add(categoryClause);
    final cleaned = _safeQuery(query);
    if (cleaned.isNotEmpty) {
      clauses.add('(title:($cleaned) OR subject:($cleaned) OR description:($cleaned))');
    }

    final params = <String>[
      'q=${Uri.encodeQueryComponent(clauses.join(' AND '))}',
      ..._fields.map((f) => 'fl%5B%5D=${Uri.encodeQueryComponent(f)}'),
      'sort%5B%5D=downloads+desc',
      'rows=${(limit * 4).clamp(10, 50)}',
      'page=1',
      'output=json',
    ];
    final uri = Uri.parse('https://archive.org/advancedsearch.php?${params.join('&')}');
    final json = await getJson(uri);
    final response = json['response'];
    if (response is! Map) return const [];
    final docs = response['docs'];
    if (docs is! List) return const [];
    final results = <DiscoveryItem>[];
    for (final raw in docs) {
      if (raw is! Map) continue;
      final doc = raw.cast<String, dynamic>();
      if (!_isOpenLicensed(doc)) continue;
      final id = _firstString(doc['identifier']);
      final title = _firstString(doc['title']);
      if (id.isEmpty || title.isEmpty) continue;
      if (_looksUnsafeText([
        title,
        _firstString(doc['subject']),
        _firstString(doc['description']),
      ].join(' '))) {
        continue;
      }
      final code = normalizeDiscoveryLanguage(doc['language']);
      if (targetOnly && code.isNotEmpty && code != targetLanguage) continue;
      final licenseUrl = _firstString(doc['licenseurl']);
      final rights = _firstString(doc['rights']);
      results.add(
        DiscoveryItem(
          provider: DiscoveryProvider.internetArchive,
          providerId: id,
          title: title,
          description: _plain(_firstString(doc['description'])),
          category: category,
          languageCode: code,
          languageLabel: code.isEmpty ? '' : discoveryLanguageFor(code).name,
          thumbnailUrl: 'https://archive.org/services/img/${Uri.encodeComponent(id)}',
          creator: _firstString(doc['creator']).nullIfEmpty,
          year: _year(_firstString(doc['date'])),
          licenseName: rights.isNotEmpty ? rights : _licenseLabel(licenseUrl),
          licenseUrl: licenseUrl.nullIfEmpty,
          popularity: _int(doc['downloads']),
          tags: _recommendationTags([
            title,
            _allStrings(doc['subject']).join(' '),
            _firstString(doc['description']),
            _allStrings(doc['collection']).join(' '),
          ].join(' ')),
          providerPageUrl: 'https://archive.org/details/${Uri.encodeComponent(id)}',
        ),
      );
      if (results.length >= limit) break;
    }
    return results;
  }

  Future<ResolvedDiscoveryMedia> resolve(DiscoveryItem item) async {
    final uri = Uri.parse('https://archive.org/metadata/${Uri.encodeComponent(item.providerId)}');
    final json = await getJson(uri);
    final metadata = json['metadata'];
    if (metadata is Map && !_isOpenLicensed(metadata.cast<String, dynamic>())) {
      throw const DiscoveryException('This item does not expose an open-use license.');
    }
    final files = json['files'];
    if (files is! List) throw const DiscoveryException('No playable files were found.');

    final videoFiles = <Map<String, dynamic>>[];
    final subtitles = <VideoExternalSub>[];
    for (final raw in files) {
      if (raw is! Map) continue;
      final file = raw.cast<String, dynamic>();
      final name = _firstString(file['name']);
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (_isSubtitle(lower)) {
        subtitles.add(
          VideoExternalSub(
            uri: _downloadUrl(item.providerId, name),
            label: _subtitleLabel(name),
            language: _languageFromFilename(name),
            mimeType: _subtitleMime(lower),
          ),
        );
      }
      if (_isPlayableVideo(lower)) videoFiles.add(file);
    }
    if (videoFiles.isEmpty) throw const DiscoveryException('No supported video stream was found.');
    videoFiles.sort((a, b) => _videoScore(b).compareTo(_videoScore(a)));
    final bestName = _firstString(videoFiles.first['name']);
    return ResolvedDiscoveryMedia(
      item: item,
      streamUrl: _downloadUrl(item.providerId, bestName),
      subtitles: subtitles.take(12).toList(growable: false),
    );
  }

  String _categoryClause(DiscoveryCategory category) => switch (category) {
        DiscoveryCategory.all => '',
        DiscoveryCategory.movies => '(subject:(film OR movie OR cinema) OR collection:feature_films)',
        DiscoveryCategory.series => '(subject:(television OR series OR episode OR tv))',
        DiscoveryCategory.sports => '(subject:(sports OR match OR football OR soccer OR basketball OR tennis OR baseball))',
        DiscoveryCategory.documentaries => '(subject:(documentary OR documentaries))',
        DiscoveryCategory.news => '(subject:(news OR "current affairs"))',
        DiscoveryCategory.kids => '(subject:(children OR kids OR animation OR cartoon))',
        DiscoveryCategory.education => '(subject:(education OR educational OR lecture OR learning))',
      };

  bool _isOpenLicensed(Map<String, dynamic> doc) {
    final license = _firstString(doc['licenseurl']).toLowerCase();
    final rights = _firstString(doc['rights']).toLowerCase();
    if (license.contains('creativecommons.org')) return true;
    if (license.contains('publicdomain')) return true;
    if (rights.contains('public domain')) return true;
    if (rights.contains('creative commons')) return true;
    if (rights.contains('cc0')) return true;
    return false;
  }

  String _downloadUrl(String id, String file) => Uri.https(
        'archive.org',
        '/download/$id/$file',
      ).toString();

  bool _isPlayableVideo(String name) =>
      name.endsWith('.mp4') || name.endsWith('.m4v') || name.endsWith('.webm') || name.endsWith('.ogv');

  bool _isSubtitle(String name) =>
      name.endsWith('.srt') || name.endsWith('.vtt') || name.endsWith('.ass') || name.endsWith('.ssa');

  int _videoScore(Map<String, dynamic> f) {
    final name = _firstString(f['name']).toLowerCase();
    final format = _firstString(f['format']).toLowerCase();
    var score = 0;
    if (name.endsWith('.mp4')) score += 100;
    if (format.contains('h.264') || format.contains('mpeg4')) score += 50;
    if (name.contains('512kb')) score -= 20;
    if (name.contains('sample') || name.contains('thumb')) score -= 200;
    final size = int.tryParse(_firstString(f['size'])) ?? 0;
    if (size > 5 * 1024 * 1024) score += 10;
    if (size > 4 * 1024 * 1024 * 1024) score -= 15;
    return score;
  }

  String _subtitleLabel(String filename) {
    final code = _languageFromFilename(filename);
    return code.isEmpty ? filename : '${discoveryLanguageFor(code).name} · $filename';
  }

  String _languageFromFilename(String filename) {
    final lower = filename.toLowerCase();
    for (final lang in discoveryLanguages.values) {
      final code = lang.code;
      final pattern = RegExp('(?:^|[._\\- ])${RegExp.escape(code)}(?:[._\\- ]|\$)');
      if (pattern.hasMatch(lower)) return code;
      if (lower.contains('.${lang.name.toLowerCase()}.')) return code;
    }
    return '';
  }

  String _subtitleMime(String lower) {
    if (lower.endsWith('.vtt')) return 'text/vtt';
    if (lower.endsWith('.ass') || lower.endsWith('.ssa')) return 'text/x-ssa';
    return 'application/x-subrip';
  }

  String _licenseLabel(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/by-sa/')) return 'CC BY-SA';
    if (lower.contains('/by/')) return 'CC BY';
    if (lower.contains('/by-nc/')) return 'CC BY-NC';
    if (lower.contains('zero') || lower.contains('cc0')) return 'CC0';
    if (lower.contains('publicdomain')) return 'Public Domain';
    return 'Open license';
  }

  String _safeQuery(String value) {
    final cleaned = value.replaceAll(RegExp(r'[+\-!(){}\[\]^"~*?:\\/]'), ' ').trim();
    return cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(8).join(' ');
  }

  String _escape(String value) => value.replaceAll('"', r'\"');
}

class _WikimediaCommonsProvider extends _JsonHttpClient {
  Future<List<DiscoveryItem>> search({
    required String targetLanguage,
    required DiscoveryCategory category,
    required String query,
    required bool targetOnly,
    required int limit,
  }) async {
    final lang = discoveryLanguageFor(targetLanguage);
    final terms = <String>[
      'filetype:video',
      if (targetOnly) lang.name,
      category.searchHint,
      if (query.trim().isNotEmpty) query.trim(),
    ].join(' ');
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'generator': 'search',
      'gsrsearch': terms,
      'gsrnamespace': '6',
      'gsrlimit': '$limit',
      'prop': 'imageinfo',
      'iiprop': 'url|mime|extmetadata',
      'iiurlwidth': '640',
      'iiextmetadatalanguage': 'en',
      'origin': '*',
    });
    final json = await getJson(uri);
    final queryObj = json['query'];
    if (queryObj is! Map) return const [];
    final pages = queryObj['pages'];
    if (pages is! List) return const [];
    final results = <DiscoveryItem>[];
    for (final raw in pages) {
      if (raw is! Map) continue;
      final page = raw.cast<String, dynamic>();
      final infos = page['imageinfo'];
      if (infos is! List || infos.isEmpty || infos.first is! Map) continue;
      final info = (infos.first as Map).cast<String, dynamic>();
      final mime = _firstString(info['mime']).toLowerCase();
      if (!mime.startsWith('video/')) continue;
      final metaRaw = info['extmetadata'];
      final meta = metaRaw is Map ? metaRaw.cast<String, dynamic>() : const <String, dynamic>{};
      final license = _metaValue(meta, 'LicenseShortName');
      final licenseUrl = _metaValue(meta, 'LicenseUrl');
      if (!_isOpenLicense(license, licenseUrl)) continue;
      final titleRaw = _firstString(page['title']);
      final title = titleRaw.replaceFirst(RegExp(r'^File:', caseSensitive: false), '').replaceAll('_', ' ');
      final direct = _firstString(info['url']);
      if (direct.isEmpty) continue;
      final detectedCode = _normalizeCommonsLanguage(_metaValue(meta, 'Language'));
      final description = _plain(_metaValue(meta, 'ImageDescription'));
      if (_looksUnsafeText('$title $description')) continue;
      results.add(
        DiscoveryItem(
          provider: DiscoveryProvider.wikimediaCommons,
          providerId: titleRaw,
          title: title,
          description: description,
          category: category,
          languageCode: detectedCode,
          languageLabel: detectedCode.isEmpty ? '' : discoveryLanguageFor(detectedCode).name,
          thumbnailUrl: _firstString(info['thumburl']).nullIfEmpty,
          creator: _plain(_metaValue(meta, 'Artist')).nullIfEmpty,
          year: _year(_metaValue(meta, 'DateTimeOriginal')),
          licenseName: license.isEmpty ? 'Open license' : license,
          licenseUrl: licenseUrl.nullIfEmpty,
          tags: _recommendationTags('$title $description ${_metaValue(meta, 'Categories')}'),
          directStreamUrl: direct,
          providerPageUrl: _firstString(info['descriptionurl']).nullIfEmpty,
        ),
      );
    }
    return results;
  }

  Future<ResolvedDiscoveryMedia> resolve(DiscoveryItem item) async {
    final url = item.directStreamUrl;
    if (url == null || url.isEmpty) throw const DiscoveryException('This media item has no direct stream URL.');
    return ResolvedDiscoveryMedia(item: item, streamUrl: url);
  }

  String _metaValue(Map<String, dynamic> meta, String key) {
    final raw = meta[key];
    if (raw is Map) return _firstString(raw['value']);
    return _firstString(raw);
  }

  bool _isOpenLicense(String name, String url) {
    final value = '$name $url'.toLowerCase();
    return value.contains('creative commons') ||
        value.contains('cc by') ||
        value.contains('cc0') ||
        value.contains('public domain') ||
        value.contains('creativecommons.org') ||
        value.contains('free art');
  }

  String _normalizeCommonsLanguage(String value) {
    final plain = _plain(value);
    return normalizeDiscoveryLanguage(plain);
  }
}

List<String> _allStrings(Object? value) {
  if (value == null) return const <String>[];
  if (value is List) {
    return value.map(_firstString).where((e) => e.isNotEmpty).toList(growable: false);
  }
  final single = _firstString(value);
  return single.isEmpty ? const <String>[] : <String>[single];
}

List<String> _recommendationTags(String value) {
  final lower = _plain(value).toLowerCase();
  final tags = <String>{};

  void add(String tag, List<String> clues) {
    if (clues.any(lower.contains)) tags.add(tag);
  }

  add('action', const ['action', 'adventure', 'martial art', 'war film']);
  add('animation', const ['animation', 'animated', 'cartoon', 'anime']);
  add('comedy', const ['comedy', 'comic', 'humor', 'humour', 'funny']);
  add('crime', const ['crime', 'gangster', 'mafia', 'detective', 'police']);
  add('documentary', const ['documentary', 'non-fiction', 'nonfiction']);
  add('drama', const ['drama', 'dramatic']);
  add('family', const ['family film', 'family movie', 'children', 'kids']);
  add('fantasy', const ['fantasy', 'fairy tale', 'mythical']);
  add('history', const ['history', 'historical', 'biography', 'biographical']);
  add('horror', const ['horror', 'monster', 'zombie', 'vampire', 'ghost']);
  add('music', const ['musical', 'music film', 'concert', 'opera']);
  add('mystery', const ['mystery', 'whodunit', 'suspense']);
  add('romance', const ['romance', 'romantic', 'love story']);
  add('science fiction', const ['science fiction', 'sci-fi', 'scifi', 'space opera']);
  add('sports', const ['sports', 'football', 'soccer', 'basketball', 'baseball', 'tennis', 'boxing']);
  add('thriller', const ['thriller', 'suspense', 'spy film', 'espionage']);

  return tags.take(8).toList(growable: false);
}

bool _looksUnsafeText(String value) {
  final lower = value.toLowerCase();
  const blocked = <String>[
    'porn',
    'pornographic',
    'xxx',
    'hardcore sex',
    'explicit sex',
    'sexual intercourse',
    'erotic nude',
    'adult film',
    'adult movie',
  ];
  return blocked.any(lower.contains);
}

String _firstString(Object? value) {
  if (value == null) return '';
  if (value is List) {
    if (value.isEmpty) return '';
    return _firstString(value.first);
  }
  if (value is Map && value.containsKey('value')) return _firstString(value['value']);
  return value.toString().trim();
}

int _int(Object? value) {
  if (value is int) return value;
  return int.tryParse(_firstString(value)) ?? 0;
}

String _year(String value) {
  final match = RegExp(r'\b(18|19|20)\d{2}\b').firstMatch(value);
  return match?.group(0) ?? '';
}

String _plain(String value) => value
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

extension _NullableString on String {
  String? get nullIfEmpty => trim().isEmpty ? null : trim();
}
