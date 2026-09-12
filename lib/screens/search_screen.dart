import 'dart:async';

import 'package:flutter/material.dart';

import '../discover/models/discovery_item.dart';
import '../discover/services/discovery_language.dart';
import '../discover/services/discovery_service.dart';
import '../learning/models/learner_profile.dart';
import '../learning/services/learner_profile_store.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.refreshTick});

  final Listenable? refreshTick;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _service = DiscoveryService.instance;
  Timer? _debounce;
  LearnerProfile _profile = const LearnerProfile();
  DiscoveryCategory _category = DiscoveryCategory.all;
  List<DiscoveryItem> _results = const [];
  bool _loading = false;
  String? _error;
  String? _openingId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.refreshTick?.addListener(_reloadProfile);
    _controller.addListener(_onChanged);
    _reloadProfile();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.refreshTick?.removeListener(_reloadProfile);
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadProfile() async {
    final profile = await LearnerProfileStore.load();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 380), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.search(
        targetLanguage: _profile.targetLanguage,
        category: _category,
        query: query,
        targetOnly: false,
        limit: 50,
      );
      if (!mounted || query != _controller.text.trim()) return;
      setState(() {
        _results = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<bool> _confirmMismatch(DiscoveryItem item) async {
    if (item.languageCode.isEmpty ||
        item.languageCode.toLowerCase() == _profile.targetLanguage.toLowerCase()) {
      return true;
    }
    final content = discoveryLanguageFor(item.languageCode).name;
    final target = discoveryLanguageFor(_profile.targetLanguage).name;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.language_rounded),
            title: const Text('Different language detected'),
            content: Text(
              'This video appears to be in $content while you are learning $target. '
              'You can play it normally; your $target learning goal will not change.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _open(DiscoveryItem item) async {
    if (_openingId != null) return;
    if (!await _confirmMismatch(item)) return;
    setState(() => _openingId = item.providerId);
    try {
      final media = await _service.resolve(item);
      if (!mounted) return;
      setState(() => _openingId = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(video: media.toVideoItem()),
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
    final theme = Theme.of(context);
    final target = discoveryLanguageFor(_profile.targetLanguage).name;
    return Scaffold(
      body: CustomScrollView(
        key: const PageStorageKey('search-screen-scroll'),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Search'),
                Text(
                  '$target first • all languages available',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF63E6FF),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Movies, series, anime, sports, documentaries…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _controller.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF111B2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: DiscoveryCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = DiscoveryCategory.values[index];
                  return ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) {
                      setState(() => _category = category);
                      if (_controller.text.trim().isNotEmpty) {
                        unawaited(_search());
                      }
                    },
                  );
                },
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!),
              ),
            )
          else if (_controller.text.trim().isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.travel_explore_rounded,
                        size: 58,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Find your next story',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search free open movies and videos. El-Nemr Language prioritizes $target, but never blocks another language.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No matching open videos found.')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                final item = _results[index];
                final targetMatch = item.matchesTarget(_profile.targetLanguage);
                return InkWell(
                  onTap: () => _open(item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 92,
                            height: 126,
                            child: item.thumbnailUrl == null
                                ? Container(
                                    color: const Color(0xFF162239),
                                    child: const Icon(Icons.movie_rounded),
                                  )
                                : Image.network(
                                    item.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: const Color(0xFF162239),
                                      child: const Icon(Icons.movie_rounded),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (item.languageLabel.isNotEmpty)
                                    _Tag(item.languageLabel),
                                  if (item.year != null && item.year!.isNotEmpty)
                                    _Tag(item.year!),
                                  _Tag(item.category.label),
                                  if (targetMatch)
                                    const _Tag('Learning fit', highlighted: true),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.description.isEmpty
                                    ? 'Open video from ${item.providerLabel}'
                                    : item.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _openingId == item.providerId
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_circle_fill_rounded),
                      ],
                    ),
                  ),
                );
                },
                childCount: _results.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.highlighted = false});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: highlighted
            ? const Color(0xFF19D39A).withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: highlighted ? const Color(0xFF54F0BD) : null,
        ),
      ),
    );
  }
}
