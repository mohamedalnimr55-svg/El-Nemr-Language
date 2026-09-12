import 'dart:math' as math;

import '../../learning/models/learner_profile.dart';
import '../models/discovery_item.dart';
import '../models/discovery_taste_profile.dart';
import 'discovery_language.dart';
import 'discovery_taste_store.dart';

class DiscoveryRecommendation {
  const DiscoveryRecommendation({
    required this.item,
    required this.score,
    required this.reason,
    required this.learningFit,
    required this.matchPercent,
    this.tasteMatches = const <String>[],
  });

  final DiscoveryItem item;
  final double score;
  final String reason;
  final String learningFit;
  final int matchPercent;
  final List<String> tasteMatches;
}

class DiscoveryRecommendationService {
  const DiscoveryRecommendationService._();
  static const instance = DiscoveryRecommendationService._();

  List<DiscoveryRecommendation> rank({
    required Iterable<DiscoveryItem> items,
    required LearnerProfile learner,
    required DiscoveryTasteProfile taste,
    int limit = 10,
  }) {
    final byTitle = <String, DiscoveryItem>{};
    for (final item in items) {
      if (item.category != DiscoveryCategory.movies && item.category != DiscoveryCategory.all) continue;
      final rating = taste.itemRating(DiscoveryTasteStore.itemKey(item));
      if (rating < 0) continue;
      final normalizedTitle = _normalizedTitle(item.title);
      if (normalizedTitle.isEmpty) continue;
      final previous = byTitle[normalizedTitle];
      if (previous == null || item.popularity > previous.popularity) {
        byTitle[normalizedTitle] = item;
      }
    }

    final scored = <DiscoveryRecommendation>[];
    for (final item in byTitle.values) {
      final key = DiscoveryTasteStore.itemKey(item);
      final languageMatch = item.matchesTarget(learner.targetLanguage);
      final matches = item.recommendationTags
          .where((tag) => taste.tagScore(tag) > 0)
          .toList(growable: false)
        ..sort((a, b) => taste.tagScore(b).compareTo(taste.tagScore(a)));

      var score = languageMatch ? 38.0 : (item.languageCode.isEmpty ? 3.0 : -8.0);
      if (taste.itemRating(key) > 0) score += 18;
      score -= math.min(10, taste.playCount(key) * 2).toDouble();

      var tasteScore = 0.0;
      for (final tag in item.recommendationTags.take(8)) {
        tasteScore += taste.tagScore(tag) * 4.2;
      }
      score += tasteScore.clamp(-42.0, 42.0);

      if (item.popularity > 0) {
        score += (math.log(item.popularity + 1) / math.ln10 * 3.2).clamp(0, 16).toDouble();
      }
      if (item.description.trim().isNotEmpty) score += 2;
      if (item.year?.isNotEmpty == true) score += 1;

      final learningFit = _learningFit(item, learner);
      if (learningFit == 'Excellent') score += 7;
      if (learningFit == 'Good') score += 3;

      final matchPercent = _matchPercent(score, languageMatch: languageMatch, hasTaste: taste.hasTasteSignals);
      scored.add(
        DiscoveryRecommendation(
          item: item,
          score: score,
          reason: _reason(
            item: item,
            learner: learner,
            taste: taste,
            matches: matches,
            languageMatch: languageMatch,
          ),
          learningFit: learningFit,
          matchPercent: matchPercent,
          tasteMatches: matches.take(3).toList(growable: false),
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList(growable: false);
  }

  String _learningFit(DiscoveryItem item, LearnerProfile learner) {
    if (!item.matchesTarget(learner.targetLanguage)) return 'Other language';
    final level = learner.level.toUpperCase();
    final tags = item.recommendationTags.toSet();
    if ((level == 'A1' || level == 'A2') &&
        (tags.contains('family') || tags.contains('animation') || tags.contains('kids'))) {
      return 'Excellent';
    }
    if ((level == 'B2' || level == 'C1' || level == 'C2') &&
        (tags.contains('documentary') || tags.contains('history') || tags.contains('news'))) {
      return 'Excellent';
    }
    return 'Good';
  }

  String _reason({
    required DiscoveryItem item,
    required LearnerProfile learner,
    required DiscoveryTasteProfile taste,
    required List<String> matches,
    required bool languageMatch,
  }) {
    final targetName = discoveryLanguageFor(learner.targetLanguage).name;
    final prettyMatches = matches.take(2).map(_prettyTag).toList(growable: false);
    if (prettyMatches.isNotEmpty && languageMatch) {
      return 'Because you like ${_join(prettyMatches)}, and it supports your $targetName learning goal.';
    }
    if (prettyMatches.isNotEmpty) {
      return 'Because you like ${_join(prettyMatches)}. It is outside your main learning language, so we keep it as an optional pick.';
    }
    if (languageMatch && taste.hasTasteSignals) {
      return 'A $targetName pick that fits your learning goal while El-Nemr Language keeps learning your movie taste.';
    }
    if (languageMatch) {
      return 'A popular $targetName title to start learning your taste. Use 👍 or 👎 to personalize the next picks.';
    }
    return 'An open movie you can explore without changing your ${discoveryLanguageFor(learner.targetLanguage).name} learning goal.';
  }

  int _matchPercent(double score, {required bool languageMatch, required bool hasTaste}) {
    var value = 58 + (score / 3.5).round();
    if (languageMatch) value += 7;
    if (!hasTaste) value = value.clamp(68, 86).toInt();
    return value.clamp(52, 99).toInt();
  }

  String _normalizedTitle(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u0400-\u04ff\u0600-\u06ff\u3040-\u30ff\u3400-\u9fff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _prettyTag(String value) => value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _join(List<String> values) {
    if (values.length <= 1) return values.isEmpty ? 'this kind of movie' : values.first;
    return '${values.first} & ${values[1]}';
  }
}
