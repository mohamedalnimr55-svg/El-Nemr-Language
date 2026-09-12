import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../discover/models/discovery_item.dart';
import '../discover/models/discovery_taste_profile.dart';
import '../discover/services/discovery_language.dart';
import '../discover/services/discovery_recommendation_service.dart';
import '../discover/services/discovery_service.dart';
import '../discover/services/discovery_taste_store.dart';
import '../learning/models/learner_profile.dart';
import '../learning/services/learner_profile_store.dart';
import 'player_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.refreshTick});

  final Listenable? refreshTick;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  static const _homeCategories = <DiscoveryCategory>[
    DiscoveryCategory.movies,
    DiscoveryCategory.series,
    DiscoveryCategory.sports,
    DiscoveryCategory.documentaries,
    DiscoveryCategory.education,
    DiscoveryCategory.kids,
    DiscoveryCategory.news,
  ];

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _service = DiscoveryService.instance;
  LearnerProfile _profile = const LearnerProfile();
  DiscoveryTasteProfile _taste = const DiscoveryTasteProfile();
  List<DiscoveryItem> _recommendationCandidates = const [];
  List<DiscoveryRecommendation> _recommendations = const [];
  bool _targetOnly = true;
  bool _loading = true;
  String? _error;
  String? _openingId;
  Timer? _debounce;
  Map<DiscoveryCategory, List<DiscoveryItem>> _sections = const {};
  List<DiscoveryItem> _otherLanguages = const [];
  List<DiscoveryItem> _searchResults = const [];
  DiscoveryCategory _searchCategory = DiscoveryCategory.all;
  int _loadGeneration = 0;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    widget.refreshTick?.addListener(_refreshProfile);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.refreshTick?.removeListener(_refreshProfile);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final profile = await LearnerProfileStore.load();
    if (!mounted) return;
    final changed = profile.targetLanguage != _profile.targetLanguage ||
        profile.nativeLanguage != _profile.nativeLanguage ||
        profile.level != _profile.level;
    _profile = profile;
    if (!changed) return;
    if (_isSearching) {
      await _runSearch();
    } else {
      await _loadHome();
    }
  }

  Future<void> _load() async {
    final profile = await LearnerProfileStore.load();
    final taste = await DiscoveryTasteStore.load();
    if (!mounted) return;
    _profile = profile;
    _taste = taste;
    await _loadHome();
  }

  Future<void> _loadHome({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    if (forceRefresh) _service.clearCache();
    setState(() {
      _loading = true;
      _error = null;
      _searchResults = const [];
      if (!forceRefresh) {
        _sections = const {};
        _otherLanguages = const [];
        _recommendationCandidates = const [];
        _recommendations = const [];
      }
    });

    var successes = 0;
    final errors = <Object>[];
    final jobs = _homeCategories.map((category) async {
      try {
        final items = await _service.search(
          targetLanguage: _profile.targetLanguage,
          category: category,
          targetOnly: _targetOnly,
          limit: 18,
        );
        if (!mounted || generation != _loadGeneration) return;
        successes++;
        setState(() {
          _sections = {..._sections, category: items};
        });
      } catch (e) {
        errors.add(e);
      }
    }).toList(growable: false);

    final Future<void> otherLanguagesJob = _targetOnly
        ? (() async {
            try {
              final all = await _service.search(
                targetLanguage: _profile.targetLanguage,
                category: DiscoveryCategory.all,
                targetOnly: false,
                limit: 30,
              );
              if (!mounted || generation != _loadGeneration) return;
              final target = _profile.targetLanguage.toLowerCase();
              final knownOther = all
                  .where((item) => item.languageCode.isNotEmpty && item.languageCode.toLowerCase() != target)
                  .toList(growable: false);
              final unknown = all.where((item) => item.languageCode.isEmpty).toList(growable: false);
              setState(() {
                _otherLanguages = [...knownOther, ...unknown].take(18).toList(growable: false);
              });
            } catch (_) {}
          })()
        : Future<void>.value();

    final Future<void> recommendationJob = (() async {
      try {
        final candidates = await _service.search(
          targetLanguage: _profile.targetLanguage,
          category: DiscoveryCategory.movies,
          targetOnly: false,
          limit: 60,
        );
        if (!mounted || generation != _loadGeneration) return;
        final recommendations = DiscoveryRecommendationService.instance.rank(
          items: candidates,
          learner: _profile,
          taste: _taste,
          limit: 10,
        );
        setState(() {
          _recommendationCandidates = candidates;
          _recommendations = recommendations;
        });
      } catch (_) {}
    })();

    await Future.wait([...jobs, otherLanguagesJob, recommendationJob]);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _loading = false;
      if (successes == 0 && errors.isNotEmpty) {
        _error = errors.first.toString();
      }
    });
  }

  Future<void> _refreshCurrent() async {
    _service.clearCache();
    if (_isSearching) {
      await _runSearch();
    } else {
      await _loadHome(forceRefresh: true);
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = const []);
      unawaited(_loadHome());
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 450), _runSearch);
  }

  Future<void> _runSearch() async {
    _loadGeneration++;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.search(
        targetLanguage: _profile.targetLanguage,
        category: _searchCategory,
        query: query,
        targetOnly: _targetOnly,
        limit: 40,
      );
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() {
        _searchResults = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setTargetOnly(bool value) async {
    if (_targetOnly == value) return;
    setState(() => _targetOnly = value);
    if (_isSearching) {
      await _runSearch();
    } else {
      await _loadHome();
    }
  }

  Future<void> _setSearchCategory(DiscoveryCategory category) async {
    if (_searchCategory == category) return;
    setState(() => _searchCategory = category);
    if (_isSearching) await _runSearch();
  }

  void _rerankRecommendations() {
    if (_recommendationCandidates.isEmpty) return;
    _recommendations = DiscoveryRecommendationService.instance.rank(
      items: _recommendationCandidates,
      learner: _profile,
      taste: _taste,
      limit: 10,
    );
  }

  Future<void> _rateTitle(DiscoveryItem item, {required bool liked}) async {
    final next = await DiscoveryTasteStore.rate(_taste, item, liked: liked);
    if (!mounted) return;
    setState(() {
      _taste = next;
      _rerankRecommendations();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(liked ? 'Got it — more movies like this.' : 'Got it — fewer movies like this.'),
      ),
    );
  }

  Future<void> _showTastePreferences() async {
    const genres = <String, String>{
      'action': 'Action',
      'animation': 'Animation',
      'comedy': 'Comedy',
      'crime': 'Crime',
      'documentary': 'Documentary',
      'drama': 'Drama',
      'family': 'Family',
      'fantasy': 'Fantasy',
      'history': 'History',
      'horror': 'Horror',
      'music': 'Music',
      'mystery': 'Mystery',
      'romance': 'Romance',
      'science fiction': 'Sci-Fi',
      'sports': 'Sports',
      'thriller': 'Thriller',
    };
    final selected = _taste.favoriteTags.toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tune your movie taste', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Pick what you usually enjoy. El-Nemr Language also learns from 👍, 👎, and what you choose to watch.'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: genres.entries.map((entry) {
                    final active = selected.contains(entry.key);
                    return FilterChip(
                      selected: active,
                      label: Text(entry.value),
                      avatar: active ? const Icon(Icons.favorite_rounded, size: 17) : null,
                      onSelected: (value) {
                        setSheetState(() {
                          if (value) {
                            selected.add(entry.key);
                          } else {
                            selected.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(selected),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Personalize my picks'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    final next = _taste.withExplicitFavorites(result);
    await DiscoveryTasteStore.save(next);
    if (!mounted) return;
    setState(() {
      _taste = next;
      _rerankRecommendations();
    });
  }

  Future<bool> _confirmLanguageMismatch(DiscoveryItem item) async {
    final code = item.languageCode;
    if (code.isEmpty || code == _profile.targetLanguage) return true;
    final contentLang = discoveryLanguageFor(code).name;
    final targetLang = discoveryLanguageFor(_profile.targetLanguage).name;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.translate_rounded),
        title: const Text('Different spoken language'),
        content: Text(
          'You are learning $targetLang, but this video appears to be in '
          '$contentLang.\n\nYou can still watch it normally. El-Nemr Language will '
          'keep your $targetLang learning goal and can analyse the video language '
          'separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showInfo(DiscoveryItem item) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: Icons.public_rounded, text: item.providerLabel),
                  if (item.languageLabel.isNotEmpty)
                    _InfoPill(icon: Icons.translate_rounded, text: item.languageLabel),
                  if (item.year != null && item.year!.isNotEmpty)
                    _InfoPill(icon: Icons.calendar_today_outlined, text: item.year!),
                ],
              ),
              if (item.creator != null && item.creator!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Creator', style: theme.textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(item.creator!),
              ],
              const SizedBox(height: 14),
              Text('License', style: theme.textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(item.licenseName.isEmpty ? 'Open/free license metadata supplied by the source' : item.licenseName),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('About', style: theme.textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(item.description),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (item.providerPageUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => _openExternal(item.providerPageUrl!),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Source page'),
                    ),
                  if (item.licenseUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => _openExternal(item.licenseUrl!),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('License'),
                    ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_open(item));
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _open(DiscoveryItem item) async {
    if (_openingId != null) return;
    if (!await _confirmLanguageMismatch(item)) return;
    final updatedTaste = await DiscoveryTasteStore.recordPlay(_taste, item);
    if (!mounted) return;
    setState(() {
      _taste = updatedTaste;
      _rerankRecommendations();
      _openingId = item.providerId;
    });
    try {
      final resolved = await _service.resolve(item);
      if (!mounted) return;
      setState(() => _openingId = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(video: resolved.toVideoItem()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final target = discoveryLanguageFor(_profile.targetLanguage);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refreshCurrent,
      child: CustomScrollView(
        key: const PageStorageKey('discover-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discover'),
                Text(
                  'Learn ${target.name} with real video',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Tune recommendations',
                onPressed: _showTastePreferences,
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () => _searchFocus.requestFocus(),
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refreshCurrent,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildSearchAndFilters(target)),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _ErrorCard(message: _error!, onRetry: _isSearching ? _runSearch : _loadHome),
              ),
            ),
          if (_loading && !_isSearching)
            SliverToBoxAdapter(
              child: _sections.isEmpty
                  ? const _DiscoverLoading()
                  : const LinearProgressIndicator(minHeight: 2),
            ),
          if (_isSearching)
            ..._buildSearchSlivers()
          else
            ..._buildHomeSlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(DiscoveryLanguage target) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'Search movies, series, sports, documentaries…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _isSearching
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchFocus.unfocus();
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.school_rounded, size: 18),
                  label: Text('${target.name} first'),
                  selected: _targetOnly,
                  onSelected: (_) => _setTargetOnly(true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.public_rounded, size: 18),
                  label: const Text('All languages'),
                  selected: !_targetOnly,
                  onSelected: (_) => _setTargetOnly(false),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Free & open sources', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: DiscoveryCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.label),
                      selected: _searchCategory == category,
                      onSelected: (_) => _setSearchCategory(category),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildHomeSlivers() {
    final featured = _sections[DiscoveryCategory.movies] ?? const [];
    final hero = featured.isNotEmpty
        ? featured.first
        : (_recommendations.isNotEmpty ? _recommendations.first.item : null);
    final recommendationRows = hero == null
        ? _recommendations
        : _recommendations
            .where((recommendation) =>
                !(recommendation.item.provider == hero.provider && recommendation.item.providerId == hero.providerId))
            .toList(growable: false);
    final widgets = <Widget>[];
    if (recommendationRows.isNotEmpty) {
      widgets.add(
        SliverToBoxAdapter(
          child: _RecommendationSection(
            recommendations: recommendationRows,
            learner: _profile,
            taste: _taste,
            openingId: _openingId,
            onPlay: _open,
            onInfo: _showInfo,
            onLike: (item) => _rateTitle(item, liked: true),
            onDislike: (item) => _rateTitle(item, liked: false),
            onTuneTaste: _showTastePreferences,
          ),
        ),
      );
    }
    if (hero != null) {
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: _DiscoverHero(
              item: hero,
              busy: _openingId == hero.providerId,
              onPlay: () => _open(hero),
              onInfo: () => _showInfo(hero),
            ),
          ),
        ),
      );
    }
    for (final category in _homeCategories) {
      final items = _sections[category] ?? const [];
      if (items.isEmpty) continue;
      final rowItems = hero != null && category == DiscoveryCategory.movies
          ? items
              .where((item) => !(item.provider == hero.provider && item.providerId == hero.providerId))
              .toList(growable: false)
          : items;
      if (rowItems.isEmpty) continue;
      widgets.add(
        SliverToBoxAdapter(
          child: _DiscoverSection(
            category: category,
            items: rowItems,
            targetLanguage: _profile.targetLanguage,
            openingId: _openingId,
            onTap: _open,
            onInfo: _showInfo,
          ),
        ),
      );
    }
    if (_targetOnly && _otherLanguages.isNotEmpty) {
      widgets.add(
        SliverToBoxAdapter(
          child: _DiscoverSection(
            category: DiscoveryCategory.all,
            title: 'Explore other languages',
            items: _otherLanguages,
            targetLanguage: _profile.targetLanguage,
            openingId: _openingId,
            onTap: _open,
            onInfo: _showInfo,
          ),
        ),
      );
    }
    if (!_loading && widgets.isEmpty && _error == null) {
      widgets.add(
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyDiscover(message: 'No open videos found for this language yet.'),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildSearchSlivers() {
    if (_loading) {
      return const [SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2))];
    }
    if (_searchResults.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyDiscover(
            message: 'No open videos matched. Try another category or “All languages”.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        sliver: SliverGrid.builder(
          itemCount: _searchResults.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 230,
            mainAxisExtent: 300,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            return _DiscoveryCard(
              item: item,
              targetLanguage: _profile.targetLanguage,
              busy: _openingId == item.providerId,
              onTap: () => _open(item),
              onInfo: () => _showInfo(item),
            );
          },
        ),
      ),
    ];
  }
}


class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.recommendations,
    required this.learner,
    required this.taste,
    required this.openingId,
    required this.onPlay,
    required this.onInfo,
    required this.onLike,
    required this.onDislike,
    required this.onTuneTaste,
  });

  final List<DiscoveryRecommendation> recommendations;
  final LearnerProfile learner;
  final DiscoveryTasteProfile taste;
  final String? openingId;
  final ValueChanged<DiscoveryItem> onPlay;
  final ValueChanged<DiscoveryItem> onInfo;
  final ValueChanged<DiscoveryItem> onLike;
  final ValueChanged<DiscoveryItem> onDislike;
  final VoidCallback onTuneTaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = discoveryLanguageFor(learner.targetLanguage).name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.onPrimaryContainer, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI picks for you', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text(
                        taste.hasTasteSignals
                            ? 'Your movie taste + $language learning goal'
                            : 'Start with $language, then teach El-Nemr Language what you enjoy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onTuneTaste,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(taste.hasTasteSignals ? 'Taste' : 'Choose taste'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 392,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final recommendation = recommendations[index];
                return SizedBox(
                  width: 286,
                  child: _RecommendationCard(
                    recommendation: recommendation,
                    rating: taste.itemRating(DiscoveryTasteStore.itemKey(recommendation.item)),
                    busy: openingId == recommendation.item.providerId,
                    onPlay: () => onPlay(recommendation.item),
                    onInfo: () => onInfo(recommendation.item),
                    onLike: () => onLike(recommendation.item),
                    onDislike: () => onDislike(recommendation.item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.rating,
    required this.busy,
    required this.onPlay,
    required this.onInfo,
    required this.onLike,
    required this.onDislike,
  });

  final DiscoveryRecommendation recommendation;
  final int rating;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = recommendation.item;
    final meta = <String>[
      if (item.languageLabel.isNotEmpty) item.languageLabel,
      if (item.year?.isNotEmpty == true) item.year!,
      if (item.recommendationTags.isNotEmpty) _prettyDiscoveryTag(item.recommendationTags.first),
    ];
    final summary = item.description.trim().isNotEmpty
        ? item.description.trim()
        : 'An open ${item.recommendationTags.isEmpty ? 'movie' : _prettyDiscoveryTag(item.recommendationTags.first).toLowerCase()} title${item.languageLabel.isEmpty ? '' : ' in ${item.languageLabel}'}.';
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPlay,
        onLongPress: onInfo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 154,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Poster(url: item.thumbnailUrl, icon: Icons.movie_creation_outlined),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xAA000000)],
                        stops: [.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: _MiniBadge(text: '${recommendation.matchPercent}% match'),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: _MiniBadge(text: recommendation.learningFit),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 9,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.black.withValues(alpha: .72),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
              ),
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
                child: Text(
                  meta.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 0),
              child: Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 15, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      recommendation.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 8, 9),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 19),
                      label: const Text('Watch'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More like this',
                    onPressed: onLike,
                    icon: Icon(rating > 0 ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Not for me',
                    onPressed: onDislike,
                    icon: Icon(rating < 0 ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
                  ),
                  IconButton(
                    tooltip: 'Movie info',
                    onPressed: onInfo,
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _prettyDiscoveryTag(String value) => value
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.item, required this.busy, required this.onPlay, required this.onInfo});
  final DiscoveryItem item;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 16 / 8.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Poster(url: item.thumbnailUrl, icon: Icons.movie_creation_outlined),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF2111115)],
                  stops: [.25, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _MiniBadge(text: item.languageLabel.isEmpty ? 'Video' : item.languageLabel),
                      _MiniBadge(text: item.licenseName.isEmpty ? 'Open' : item.licenseName),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onPlay,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(busy ? 'Opening…' : 'Play & learn'),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Source details',
                        onPressed: onInfo,
                        icon: const Icon(Icons.info_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverSection extends StatelessWidget {
  const _DiscoverSection({
    required this.category,
    this.title,
    required this.items,
    required this.targetLanguage,
    required this.openingId,
    required this.onTap,
    required this.onInfo,
  });
  final DiscoveryCategory category;
  final String? title;
  final List<DiscoveryItem> items;
  final String targetLanguage;
  final String? openingId;
  final ValueChanged<DiscoveryItem> onTap;
  final ValueChanged<DiscoveryItem> onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title ?? category.label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 270,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return SizedBox(
                  width: 168,
                  child: _DiscoveryCard(
                    item: item,
                    targetLanguage: targetLanguage,
                    busy: openingId == item.providerId,
                    onTap: () => onTap(item),
                    onInfo: () => onInfo(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.item,
    required this.targetLanguage,
    required this.busy,
    required this.onTap,
    required this.onInfo,
  });
  final DiscoveryItem item;
  final String targetLanguage;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mismatch = item.languageCode.isNotEmpty && item.languageCode != targetLanguage;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        onLongPress: onInfo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Poster(url: item.thumbnailUrl, icon: Icons.ondemand_video_rounded),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _MiniBadge(
                      text: mismatch
                          ? '${item.languageLabel.isEmpty ? item.languageCode.toUpperCase() : item.languageLabel} · other'
                          : (item.languageLabel.isEmpty ? 'Open video' : item.languageLabel),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.black.withValues(alpha: .72),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 4),
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
              child: Row(
                children: [
                  Icon(
                    item.provider == DiscoveryProvider.internetArchive
                        ? Icons.inventory_2_outlined
                        : Icons.public_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.licenseName.isEmpty
                          ? item.providerLabel
                          : '${item.providerLabel} · ${item.licenseName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkResponse(
                    onTap: onInfo,
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(Icons.info_outline_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.icon});
  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = url;
    if (value == null || value.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(icon, size: 46, color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(icon, size: 46, color: theme.colorScheme.onSurfaceVariant)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: theme.textTheme.labelMedium)),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DiscoverLoading extends StatelessWidget {
  const _DiscoverLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        children: [
          LinearProgressIndicator(minHeight: 2),
          SizedBox(height: 18),
          Text('Finding free open videos for your learning language…'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Discovery source unavailable.\n$message', maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
