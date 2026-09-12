import 'package:flutter/material.dart';

import '../models/learner_profile.dart';
import '../services/learner_profile_store.dart';

class LearningOnboardingScreen extends StatefulWidget {
  const LearningOnboardingScreen({super.key, required this.onComplete, this.initialProfile});

  final ValueChanged<LearnerProfile> onComplete;
  final LearnerProfile? initialProfile;

  @override
  State<LearningOnboardingScreen> createState() => _LearningOnboardingScreenState();
}

class _LearningOnboardingScreenState extends State<LearningOnboardingScreen> {
  int _step = 0;
  String _native = 'ar';
  String _target = 'en';
  String _level = 'A2';
  final Set<String> _goals = {'listening', 'movies'};
  final Set<String> _genres = <String>{};
  bool _saving = false;


  @override
  void initState() {
    super.initState();
    final initial = widget.initialProfile;
    if (initial == null) return;
    _native = initial.nativeLanguage;
    _target = initial.targetLanguage;
    _level = initial.level;
    _goals
      ..clear()
      ..addAll(initial.goals);
    _genres
      ..clear()
      ..addAll(initial.favoriteGenres);
  }

  static const _languages = <(String, String, String)>[
    ('ar', '🇪🇬', 'العربية'),
    ('en', '🇬🇧', 'English'),
    ('de', '🇩🇪', 'Deutsch'),
    ('fr', '🇫🇷', 'Français'),
    ('es', '🇪🇸', 'Español'),
    ('it', '🇮🇹', 'Italiano'),
    ('ko', '🇰🇷', '한국어'),
    ('ja', '🇯🇵', '日本語'),
    ('zh', '🇨🇳', '中文'),
    ('ru', '🇷🇺', 'Русский'),
    ('tr', '🇹🇷', 'Türkçe'),
    ('pt', '🇵🇹', 'Português'),
  ];

  static const _goalOptions = <(String, IconData, String)>[
    ('listening', Icons.headphones_rounded, 'Listening'),
    ('speaking', Icons.record_voice_over_rounded, 'Speaking'),
    ('movies', Icons.movie_filter_rounded, 'Understand movies'),
    ('travel', Icons.flight_takeoff_rounded, 'Travel'),
    ('fluency', Icons.psychology_alt_rounded, 'General fluency'),
  ];

  static const _genreOptions = <String>[
    'Action', 'Anime', 'Comedy', 'Crime', 'Documentary', 'Drama', 'Family',
    'Fantasy', 'History', 'Horror', 'Mystery', 'Romance', 'Sci-Fi', 'Sports',
    'Thriller',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00D7FF), Color(0xFF815CFF)]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('El-Nemr Language', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                        Text('Learn from every scene', style: TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LinearProgressIndicator(value: (_step + 1) / 5, minHeight: 5, borderRadius: BorderRadius.circular(8)),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_step), child: _stepBody(theme)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving || !_canContinue ? null : _next,
                      icon: _saving
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_step == 4 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded),
                      label: Text(_step == 4 ? 'Start learning' : 'Continue'),
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

  Widget _stepBody(ThemeData theme) => switch (_step) {
        0 => _languageStep('What is your main language?', 'We use it only to explain difficult parts.', _native, (v) => setState(() => _native = v)),
        1 => _languageStep('What do you want to learn?', _target == _native ? 'Choose a language different from your main language.' : 'This language gets priority in Discover, subtitles and tests.', _target, (v) => setState(() => _target = v)),
        2 => _choiceStep(
            'What is your current level?',
            'You can change this later.',
            ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
            _level,
            (v) => setState(() => _level = v),
          ),
        3 => _multiChoiceStep(
            'What do you want to improve?',
            'Choose one or more. Smart Coach will adapt around these goals.',
            _goalOptions.map((e) => (e.$1, e.$3, e.$2)).toList(),
            _goals,
          ),
        _ => _multiChoiceStep(
            'What do you enjoy watching?',
            'This shapes AI recommendations. You can skip it.',
            _genreOptions.map((e) => (e.toLowerCase(), e, Icons.movie_outlined)).toList(),
            _genres,
          ),
      };

  Widget _heading(String title, String subtitle) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
      );

  Widget _languageStep(String title, String subtitle, String value, ValueChanged<String> onChanged) => ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _heading(title, subtitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final language in _languages)
                  ChoiceChip(
                    avatar: Text(language.$2),
                    label: Text(language.$3),
                    selected: value == language.$1,
                    onSelected: (_) => onChanged(language.$1),
                  ),
              ],
            ),
          ),
        ],
      );

  Widget _choiceStep(String title, String subtitle, List<String> options, String value, ValueChanged<String> onChanged) => ListView(
        children: [
          _heading(title, subtitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in options)
                  ChoiceChip(label: Text(option, style: const TextStyle(fontSize: 17)), selected: value == option, onSelected: (_) => onChanged(option)),
              ],
            ),
          ),
        ],
      );

  Widget _multiChoiceStep(String title, String subtitle, List<(String, String, IconData)> options, Set<String> selected) => ListView(
        children: [
          _heading(title, subtitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  FilterChip(
                    avatar: Icon(option.$3, size: 18),
                    label: Text(option.$2),
                    selected: selected.contains(option.$1),
                    onSelected: (v) => setState(() => v ? selected.add(option.$1) : selected.remove(option.$1)),
                  ),
              ],
            ),
          ),
        ],
      );


  bool get _canContinue {
    if (_step == 1 && _target == _native) return false;
    if (_step == 3 && _goals.isEmpty) return false;
    return true;
  }

  Future<void> _next() async {
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    final profile = LearnerProfile(
      nativeLanguage: _native,
      targetLanguage: _target,
      level: _level,
      goals: _goals.toList(growable: false),
      favoriteGenres: _genres.toList(growable: false),
      onboardingComplete: true,
    );
    await LearnerProfileStore.save(profile);
    if (!mounted) return;
    widget.onComplete(profile);
  }
}
