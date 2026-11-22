import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/subtitle_layer.dart';
import 'package:el_nemr_language/learning/services/learner_profile_store.dart';
import 'package:el_nemr_language/learning/services/learning_progress_store.dart';
import 'package:el_nemr_language/learning/services/subtitle_layer_store.dart';
import 'package:el_nemr_language/learning/services/video_flashcard_store.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('learner profile persists', () async {
    const profile = LearnerProfile(nativeLanguage: 'ar', targetLanguage: 'de', level: 'B1');
    await LearnerProfileStore.save(profile);
    final loaded = await LearnerProfileStore.load();
    expect(loaded.nativeLanguage, 'ar');
    expect(loaded.targetLanguage, 'de');
    expect(loaded.level, 'B1');
  });

  test('progress never marks replacement subtitle as already mastered', () async {
    const original = LearningSegment(
      id: 'seg_3000_0',
      start: Duration(seconds: 3),
      end: Duration(seconds: 5),
      original: 'Original spoken dialogue',
    );
    const replacement = LearningSegment(
      id: 'seg_3000_0',
      start: Duration(seconds: 3),
      end: Duration(seconds: 5),
      original: 'A different spoken dialogue',
    );
    await LearningProgressStore.record('replacement-progress', original.id, 1,
        segment: original);
    var saved = await LearningProgressStore.load('replacement-progress');
    var entry = Map<String, dynamic>.from(saved[original.id] as Map);
    expect(LearningProgressStore.matchesSegment(entry, original), isTrue);
    expect(LearningProgressStore.matchesSegment(entry, replacement), isFalse);
    expect(entry['best'], 1);

    await LearningProgressStore.record('replacement-progress', replacement.id,
        0.2, segment: replacement);
    saved = await LearningProgressStore.load('replacement-progress');
    entry = Map<String, dynamic>.from(saved[replacement.id] as Map);
    expect(LearningProgressStore.matchesSegment(entry, replacement), isTrue);
    expect(entry['best'], 0.2);
    expect(entry['attempts'], 1,
        reason: 'Old line attempts must not transfer to new subtitles.');

    await LearningProgressStore.record('replacement-progress', replacement.id,
        0.8, segment: replacement);
    saved = await LearningProgressStore.load('replacement-progress');
    entry = Map<String, dynamic>.from(saved[replacement.id] as Map);
    expect(entry['attempts'], 2);
    expect(entry['best'], 0.8);
    expect(LearningProgressStore.matchesSegment(entry, original), isFalse);
  });

  test('captured answer identity rejects current subtitles sharing the old ID',
      () {
    const captured = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      original: 'Guten Morgen',
      translation: 'Good morning',
    );
    const changedTranslation = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      original: 'Guten Morgen',
      translation: 'Hello there',
    );
    const changedText = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      original: 'Guten Abend',
      translation: 'Good morning',
    );
    const changedTiming = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 2),
      end: Duration(seconds: 5),
      original: 'Guten Morgen',
      translation: 'Good morning',
    );
    expect(LearningProgressStore.sameSegmentIdentity(captured, captured),
        isTrue);
    expect(LearningProgressStore.sameSegmentIdentity(
        captured, changedTranslation), isFalse);
    expect(LearningProgressStore.sameSegmentIdentity(
        captured, changedText), isFalse);
    expect(LearningProgressStore.sameSegmentIdentity(
        captured, changedTiming), isFalse);
  });

  test('changing only subtitle translation resets adaptive score identity', () async {
    const original = LearningSegment(
      id: 'same-timing',
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      original: 'Guten Morgen',
      translation: 'Good morning',
    );
    const retranslated = LearningSegment(
      id: 'same-timing',
      start: Duration(seconds: 2),
      end: Duration(seconds: 4),
      original: 'Guten Morgen',
      translation: 'Good day',
    );
    await LearningProgressStore.record('translation-edit', original.id, 1.0,
        segment: original);
    var all = await LearningProgressStore.load('translation-edit');
    var stored = Map<String, dynamic>.from(all[original.id] as Map);
    expect(LearningProgressStore.matchesSegment(stored, original), isTrue);
    expect(LearningProgressStore.matchesSegment(stored, retranslated), isFalse);
    expect(stored['best'], 1.0, reason: 'Retain old scores in storage');

    await LearningProgressStore.record(
        'translation-edit', retranslated.id, 0.3, segment: retranslated);
    all = await LearningProgressStore.load('translation-edit');
    stored = Map<String, dynamic>.from(all[retranslated.id] as Map);
    expect(LearningProgressStore.matchesSegment(stored, retranslated), isTrue);
    expect(LearningProgressStore.matchesSegment(stored, original), isFalse);
    expect(stored['translation'], 'Good day');
    expect(stored['attempts'], 1);
    expect(stored['best'], 0.3);
  });

  test('adding a new translation invalidates scores for an un-translated line',
      () async {
    const without = LearningSegment(
      id: 'translation-arrives',
      start: Duration.zero,
      end: Duration(seconds: 2),
      original: 'Hola',
    );
    const withTranslation = LearningSegment(
      id: 'translation-arrives',
      start: Duration.zero,
      end: Duration(seconds: 2),
      original: 'Hola',
      translation: 'Hello',
    );
    await LearningProgressStore.record(
        'translation-arrives', without.id, 0.8, segment: without);
    final all = await LearningProgressStore.load('translation-arrives');
    final stored = Map<String, dynamic>.from(all[without.id] as Map);
    expect(stored.containsKey('translation'), isTrue);
    expect(LearningProgressStore.matchesSegment(stored, without), isTrue);
    expect(LearningProgressStore.matchesSegment(stored, withTranslation),
        isFalse);
  });

  test('legacy progress without content signature is not applied to new cues',
      () async {
    await LearningProgressStore.record('legacy', 'same-id', 0.9);
    final saved = await LearningProgressStore.load('legacy');
    final entry = Map<String, dynamic>.from(saved['same-id'] as Map);
    const segment = LearningSegment(
      id: 'same-id',
      start: Duration.zero,
      end: Duration(seconds: 3),
      original: 'New content at legacy index',
    );
    expect(LearningProgressStore.matchesSegment(entry, segment), isFalse);
    expect(entry['best'], 0.9,
        reason: 'Keep legacy records even when they cannot be re-associated.');
  });

  test('subtitle layer settings persist without cue payload', () async {
    final layer = SubtitleLayer(
      id: 'layer1',
      label: 'Deutsch',
      source: 'file:///de.srt',
      language: 'de',
      cues: const [],
      x: 0.42,
      y: 0.73,
      scale: 1.25,
      delayMs: -300,
      locked: true,
      textColor: Colors.yellow,
    );
    await SubtitleLayerStore.save('video', <SubtitleLayer>[layer]);
    final loaded = await SubtitleLayerStore.load('video');
    expect(loaded['layer1']?['source'], 'file:///de.srt');
    expect(loaded['layer1']?['x'], 0.42);
    expect(loaded['layer1']?['delayMs'], -300);
    expect(loaded['layer1']?['locked'], isTrue);
  });

  test('progress records attempts and best score', () async {
    await LearningProgressStore.record('video', 'seg', 0.4);
    await LearningProgressStore.record('video', 'seg', 0.9);
    final data = await LearningProgressStore.load('video');
    final seg = Map<String, dynamic>.from(data['seg'] as Map);
    expect(seg['attempts'], 2);
    expect(seg['best'], 0.9);
    expect(seg['last'], 0.9);
  });

  test('stale flashcards do not hide valid due reviews after subtitle edits', () async {
    const removed = LearningSegment(
      id: 'removed-caption',
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
      original: 'Old text',
    );
    const active = LearningSegment(
      id: 'current-caption',
      start: Duration(seconds: 3),
      end: Duration(seconds: 4),
      original: 'Current words',
    );
    await VideoFlashcardStore.toggle('video', removed);
    await VideoFlashcardStore.toggle('video', active);
    final cards = await VideoFlashcardStore.load('video');

    final due = VideoFlashcardStore.dueForSegments(
      cards,
      <LearningSegment>[active],
    );
    expect(due.map((e) => e.key), <String>[active.id]);
    expect(cards.containsKey(removed.id), isTrue,
        reason: 'Existing stored cards are preserved until explicitly deleted.');
    final none = VideoFlashcardStore.dueForSegments(cards, <LearningSegment>[]);
    expect(none, isEmpty);
  });

  test('replacement captions do not hijack old cards with the same ID', () async {
    const oldLine = LearningSegment(
      id: 'seg_3000_0',
      start: Duration(seconds: 3),
      end: Duration(seconds: 5),
      original: 'My original sentence',
    );
    const replacement = LearningSegment(
      id: 'seg_3000_0',
      start: Duration(seconds: 3),
      end: Duration(seconds: 5),
      original: 'A totally different subtitle',
    );
    expect(await VideoFlashcardStore.toggle('replacement', oldLine), isTrue);
    var cards = await VideoFlashcardStore.load('replacement');
    expect(VideoFlashcardStore.matchesSegment(cards[replacement.id], replacement), isFalse);
    expect(VideoFlashcardStore.dueForSegments(cards, <LearningSegment>[replacement]),
        isEmpty, reason: 'A shared timestamp and index do not prove shared dialogue.');
    expect(VideoFlashcardStore.dueForSegments(cards, <LearningSegment>[oldLine]),
        hasLength(1));

    expect(await VideoFlashcardStore.toggle('replacement', replacement), isTrue,
        reason: 'Saving a new sentence at an old ID must replace the stale card, not delete it.');
    cards = await VideoFlashcardStore.load('replacement');
    expect(cards, hasLength(1));
    expect(cards[replacement.id]?['original'], replacement.original);
    expect(VideoFlashcardStore.matchesSegment(cards[replacement.id], replacement), isTrue);
    expect(VideoFlashcardStore.dueForSegments(cards, <LearningSegment>[replacement]),
        hasLength(1));
    expect(await VideoFlashcardStore.toggle('replacement', replacement), isFalse);
    expect(await VideoFlashcardStore.load('replacement'), isEmpty);
  });

  test('translation edits never reuse the old video flashcard or its schedule',
      () async {
    const original = LearningSegment(
      id: 'shared-id',
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      original: 'Bonjour',
      translation: 'Hello',
    );
    const retranslated = LearningSegment(
      id: 'shared-id',
      start: Duration(seconds: 1),
      end: Duration(seconds: 3),
      original: 'Bonjour',
      translation: 'Good day',
    );
    expect(await VideoFlashcardStore.toggle('translated-cards', original),
        isTrue);
    await VideoFlashcardStore.review('translated-cards', original.id, 1);
    var cards = await VideoFlashcardStore.load('translated-cards');
    expect(cards[original.id]?['repetitions'], 1);
    expect(VideoFlashcardStore.matchesSegment(cards[original.id], original),
        isTrue);
    expect(VideoFlashcardStore.matchesSegment(
        cards[retranslated.id], retranslated), isFalse);
    expect(VideoFlashcardStore.dueForSegments(
        cards, <LearningSegment>[retranslated]), isEmpty);

    expect(await VideoFlashcardStore.toggle('translated-cards', retranslated),
        isTrue, reason: 'Different translations must replace, not toggle off');
    cards = await VideoFlashcardStore.load('translated-cards');
    expect(cards, hasLength(1));
    expect(cards[retranslated.id]?['translation'], 'Good day');
    expect(cards[retranslated.id]?['repetitions'], 0);
    expect(VideoFlashcardStore.matchesSegment(
        cards[retranslated.id], retranslated), isTrue);
    expect(VideoFlashcardStore.matchesSegment(cards[original.id], original),
        isFalse);
  });

  test('parallel score writes keep all attempts and the best score', () async {
    final scores = List<double>.generate(40, (i) => (i + 1) / 40);
    await Future.wait(scores.map(
      (score) => LearningProgressStore.record('many', 'seg', score),
    ));
    final progress = await LearningProgressStore.load('many');
    final saved = Map<String, dynamic>.from(progress['seg'] as Map);
    expect(saved['attempts'], 40);
    expect(saved['best'], 1.0);
    expect(saved['last'], 1.0);
  });

  test('parallel flashcard toggles and reviews do not lose updates', () async {
    final segments = List<LearningSegment>.generate(
      20,
      (i) => LearningSegment(
        id: 'card-$i',
        start: Duration(seconds: i),
        end: Duration(seconds: i + 1),
        original: 'Sentence $i',
      ),
    );
    final toggled = await Future.wait(
      segments.map((s) => VideoFlashcardStore.toggle('parallel', s)),
    );
    expect(toggled, everyElement(isTrue));
    final saved = await VideoFlashcardStore.load('parallel');
    expect(saved, hasLength(20));

    await Future.wait(List.generate(
      8,
      (_) => VideoFlashcardStore.review('parallel', 'card-0', 1),
    ));
    final cards = await VideoFlashcardStore.load('parallel');
    expect((cards['card-0']?['repetitions'] as num?)?.toInt(), 8);
    expect(cards, hasLength(20));
  });

  test('video flashcard toggles and schedules successful review', () async {
    const segment = LearningSegment(
      id: 'seg-card',
      start: Duration(seconds: 3),
      end: Duration(seconds: 5),
      original: 'Guten Morgen',
      translation: 'صباح الخير',
    );
    expect(await VideoFlashcardStore.toggle('video', segment), isTrue);
    var cards = await VideoFlashcardStore.load('video');
    expect(cards.containsKey(segment.id), isTrue);
    expect(VideoFlashcardStore.isDue(cards[segment.id]!), isTrue);

    await VideoFlashcardStore.review('video', segment.id, 1.0);
    cards = await VideoFlashcardStore.load('video');
    expect((cards[segment.id]?['repetitions'] as num?)?.toInt(), 1);
    expect(VideoFlashcardStore.isDue(cards[segment.id]!), isFalse);

    expect(await VideoFlashcardStore.toggle('video', segment), isFalse);
  });
}
