import 'dart:async';

import 'package:flutter/material.dart';
import '../models/learning_models.dart';
import '../models/subtitle_layer.dart';
import '../models/learner_profile.dart';
import '../services/learning_engine.dart';
import '../services/speech_coach_service.dart';
import '../services/speech_assessment.dart';
import '../services/ai_language_service.dart';
import '../services/video_flashcard_store.dart';
import '../services/on_device_translation_service.dart';
import '../services/local_language_coach.dart';
import '../services/vocabulary_store.dart';

class LearningStudioSheet extends StatefulWidget {
  const LearningStudioSheet({
    super.key,
    required this.layers,
    required this.segments,
    required this.position,
    required this.positionProvider,
    required this.mode,
    required this.onModeChanged,
    required this.onSeek,
    required this.onLayerChanged,
    required this.onAddSubtitle,
    required this.onEditLayoutChanged,
    required this.editLayout,
    required this.onRecordScore,
    required this.onPauseForSpeech,
    required this.profile,
    required this.onProfileChanged,
    required this.onAutoPrepare,
    required this.onRemoveLayer,
    required this.onAutoArrange,
    required this.videoKey,
    required this.onThreeStepRepeat,
    required this.immersionEnabled,
    required this.onImmersionChanged,
    required this.smartCoachEnabled,
    required this.onSmartCoachChanged,
  });

  final List<SubtitleLayer> layers;
  final List<LearningSegment> segments;
  final Duration position;
  /// Reads the live player position while this modal route is open.
  /// A bottom sheet is not rebuilt by the parent player's setState, so relying
  /// on [position] alone would freeze the current lesson at the instant the
  /// sheet was opened.
  final Duration Function() positionProvider;
  final LearningMode mode;
  final ValueChanged<LearningMode> onModeChanged;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<SubtitleLayer> onLayerChanged;
  final VoidCallback onAddSubtitle;
  final ValueChanged<bool> onEditLayoutChanged;
  final bool editLayout;
  final void Function(String segmentId, double score) onRecordScore;
  final VoidCallback onPauseForSpeech;
  final LearnerProfile profile;
  final ValueChanged<LearnerProfile> onProfileChanged;
  final VoidCallback onAutoPrepare;
  final ValueChanged<SubtitleLayer> onRemoveLayer;
  final VoidCallback onAutoArrange;
  final String videoKey;
  final VoidCallback onThreeStepRepeat;
  final bool immersionEnabled;
  final ValueChanged<bool> onImmersionChanged;
  final bool smartCoachEnabled;
  final ValueChanged<bool> onSmartCoachChanged;

  @override
  State<LearningStudioSheet> createState() => _LearningStudioSheetState();
}

class _LearningStudioSheetState extends State<LearningStudioSheet> {
  final LearningEngine _engine = LearningEngine();
  final TextEditingController _answer = TextEditingController();
  QuizQuestion? _question;
  double? _lastScore;
  AnswerScore? _lastAnswerScore;
  SpeechAssessment? _lastSpeechAssessment;
  late LearningMode _mode;
  late bool _editLayout;
  late LearnerProfile _profile;
  bool _listening = false;
  String? _speechError;
  bool _aiBusy = false;
  String? _aiExplanation;
  String? _aiError;
  Map<String, Map<String, dynamic>> _flashcards = <String, Map<String, dynamic>>{};
  Timer? _positionTicker;
  String? _activeSegmentId;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _editLayout = widget.editLayout;
    _profile = widget.profile;
    _loadFlashcards();
    _activeSegmentId = _current?.id;
    _positionTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final currentId = _current?.id;
      final changed = currentId != _activeSegmentId;
      if (changed) {
        _activeSegmentId = currentId;
        _question = null;
        _answer.clear();
        _lastScore = null;
        _lastAnswerScore = null;
        _speechError = null;
        _aiExplanation = null;
        _aiError = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _positionTicker?.cancel();
    _answer.dispose();
    super.dispose();
  }

  Duration get _livePosition {
    try {
      return widget.positionProvider();
    } catch (_) {
      return widget.position;
    }
  }

