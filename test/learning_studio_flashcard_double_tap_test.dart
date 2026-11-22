import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/services/video_flashcard_store.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('two immediate save taps create one video flashcard',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const key = 'flashcard-double-tap-video';
    const segment = LearningSegment(
      id: 'flashcard-one',
      start: Duration(seconds: 1),
      end: Duration(seconds: 6),
      original: 'A sentence to remember.',
    );
    const position = Duration(seconds: 3);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: const <LearningSegment>[segment],
            position: position,
            positionProvider: () => position,
            mode: LearningMode.learn,
            onModeChanged: (_) {},
            onSeek: (_) {},
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (_, __) {},
            onPauseForSpeech: () {},
            profile: const LearnerProfile(
              nativeLanguage: 'en', targetLanguage: 'en',
            ),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: key,
            onThreeStepRepeat: () {},
            immersionEnabled: false,
            onImmersionChanged: (_) {},
            smartCoachEnabled: false,
            onSmartCoachChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Save video flashcard'));
    final button = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Save video flashcard',
      ),
    );
    final firstCallback = button.onPressed!;
    firstCallback();
    // Second event is dispatched with the stale pre-rebuild callback.
    firstCallback();
    // Verify persisted state rather than asserting intermediate button
    // visibility: in the mock store the write can finish within a frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final saved = await VideoFlashcardStore.load(key);
    expect(saved, hasLength(1),
        reason: 'Rapid double tap must not create and then remove a card');
    expect(VideoFlashcardStore.matchesSegment(saved[segment.id], segment), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
