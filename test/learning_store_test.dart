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