  LearningSegment? get _current => _engine.segmentAt(widget.segments, _livePosition) ??
      (widget.segments.isNotEmpty ? widget.segments.first : null);

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF121316),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.school_rounded, color: Colors.lightBlueAccent),
                  SizedBox(width: 10),
                  Text('Learning Studio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1A1C20), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _languagePicker('My language', _profile.nativeLanguage, (v) => _setProfile(_profile.copyWith(nativeLanguage: v)))),
                      const SizedBox(width: 10),
                      Expanded(child: _languagePicker('Learning', _profile.targetLanguage, (v) => _setProfile(_profile.copyWith(targetLanguage: v)))),
                      const SizedBox(width: 10),
                      SizedBox(width: 86, child: _levelPicker()),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onAutoPrepare,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Auto prepare this video'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in const <LearningMode>[
                    LearningMode.watch,
                    LearningMode.learn,
                    LearningMode.listening,
                    LearningMode.speak,
                    LearningMode.test,
                  ])
                    ChoiceChip(
                      label: Text(_modeLabel(mode)),
                      selected: _mode == mode,
                      onSelected: (_) { setState(() => _mode = mode); widget.onModeChanged(mode); },
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_mode_rounded, color: Colors.purpleAccent),
                title: const Text('Immersion Auto', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Cycles Watch → Learn → Listen → Speak → Test while the movie keeps flowing.', style: TextStyle(color: Colors.white54)),
                value: widget.immersionEnabled,
                onChanged: widget.onImmersionChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.psychology_rounded, color: Colors.lightBlueAccent),
                title: const Text('Smart Coach', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Adapts help and playback to your performance.', style: TextStyle(color: Colors.white54)),
                value: widget.smartCoachEnabled,
                onChanged: widget.onSmartCoachChanged,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Subtitle layers (${widget.layers.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                  IconButton(tooltip: 'Auto arrange', onPressed: widget.layers.isEmpty ? null : widget.onAutoArrange, icon: const Icon(Icons.vertical_align_center, color: Colors.white70)),
                  TextButton.icon(onPressed: widget.onAddSubtitle, icon: const Icon(Icons.add), label: const Text('Add')),
                ],
              ),
              for (var i = 0; i < widget.layers.length; i++) _layerTile(widget.layers[i], i),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _editLayout,
                onChanged: (v) { setState(() => _editLayout = v); widget.onEditLayoutChanged(v); },
                title: const Text('Edit subtitle positions', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Drag with one finger · pinch with two · double-tap to reset', style: TextStyle(color: Colors.white54)),
              ),
              const Divider(color: Colors.white12),
              if (_dueFlashcards.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF191D1B), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.style, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_dueFlashcards.length} video flashcard${_dueFlashcards.length == 1 ? '' : 's'} due', style: const TextStyle(color: Colors.white70))),
                    TextButton(onPressed: _reviewNextDue, child: const Text('Review')),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              if (current == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Add an original-language subtitle to create lessons and quizzes from this video.', style: TextStyle(color: Colors.white60)),
                )
              else ...[
                const Text('Current learning segment', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _segmentCard(current),
                if (_mode == LearningMode.speak) ...[
                  const SizedBox(height: 12),
                  _shadowCard(current),
                  const SizedBox(height: 12),
                  _rolePlayCard(current),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: FilledButton.icon(onPressed: () => widget.onSeek(current.start), icon: const Icon(Icons.replay), label: const Text('Repeat sentence'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _newQuestion(current), icon: const Icon(Icons.quiz_outlined), label: const Text('Quiz me'))),
                    IconButton(
                      tooltip: _flashcards.containsKey(current.id) ? 'Remove video flashcard' : 'Save video flashcard',
                      onPressed: () => _toggleFlashcard(current),
                      icon: Icon(_flashcards.containsKey(current.id) ? Icons.star : Icons.star_border, color: Colors.amberAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onThreeStepRepeat,
                    icon: const Icon(Icons.repeat_on_rounded),
                    label: const Text('3-step repeat · bilingual → target only → listening'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _aiBusy ? null : () => _explainWithAi(current),
                    icon: _aiBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(AiLanguageService.isConfigured ? 'Explain this scene · AI Tutor' : 'Explain this scene · Local Coach'),
                  ),
                ),
                if (_aiError != null) Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_aiError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
                if (_aiExplanation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF171A20), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: .22))),
                    child: SelectableText(_aiExplanation!, style: const TextStyle(color: Colors.white70, height: 1.45)),
                  ),
                ],
                if (_question != null) ...[
                  const SizedBox(height: 16),
                  _questionCard(_question!),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _layerTile(SubtitleLayer layer, int index) {
    return Card(
      color: const Color(0xFF1C1E22),
      child: ExpansionTile(
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
        title: Text(layer.label.isEmpty ? 'Subtitle ${index + 1}' : layer.label, style: const TextStyle(color: Colors.white)),
        subtitle: Text('${layer.language.isEmpty ? 'Unknown language' : layer.language.toUpperCase()} · ${layer.role.name}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        leading: IconButton(
          icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off, color: layer.visible ? Colors.white : Colors.white38),
          onPressed: () { layer.visible = !layer.visible; widget.onLayerChanged(layer); setState(() {}); },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                Row(children: [
                  const Text('Role', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButton<SubtitleLayerRole>(
                    value: layer.role,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF25272C),
                    items: [for (final r in SubtitleLayerRole.values) DropdownMenuItem(value: r, child: Text(r.name, style: const TextStyle(color: Colors.white)))],
                    onChanged: (v) { if (v == null) return; layer.role = v; widget.onLayerChanged(layer); setState(() {}); },
                  )),
                ]),
                Row(children: [
                  const Text('Size', style: TextStyle(color: Colors.white70)),
                  Expanded(child: Slider(value: layer.scale, min: 0.55, max: 2.5, onChanged: (v) { layer.scale = v; widget.onLayerChanged(layer); setState(() {}); })),
                  Text('${(layer.scale * 100).round()}%', style: const TextStyle(color: Colors.white60)),
                ]),
                Row(children: [
                  const Text('Delay', style: TextStyle(color: Colors.white70)),
                  Expanded(child: Slider(value: layer.delayMs.toDouble().clamp(-10000, 10000).toDouble(), min: -10000, max: 10000, divisions: 80, onChanged: (v) { layer.delayMs = v.round(); widget.onLayerChanged(layer); setState(() {}); })),
                  SizedBox(width: 70, child: Text('${layer.delayMs >= 0 ? '+' : ''}${layer.delayMs} ms', textAlign: TextAlign.end, style: const TextStyle(color: Colors.white60))),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: layer.locked,
                  onChanged: (v) { layer.locked = v; widget.onLayerChanged(layer); setState(() {}); },
                  title: const Text('Lock position', style: TextStyle(color: Colors.white70)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () { widget.onRemoveLayer(layer); setState(() {}); },
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text('Remove layer', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentCard(LearningSegment s, {bool conceal = false}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF1C1E22), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (conceal)
        const Text('Your turn — answer the previous line', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))
      else
        _interactiveSentence(s),
      if (!conceal && s.translation?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(
          s.translation!,
          textDirection: _isRtlLanguage(_profile.nativeLanguage) ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 16),
        ),
      ],
      const SizedBox(height: 8),
      Text('Estimated ${estimatedCefr(s.difficulty)} · difficulty ${(s.difficulty * 100).round()}% · ${_fmt(s.start)} → ${_fmt(s.end)}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
    ]),
  );

  Widget _interactiveSentence(LearningSegment segment) {
    final tokens = RegExp(r"[\p{L}\p{M}’'\-]+|[^\p{L}\p{M}’'\-]+", unicode: true)
        .allMatches(segment.original)
        .map((m) => m.group(0) ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return Wrap(
      spacing: 0,
      runSpacing: 2,
      children: [
        for (final token in tokens)
          if (RegExp(r'[\p{L}\p{M}]', unicode: true).hasMatch(token))
            InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () => _openWord(token.replaceAll(RegExp(r"^[^\p{L}]+|[^\p{L}]+$", unicode: true), ''), segment),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                child: Text(token, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Text(token, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String get _originalLanguage {
    final original = widget.layers.where((e) => e.role == SubtitleLayerRole.original).firstOrNull;
    final language = original?.language.trim().toLowerCase() ?? '';
    return language.isEmpty || language == 'und' ? _profile.targetLanguage : language;
  }

  Future<void> _openWord(String word, LearningSegment segment) async {
    if (word.trim().isEmpty) return;
    final sourceLanguage = _originalLanguage;
    final targetLanguage = _profile.nativeLanguage;
    String meaning = word;
    String? error;
    if (sourceLanguage != targetLanguage && OnDeviceTranslationService.canTranslate(sourceLanguage, targetLanguage)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Translating word locally…'), duration: Duration(seconds: 2)));
      }
      try {
        meaning = await OnDeviceTranslationService.translateText(
          word,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );
      } catch (e) {
        error = e.toString();
      }
    } else if (sourceLanguage != targetLanguage) {
      error = 'This language pair is not available in the on-device translator.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17191E),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(word, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w800))),
                Text(sourceLanguage.toUpperCase(), style: const TextStyle(color: Colors.white38)),
              ]),
              const SizedBox(height: 8),
              Text(error ?? meaning, style: TextStyle(fontSize: 20, color: error == null ? Colors.lightBlueAccent : Colors.orangeAccent)),
              const SizedBox(height: 12),
              Text('“${segment.original}”', style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: error != null ? null : () async {
                    await VocabularyStore.saveWord(
                      word: word,
                      language: sourceLanguage,
                      meaning: meaning,
                      context: segment.original,
                    );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Daily Review')));
                  },
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: const Text('Save to vocabulary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionCard(QuizQuestion q) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF191B20), border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .25)), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(q.prompt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      TextField(controller: _answer, minLines: 1, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'اكتب إجابتك…', hintStyle: TextStyle(color: Colors.white38), border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Row(children: [
        FilledButton(onPressed: _grade, child: const Text('Check')),
        const SizedBox(width: 10),
        TextButton(onPressed: () => setState(() { _answer.text = q.answer; _lastScore = null; _lastAnswerScore = null; }), child: const Text('Show answer')),
        IconButton(
          tooltip: 'Answer by voice',
          onPressed: _listening ? null : () => _listenAndFill(q.segment),
          icon: _listening
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.mic, color: Colors.lightBlueAccent),
        ),
        const Spacer(),
        if (_lastScore != null) Text('${(_lastScore! * 100).round()}%', style: TextStyle(color: _lastScore! >= .8 ? Colors.greenAccent : _lastScore! >= .55 ? Colors.amberAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
      ]),
      if (_lastAnswerScore != null && !_lastAnswerScore!.perfect) ...[
        const SizedBox(height: 8),
        _answerFeedback(_lastAnswerScore!),
      ],
    ]),
  );

  Widget _answerFeedback(AnswerScore detail) {
    final missing = detail.missingWords.take(8).join(', ');
    final extra = detail.extraWords.take(8).join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (missing.isNotEmpty)
            Text('Missing / expected: $missing', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
          if (extra.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: missing.isEmpty ? 0 : 4),
              child: Text('Different / extra: $extra', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  static const Map<String, String> _languageNames = <String, String>{
    'ar': 'Arabic', 'en': 'English', 'de': 'German', 'fr': 'French',
    'es': 'Spanish', 'it': 'Italian', 'pt': 'Portuguese', 'ru': 'Russian',
    'tr': 'Turkish', 'ja': 'Japanese', 'ko': 'Korean', 'zh': 'Chinese',
  };

  Widget _languagePicker(String label, String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
    initialValue: _languageNames.containsKey(value) ? value : 'en',
    isExpanded: true,
    dropdownColor: const Color(0xFF25272C),
    decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
    items: [for (final e in _languageNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)))],
    onChanged: (v) { if (v != null) onChanged(v); },
  );

  Widget _levelPicker() => DropdownButtonFormField<String>(
    initialValue: const ['A1','A2','B1','B2','C1','C2'].contains(_profile.level) ? _profile.level : 'A2',
    dropdownColor: const Color(0xFF25272C),
    decoration: const InputDecoration(labelText: 'Level', isDense: true, border: OutlineInputBorder()),
    items: [for (final level in const ['A1','A2','B1','B2','C1','C2']) DropdownMenuItem(value: level, child: Text(level, style: const TextStyle(color: Colors.white)))],
    onChanged: (v) { if (v != null) _setProfile(_profile.copyWith(level: v)); },
  );

  void _setProfile(LearnerProfile value) {
    setState(() => _profile = value);
    widget.onProfileChanged(value);
  }

  Widget _rolePlayCard(LearningSegment segment) {
    final index = widget.segments.indexWhere((e) => e.id == segment.id);
    final cue = index > 0 ? widget.segments[index - 1] : null;
    final cueLine = cue == null ? null : parseDialogueLine(cue.original);
    final answerLine = parseDialogueLine(segment.original);
    final cueName = cueLine?.speaker ?? 'Other character';
    final answerName = answerLine.speaker ?? 'Your character';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1917),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: .25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.theater_comedy, color: Colors.orangeAccent, size: 20),
          SizedBox(width: 8),
          Text('Role Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(
          cue == null ? 'Start from the first line and respond naturally.' : '$cueName: “${cueLine?.text ?? cue.original}”',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (cue != null)
            Expanded(child: OutlinedButton.icon(
              onPressed: () => widget.onSeek(cue.start),
              icon: const Icon(Icons.hearing),
              label: const Text('Hear cue'),
            )),
          if (cue != null) const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(
            onPressed: _listening ? null : () => _listenAndScoreShadow(segment),
            icon: const Icon(Icons.mic),
            label: Text('Answer as $answerName'),
          )),
        ]),
        if (_lastScore != null) ...[
          const SizedBox(height: 8),
          Text('Dialogue match: ${(_lastScore! * 100).round()}%', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700)),
        ],
        TextButton(
          onPressed: () => setState(() { _answer.text = answerLine.text; }),
          child: const Text('Reveal scripted answer'),
        ),
      ]),
    );
  }

  Widget _shadowCard(LearningSegment segment) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF171D1F),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.22)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.record_voice_over, color: Colors.tealAccent, size: 20),
        SizedBox(width: 8),
        Text('Shadow practice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      const Text('Listen once, then repeat the line. The first score checks recognized words; phoneme-level pronunciation scoring can be added as a separate provider.', style: TextStyle(color: Colors.white54, fontSize: 12)),
      if (_speechError != null) ...[
        const SizedBox(height: 8),
        Text(_speechError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      ],
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _listening ? null : () => _listenAndScoreShadow(segment),
        icon: _listening
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.mic),
        label: Text(_listening ? 'Listening…' : 'Speak this line'),
      ),
      if (_lastSpeechAssessment != null) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricChip('Words', _lastSpeechAssessment!.wordAccuracy),
            _metricChip('Completeness', _lastSpeechAssessment!.completeness),
            _metricChip('Pace', _lastSpeechAssessment!.pace),
            _metricChip('Overall', _lastSpeechAssessment!.overall),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Local word/timing feedback · not phoneme or accent scoring.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    ]),
  );

  Widget _metricChip(String label, double value) {
    final pct = (value.clamp(0.0, 1.0) * 100).round();
    final color = value >= .8
        ? Colors.greenAccent
        : value >= .55
            ? Colors.amberAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $pct%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  List<MapEntry<String, Map<String, dynamic>>> get _dueFlashcards => _flashcards.entries
      .where((e) => VideoFlashcardStore.isDue(e.value))
      .toList(growable: false);

  Future<void> _loadFlashcards() async {
    try {
      final cards = await VideoFlashcardStore.load(widget.videoKey);
      if (mounted) setState(() => _flashcards = cards);
    } catch (_) {}
  }

  Future<void> _toggleFlashcard(LearningSegment segment) async {
    await VideoFlashcardStore.toggle(widget.videoKey, segment);
    await _loadFlashcards();
  }

  void _reviewNextDue() {
    final due = _dueFlashcards;
    if (due.isEmpty) return;
    final id = due.first.key;
    final segment = widget.segments.where((e) => e.id == id).firstOrNull;
    if (segment == null) return;
    widget.onSeek(segment.start);
    setState(() {
      _question = _engine.questionFor(segment, mode: LearningMode.test, nativeLanguage: _profile.nativeLanguage);
      _answer.clear();
      _lastScore = null;
      _lastAnswerScore = null;
    });
  }

  Future<void> _explainWithAi(LearningSegment segment) async {
    setState(() { _aiBusy = true; _aiError = null; _aiExplanation = null; });
    try {
      String explanation;
      if (AiLanguageService.isConfigured) {
        final index = widget.segments.indexWhere((e) => e.id == segment.id);
        final previous = index > 0 ? widget.segments[index - 1].original : null;
        final next = index >= 0 && index + 1 < widget.segments.length ? widget.segments[index + 1].original : null;
        explanation = await AiLanguageService.explainSegment(
          segment: segment,
          profile: _profile,
          previous: previous,
          next: next,
        );
      } else {
        explanation = await LocalLanguageCoach.explain(
          segment: segment,
          profile: _profile,
          sourceLanguage: _targetLanguage(),
        );
      }
      if (mounted) setState(() => _aiExplanation = explanation);
    } catch (e) {
      if (mounted) {
        setState(() => _aiError = 'Could not explain this scene locally: $e');
      }
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  String _targetLanguage() {
    final originals = widget.layers.where((e) => e.role == SubtitleLayerRole.original && e.language.trim().isNotEmpty);
    if (originals.isNotEmpty) return originals.first.language;
    final any = widget.layers.where((e) => e.language.trim().isNotEmpty);
    return any.isNotEmpty ? any.first.language : _profile.targetLanguage;
  }

  Future<void> _listenAndFill(LearningSegment segment) async {
    widget.onPauseForSpeech();
    setState(() { _listening = true; _speechError = null; });
    try {
      final text = await SpeechCoachService.instance.listen(languageCode: _targetLanguage());
      if (!mounted) return;
      if (text != null) _answer.text = text;
    } catch (e) {
      if (mounted) setState(() => _speechError = e.toString());
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _listenAndScoreShadow(LearningSegment segment) async {
    widget.onPauseForSpeech();
    setState(() { _listening = true; _speechError = null; _lastScore = null; _lastAnswerScore = null; _lastSpeechAssessment = null; });
    try {
      final stopwatch = Stopwatch()..start();
      final text = await SpeechCoachService.instance.listen(languageCode: _targetLanguage());
      stopwatch.stop();
      if (!mounted) return;
      if (text == null) return;
      final detail = _engine.scoreDetailed(text, segment.original);
      final assessment = assessSpeech(
        answer: detail,
        expectedText: segment.original,
        expectedDuration: segment.duration,
        speakingDuration: stopwatch.elapsed,
      );
      final score = assessment.overall;
      widget.onRecordScore(segment.id, score);
      if (_flashcards.containsKey(segment.id)) {
        await VideoFlashcardStore.review(widget.videoKey, segment.id, score);
        await _loadFlashcards();
      }
      setState(() {
        _answer.text = text;
        _lastScore = score;
        _lastAnswerScore = detail;
        _lastSpeechAssessment = assessment;
      });
    } catch (e) {
      if (mounted) setState(() => _speechError = e.toString());
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  void _newQuestion(LearningSegment segment) {
    setState(() {
      _question = _engine.questionFor(segment, mode: _mode, nativeLanguage: _profile.nativeLanguage);
      _answer.clear();
      _lastScore = null;
      _lastAnswerScore = null;
    });
  }

  void _grade() {
    final q = _question;
    if (q == null) return;
    final detail = _engine.scoreDetailed(_answer.text, q.answer);
    final score = detail.score;
    widget.onRecordScore(q.segment.id, score);
    if (_flashcards.containsKey(q.segment.id)) {
      VideoFlashcardStore.review(widget.videoKey, q.segment.id, score).then((_) => _loadFlashcards());
    }
    setState(() {
      _lastScore = score;
      _lastAnswerScore = detail;
    });
  }


  static bool _isRtlLanguage(String code) {
    final primary = code.trim().toLowerCase().split(RegExp('[-_]')).first;
    return const {'ar', 'fa', 'he', 'ur', 'ps', 'dv', 'ku'}.contains(primary);
  }

  static String _modeLabel(LearningMode mode) => switch (mode) {
    LearningMode.watch => 'Watch',
    LearningMode.learn => 'Learn',
    LearningMode.listening => 'Listening',
    LearningMode.speak => 'Speak',
    LearningMode.test => 'Test',
  };

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
