import '../../services/tmdb_client.dart';

enum LocalContentKind { movieOrVideo, seriesEpisode }

class LocalContentIdentity {
  const LocalContentIdentity({
    required this.title,
    required this.kind,
    this.year,
    this.season,
    this.episode,
    this.audioLanguage,
  });

  final String title;
  final LocalContentKind kind;
  final int? year;
  final int? season;
  final int? episode;
  final String? audioLanguage;

  String get typeLabel => kind == LocalContentKind.seriesEpisode
      ? 'Series episode'
      : 'Movie / video';

  String get episodeLabel {
    if (season == null || episode == null) return '';
    return 'S${season!.toString().padLeft(2, '0')}E${episode!.toString().padLeft(2, '0')}';
  }

  String get summary {
    final parts = <String>[typeLabel];
    if (title.trim().isNotEmpty) parts.add(title.trim());
    if (episodeLabel.isNotEmpty) parts.add(episodeLabel);
    if (year != null) parts.add('$year');
    final lang = audioLanguage?.trim();
    if (lang != null && lang.isNotEmpty && lang != 'und') {
      parts.add('audio ${lang.toUpperCase()}');
    }
    return parts.join(' · ');
  }
}

/// Best-effort, fully local media identity.
///
/// This deliberately does not claim acoustic fingerprint matching. It extracts
/// title / series / season / episode hints from the filename and combines them
/// with the language detected from the actual soundtrack. Exact commercial
/// movie matching can be enhanced later by an optional metadata provider.
class ContentIdentityService {
  const ContentIdentityService._();

  static LocalContentIdentity detect({
    required String fileName,
    String? audioLanguage,
    String? parentFolderName,
  }) {
    final parsed = ParsedFileName.parse(
      fileName,
      parentFolderName: parentFolderName,
    );
    final title = (parsed.isEpisode ? parsed.seriesName : parsed.title)?.trim();
    return LocalContentIdentity(
      title: (title == null || title.isEmpty) ? fileName.trim() : title,
      kind: parsed.isEpisode
          ? LocalContentKind.seriesEpisode
          : LocalContentKind.movieOrVideo,
      year: parsed.year,
      season: parsed.isEpisode && parsed.season > 0 ? parsed.season : null,
      episode: parsed.isEpisode && parsed.episode > 0 ? parsed.episode : null,
      audioLanguage: audioLanguage?.trim().toLowerCase(),
    );
  }
}
